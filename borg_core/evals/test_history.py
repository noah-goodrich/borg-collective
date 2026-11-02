"""Tests for borg_core.evals.history: the append, the Wilson interval, the per-SHA trend and the report CLI."""

from __future__ import annotations

from datetime import datetime, timezone
import json
from pathlib import Path

import pytest

from borg_core.evals import history

REPO = Path(__file__).resolve().parents[2]
RECORDED = REPO / "evals" / "cortex-agents" / "recorded"


def _rec(case: str, verdict: str, sha: str = "aaaaaaa1", ts: str = "2026-11-01T00:00:00Z", harness: str = "h") -> dict:
    return {"ts": ts, "harness": harness, "case": case, "git_sha": sha, "verdict": verdict, "reason": ""}


def _write(path: Path, records: list[dict]) -> None:
    for rec in records:
        history.append(rec, path)


def test_empty_or_missing_file_reports_nothing_and_exits_zero(tmp_path, capsys):
    assert history.main(["--report", "--path", str(tmp_path / "absent.jsonl")]) == 0
    (tmp_path / "empty.jsonl").write_text("")
    assert history.main(["--report", "--path", str(tmp_path / "empty.jsonl")]) == 0
    captured = capsys.readouterr()
    assert captured.out == "" and captured.err == ""


def test_ten_identical_passes_have_wilson_lower_bound_near_072():
    low, high = history.wilson(10, 10)
    assert low == pytest.approx(0.722, abs=0.002)
    assert high == pytest.approx(1.0)


def test_wilson_of_no_evidence_is_none_not_zero():
    assert history.wilson(0, 0) is None


def test_mixed_verdicts_and_skip_error_counted_but_not_in_the_rate(tmp_path, capsys):
    path = tmp_path / "h.jsonl"
    verdicts = ["pass", "pass", "pass", "fail", "skip", "error", "skip"]
    _write(path, [_rec("P1", v, ts=f"2026-11-01T00:00:0{i}Z") for i, v in enumerate(verdicts)])
    assert history.main(["--report", "--path", str(path)]) == 0
    first = capsys.readouterr().out.splitlines()[0]
    assert "h/P1" in first and "n=4 pass=3 skip=2 error=1" in first
    low, high = history.wilson(3, 4)
    assert f"[{low:.3f}, {high:.3f}]" in first


def test_a_case_with_only_skips_is_shown_with_no_interval(tmp_path, capsys):
    path = tmp_path / "h.jsonl"
    _write(path, [_rec("P1", "skip")])
    history.main(["--report", "--path", str(path)])
    assert "n=0 pass=0 skip=1 error=0  wilson95=n/a" in capsys.readouterr().out


def test_per_sha_trend_is_in_time_order_not_file_order(tmp_path, capsys):
    path = tmp_path / "h.jsonl"
    _write(
        path,
        [
            _rec("P1", "pass", sha="bbbbbbb2", ts="2026-11-02T00:00:00Z"),
            _rec("P1", "fail", sha="aaaaaaa1", ts="2026-11-01T00:00:00Z"),
            _rec("P1", "pass", sha="aaaaaaa1", ts="2026-11-01T01:00:00Z"),
            _rec("P1", "pass", sha="bbbbbbb2", ts="2026-11-02T01:00:00Z"),
        ],
    )
    history.main(["--report", "--path", str(path)])
    trend = [ln for ln in capsys.readouterr().out.splitlines() if ln.startswith("trend")]
    assert trend == ["trend h/P1  aaaaaaa:1/2 bbbbbbb:2/2"]


def test_a_malformed_line_is_skipped_and_counted_on_stderr(tmp_path, capsys):
    path = tmp_path / "h.jsonl"
    _write(path, [_rec("P1", "pass")])
    with open(path, "a", encoding="utf-8") as handle:
        handle.write(
            "not json\n[1,2]\n" + json.dumps({"harness": "h", "case": "x", "ts": "t", "verdict": "bogus"}) + "\n"
        )
    assert history.main(["--report", "--path", str(path)]) == 0
    captured = capsys.readouterr()
    assert "h/P1  n=1 pass=1" in captured.out
    assert "skipped 3 malformed line(s)" in captured.err


