"""Tests for the eval sweep's `borg next` item: the pure decisions (sweeprow) and the fail-open file read (shell)."""

from __future__ import annotations

import ast
import json
import os
from datetime import datetime, timezone
from pathlib import Path

import pytest

from borg_core.evals.sweep import core as sweep_core
from borg_core.nextpick import shell, sweeprow

DAY = 86400
NOW = 1_800_000_000.0
LOOK = "LOOK-CMD"


def doc(*cases, attention=None, halted="", **over):
    rows = [{"harness": h, "case": c, "verdict": v, "reason": r, "cost_usd": None} for h, c, v, r in cases]
    bad = any(v != "pass" for _h, _c, v, _r in cases)
    out = {
        "schema": 1,
        "ts": "x",
        "cases": rows,
        "needs_attention": bad if attention is None else attention,
        "halted": halted,
        "futureKey": 1,
    }
    out.update(over)
    return out


def items(present=True, d=None, ts_age_days=1.0, installed_days=None, now=NOW):
    ts = None if ts_age_days is None else now - ts_age_days * DAY
    inst = None if installed_days is None else now - installed_days * DAY
    return sweeprow.sweep_items(present, d, now, ts, inst, LOOK)


def test_schema_and_stale_window_are_pinned_to_the_writer():
    assert sweeprow.SWEEP_SCHEMA == sweep_core.SCHEMA_VERSION == 1
    assert sweeprow.STALE_DAYS == 8


def test_a_clean_recent_sweep_raises_nothing():
    assert items(d=doc(("h", "c", "pass", ""))) == []


@pytest.mark.parametrize("verdict", ["skip", "error", "fail"])
def test_a_non_pass_case_raises_a_you_item_naming_case_reason_and_the_command(verdict):
    (item,) = items(d=doc(("link-next", "next-rows-chooser", verdict, "budget: over the cap")))
    assert item["owner"] == "YOU"
    assert f"link-next/next-rows-chooser {verdict} (budget: over the cap)" in item["text"]
    assert item["text"].endswith(f"Look: {LOOK}")


def test_many_bad_cases_are_cut_to_three_and_counted():
    cases = [("h", f"c{i}", "fail", "") for i in range(5)]
    (item,) = items(d=doc(*cases))
    assert "h/c2 fail" in item["text"] and "h/c3" not in item["text"] and "+2 more" in item["text"]


def test_a_halted_sweep_says_so():
    (item,) = items(d=doc(("h", "c", "skip", "halted"), halted="usage guardian: halted"))
    assert "was halted: usage guardian: halted" in item["text"]


def test_a_failing_sweep_is_raised_even_when_the_agent_is_not_installed():
    assert len(items(d=doc(("h", "c", "fail", "")), installed_days=None)) == 1


def test_stale_needs_the_agent_installed_and_beats_the_old_failure():
    old = doc(("h", "c", "fail", ""))
    assert "no eval sweep for 9 days" in items(d=old, ts_age_days=9.5, installed_days=30)[0]["text"]
    assert items(d=doc(("h", "c", "pass", "")), ts_age_days=9.5, installed_days=None) == []


def test_the_boundary_is_eight_days():
    clean = doc(("h", "c", "pass", ""))
    assert items(d=clean, ts_age_days=8.0, installed_days=30) == []
    assert len(items(d=clean, ts_age_days=8.01, installed_days=30)) == 1


def test_a_missing_file_has_a_grace_period_and_never_nags_an_agent_that_is_not_installed():
    assert items(present=False, installed_days=None) == []
    assert items(present=False, installed_days=0.1) == []
    assert items(present=False, installed_days=8.0) == []
    (item,) = items(present=False, installed_days=9.0)
    assert "installed 9 days ago and has never produced a sweep" in item["text"]


@pytest.mark.parametrize(
    "bad",
    [
        None,
        [],
        "x",
        {"schema": 2, "needs_attention": False, "cases": []},
        {"schema": 1, "cases": []},
        {"schema": 1, "needs_attention": "yes", "cases": []},
        {"schema": 1, "needs_attention": True, "cases": [1]},
    ],
)
def test_unreadable_documents_are_raised_only_while_the_agent_is_installed(bad):
    assert items(d=bad, installed_days=None) == []
    (item,) = items(d=bad, installed_days=1)
    assert "unreadable" in item["text"]


def test_an_unparseable_ts_with_a_good_document_is_unreadable_not_clean():
    assert "unreadable" in items(d=doc(("h", "c", "pass", "")), ts_age_days=None, installed_days=1)[0]["text"]


def test_sweeprow_imports_only_pure_modules():
    tree = ast.parse(Path(sweeprow.__file__).read_text())
    roots = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            roots.update(a.name.split(".")[0] for a in node.names)
        elif isinstance(node, ast.ImportFrom):
            roots.add((node.module or "").split(".")[0])
    assert roots == {"__future__", "typing"}


# ── the shell read ────────────────────────────────────────────────────────────────────────────


def write_sweep(text: str) -> None:
    target = shell.sweep_path()
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text)


def iso(epoch: float) -> str:
    return datetime.fromtimestamp(epoch, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def test_the_shell_raises_from_a_real_file_and_the_row_reaches_queen_owned():
    write_sweep(json.dumps(doc(("link-next", "c1", "skip", "budget"), ts=iso(NOW - 3600))))
    got = shell.sweep_items(NOW)
    assert len(got) == 1 and "link-next/c1 skip (budget)" in got[0]["text"]
    assert "python3 -m borg_core.evals.history --report" in got[0]["text"]


@pytest.mark.parametrize("text", ["", "{", "[]", "null", '{"schema": 1}', "\x00\xff"])
def test_a_malformed_file_never_raises_and_gives_no_item_without_an_agent(text):
    write_sweep(text)
    assert shell.sweep_items(NOW) == []


def test_an_installed_agent_with_a_malformed_file_raises_unreadable(tmp_path):
    plist = Path(os.environ["BORG_LAUNCH_AGENTS_DIR"]) / "com.x.borg.eval-sweep.plist"
    plist.write_text("x")
    write_sweep("{")
    got = shell.sweep_items(plist.stat().st_mtime + 60)
    assert len(got) == 1 and "unreadable" in got[0]["text"]


def test_a_missing_file_and_an_unreadable_directory_give_no_item(monkeypatch):
    assert shell.sweep_items(NOW) == []
    monkeypatch.setattr(shell, "sweep_path", lambda: (_ for _ in ()).throw(RuntimeError("boom")))
    assert shell.sweep_items(NOW) == []


def test_queen_owned_carries_the_sweep_item_after_the_checkpoint_items(monkeypatch):
    monkeypatch.setattr(shell.link_shell, "read_latest_checkpoint", lambda _s: ("", None))
    write_sweep(json.dumps(doc(("h", "c", "fail", ""), ts=iso(datetime.now(timezone.utc).timestamp()))))
    got = shell.queen_owned()
    assert [i["owner"] for i in got["queen"]["items"]] == ["YOU"]