def test_append_writes_one_line_and_rejects_a_bad_verdict(tmp_path):
    path = tmp_path / "deep" / "dir" / "h.jsonl"
    history.append(_rec("P1", "pass"), path)
    history.append(_rec("P2", "fail"), path)
    assert len(path.read_text().splitlines()) == 2
    with pytest.raises(ValueError):
        history.append(_rec("P3", "maybe"), path)


def test_env_override_names_the_store(tmp_path, monkeypatch):
    monkeypatch.setenv("BORG_EVAL_HISTORY", str(tmp_path / "x.jsonl"))
    assert history.history_path() == tmp_path / "x.jsonl"
    monkeypatch.delenv("BORG_EVAL_HISTORY")
    monkeypatch.setenv("XDG_STATE_HOME", str(tmp_path / "state"))
    assert history.history_path() == tmp_path / "state" / "borg" / "evals" / "history.jsonl"


def test_parser_derives_turns_tokens_and_models_from_a_recorded_result_event():
    # A REAL recorded stream (evals/cortex-agents/recorded), not a fixture that sets what production must derive.
    derived = history.parse_result((RECORDED / "stream-assume.jsonl").read_text())
    assert derived["turns"] == 3
    assert derived["input_tokens"] == 8 + 10
    assert derived["output_tokens"] == 376 + 233
    assert derived["cache_read_tokens"] == 182619 + 14273
    assert derived["model"] == "claude-haiku-5-5,claude-sonnet-5-5"
    assert derived["cost_usd"] is None  # Cortex reports no cost; it is not estimated


def test_parser_falls_back_to_the_init_model_and_reads_claude_cost_and_usage():
    # The shape `claude -p --output-format json` prints (the fields run.sh's _report_run reads), after an init.
    stream = "\n".join(
        json.dumps(e)
        for e in [
            {"type": "system", "subtype": "init", "model": "claude-opus-5-5"},
            {
                "type": "result",
                "subtype": "success",
                "total_cost_usd": 0.4321,
                "num_turns": 7,
                "usage": {"input_tokens": 12, "output_tokens": 345, "cache_read_input_tokens": 9},
            },
        ]
    )
    derived = history.parse_result(stream)
    assert (derived["cost_usd"], derived["turns"]) == (0.4321, 7)
    assert (derived["input_tokens"], derived["output_tokens"], derived["cache_read_tokens"]) == (12, 345, 9)
    assert derived["model"] == "claude-opus-5-5"
    assert history.parse_result("")["model"] is None


def test_cli_record_derives_from_the_result_file_and_stamps_the_sha(tmp_path):
    store = tmp_path / "h.jsonl"
    code = history.main(
        [
            "--record",
            "--harness",
            "cortex-agents",
            "--case",
            "assume",
            "--verdict",
            "pass",
            "--result",
            str(RECORDED / "stream-alias.jsonl"),
            "--sha",
            "deadbeefcafe",
            "--path",
            str(store),
        ]
    )
    assert code == 0
    rec = json.loads(store.read_text())
    assert (rec["harness"], rec["case"], rec["verdict"], rec["git_sha"]) == (
        "cortex-agents",
        "assume",
        "pass",
        "deadbeefcafe",
    )
    assert (rec["turns"], rec["input_tokens"], rec["output_tokens"]) == (2, 6, 167)
    assert rec["model"] == "claude-sonnet-5-5"


def test_record_without_a_result_still_records_a_skip_with_its_reason(tmp_path):
    store = tmp_path / "h.jsonl"
    history.main(
        [
            "--record",
            "--harness",
            "h",
            "--case",
            "P1",
            "--verdict",
            "skip",
            "--reason",
            "claude unavailable",
            "--sha",
            "abc",
            "--path",
            str(store),
        ]
    )
    rec = json.loads(store.read_text())
    assert rec["verdict"] == "skip" and rec["reason"] == "claude unavailable" and rec["cost_usd"] is None


def test_record_requires_harness_case_and_verdict(tmp_path):
    assert history.main(["--record", "--harness", "h", "--path", str(tmp_path / "h.jsonl")]) == 2


def test_make_record_stamps_a_utc_second_resolution_ts():
    now = datetime(2026, 11, 2, 3, 4, 5, 678, tzinfo=timezone.utc)
    assert history.make_record("h", "c", "pass", now=now)["ts"] == "2026-11-02T03:04:05Z"
