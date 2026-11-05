"""Tests for the sweep shell and CLI. No subprocess reaches a model: run_group is replaced by a fake that appends the
history records a harness would, and build_plugin / resolve_claude are stubbed."""

from __future__ import annotations

import json
import os
from pathlib import Path

import pytest

from borg_core.evals import history, runstats
from borg_core.evals.sweep import cli, core, shell


IN_WINDOW = "2026-11-10"
AFTER_WINDOW = "2026-12-06"
GROUPS = (
    ["lifecycle-manifests"]
    + ["link-next"] * 4
    + ["orchestrator-skills", "agent-gates"]
    + ["orchestrator-skills"] * 2
    + ["agent-gates"]
    + ["orchestrator-skills"] * 4
)
N_CASES = 6 + 4 + 4 + 8 + 4 + 3 + 8 + 3 + 3 + 2 + 4
N_RUNS = N_CASES - 2  # RV3 and AD4 ride another case's run


@pytest.fixture(name="sandbox")
def fixture_sandbox(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    monkeypatch.setenv("XDG_STATE_HOME", str(tmp_path / "state"))
    monkeypatch.setenv("BORG_EVAL_HISTORY", str(tmp_path / "history.jsonl"))
    monkeypatch.setenv("BORG_USAGE_SAMPLES", str(tmp_path / "samples.jsonl"))
    monkeypatch.delenv("BORG_USAGE_HALT_ENABLED", raising=False)
    monkeypatch.setenv("BORG_EVAL_SWEEP_MODEL", "")
    repo = tmp_path / "repo"
    for name in ("alpha", "beta", "gamma", "delta"):
        (repo / "evals" / "link-next" / "cases" / name).mkdir(parents=True)
    monkeypatch.setattr(shell, "git_sha", lambda _r: "deadbeef")
    monkeypatch.setattr(shell, "today_utc", lambda: IN_WINDOW)  # the cap depends on the date: freeze it
    monkeypatch.setattr(shell, "resolve_claude", lambda: "/stub/bin/claude")

    def build(_repo, dest):
        dest.mkdir(parents=True)
        return ""

    monkeypatch.setattr(shell, "build_plugin", build)
    return repo


def fake_harness(monkeypatch: pytest.MonkeyPatch, cost, verdict="pass") -> list[tuple[str, tuple[str, ...]]]:
    calls: list[tuple[str, tuple[str, ...]]] = []

    def run(group, _repo, model, env):
        calls.append((group.harness, group.cases))
        assert model == "claude-opus-5-5" and env["EVAL_PLUGIN_DIR"]
        for case in group.cases:
            history.append(
                runstats.make_record(
                    group.harness,
                    case,
                    verdict,
                    git_sha="deadbeef",
                    ts=shell.utc_now(),
                    result_text=json.dumps({"type": "result", "total_cost_usd": cost}) if cost is not None else "",
                )
            )
        return 0

    monkeypatch.setattr(shell, "run_group", run)
    return calls


def summary() -> dict:
    return dict(json.loads(shell.summary_path().read_text()))


def test_full_sweep_runs_every_group_and_writes_the_summary(sandbox, monkeypatch):
    calls = fake_harness(monkeypatch, 0.2)
    assert cli.main(["--repo", str(sandbox)]) == 0
    assert [c[0] for c in calls] == GROUPS
    doc = summary()
    assert tuple(doc) == tuple(sorted(core.SUMMARY_KEYS))  # sort_keys on disk
    assert doc["model"] == "claude-opus-5-5" and doc["git_sha"] == "deadbeef"
    assert doc["cap_usd"] == 15.0
    # RV3 and AD4 share another case's run, so their (duplicate) recorded cost must not be counted a second time
    assert doc["spend_usd"] == pytest.approx(N_RUNS * 0.2)
    assert doc["counts"]["pass"] == N_CASES and doc["needs_attention"] is False


def test_each_row_names_its_model_and_agent_gates_reports_the_agents_own_pin(sandbox, monkeypatch):
    fake_harness(monkeypatch, 0.2)
    cli.main(["--repo", str(sandbox)])
    by = {(c["harness"], c["case"]): c for c in summary()["cases"]}
    assert by[("agent-gates", "V1")]["model"] == "agent-frontmatter"
    assert by[("lifecycle-manifests", "P1")]["model"] == "claude-opus-5-5"
    assert by[("orchestrator-skills", "RS1")]["model"] == "claude-opus-5-5"
    assert by[("orchestrator-skills", "RV3")]["cost_usd"] is None  # graded on RV1's run: no cost of its own
    assert by[("orchestrator-skills", "RV1")]["cost_usd"] == 0.2
    assert by[("orchestrator-skills", "AD4")]["cost_usd"] is None and by[("agent-gates", "GR1")]["model"] == (
        "agent-frontmatter"
    )


def test_the_raise_has_expired_after_the_window_and_the_sweep_runs_on_the_old_cap(sandbox, monkeypatch):
    fake_harness(monkeypatch, 0.2)
    monkeypatch.setattr(shell, "today_utc", lambda: AFTER_WINDOW)
    assert cli.main(["--repo", str(sandbox)]) == 1
    doc = summary()
    assert doc["cap_usd"] == 10.0 and doc["counts"]["skip"] > 0 and doc["spend_usd"] <= 10.0


def test_dry_run_prints_the_plan_runs_nothing_and_writes_no_summary(sandbox, monkeypatch, capsys):
    calls = fake_harness(monkeypatch, 0.5)
    assert cli.main(["--repo", str(sandbox), "--dry-run"]) == 0
    out = capsys.readouterr().out
    assert calls == [] and not shell.summary_path().exists()
    assert "cap $15.00" in out and "--case review" in out and "--case break-glass" in out


def test_null_cost_link_next_cases_exhaust_the_cap_and_the_rest_are_skipped_and_recorded(sandbox, monkeypatch):
    calls = fake_harness(monkeypatch, None)
    monkeypatch.setattr(shell, "today_utc", lambda: AFTER_WINDOW)
    assert cli.main(["--repo", str(sandbox)]) == 1
    # lifecycle null-cost counts 9.0; 9.0 + 1.5 > 10 so every link-next case skips; the step-3a groups skip too.
    assert len(calls) == 1
    doc = summary()
    assert doc["counts"]["skip"] == N_CASES - 6 and doc["spend_usd"] == pytest.approx(9.0)
    assert all("sweep cap" in c["reason"] for c in doc["cases"] if c["verdict"] == "skip")
    skips = [r for r in history.read_records()[0] if r["verdict"] == "skip"]
    assert sorted(r["case"] for r in skips if r["harness"] == "link-next") == ["alpha", "beta", "delta", "gamma"]
    assert len(skips) == N_CASES - 6


def test_a_failed_case_is_reported_and_the_exit_is_nonzero(sandbox, monkeypatch):
    fake_harness(monkeypatch, 0.2, verdict="fail")
    assert cli.main(["--repo", str(sandbox)]) == 1
    assert summary()["counts"]["fail"] == N_CASES


def test_a_halted_guardian_skips_the_whole_sweep_without_running_anything(sandbox, monkeypatch, tmp_path):
    calls = fake_harness(monkeypatch, 0.5)
    stamp = shell.utc_now()
    sample = {"status": "ok", "session_pct": 97, "ts": stamp}
    (tmp_path / "samples.jsonl").write_text(json.dumps(sample) + "\n")
    assert cli.main(["--repo", str(sandbox)]) == 1
    doc = summary()
    assert calls == [] and "usage guardian" in doc["halted"] and doc["counts"]["skip"] == N_CASES
    assert doc["spend_usd"] == 0
    assert len(history.read_records()[0]) == N_CASES


def test_a_stale_or_malformed_guardian_sample_is_fail_open(sandbox, tmp_path):
    samples = tmp_path / "samples.jsonl"
    samples.write_text(json.dumps({"status": "ok", "session_pct": 99, "ts": "2020-01-01T00:00:00Z"}) + "\n")
    assert shell.guardian_halted(1_900_000_000) is False
    samples.write_text("not json\n")
    assert shell.guardian_halted(1_900_000_000) is False
    samples.unlink()
    assert shell.guardian_halted(1_900_000_000) is False


def test_the_halt_switch_can_be_turned_off(sandbox, monkeypatch, tmp_path):
    (tmp_path / "samples.jsonl").write_text(
        json.dumps({"status": "ok", "session_pct": 99, "ts": shell.utc_now()}) + "\n"
    )
    assert shell.guardian_halted(__import__("time").time()) is True
    monkeypatch.setenv("BORG_USAGE_HALT_ENABLED", "0")
    assert shell.guardian_halted(__import__("time").time()) is False


def test_no_claude_is_an_error_for_every_case(sandbox, monkeypatch):
    calls = fake_harness(monkeypatch, 0.5)
    monkeypatch.setattr(shell, "resolve_claude", lambda: None)
    assert cli.main(["--repo", str(sandbox)]) == 1
    assert calls == [] and summary()["counts"]["error"] == N_CASES


def test_a_failed_plugin_build_is_an_error_for_every_case(sandbox, monkeypatch):
    calls = fake_harness(monkeypatch, 0.5)
    monkeypatch.setattr(shell, "build_plugin", lambda _r, _d: "plugin build exited 1: boom")
    assert cli.main(["--repo", str(sandbox)]) == 1
    doc = summary()
    assert calls == [] and doc["counts"]["error"] == N_CASES and "boom" in doc["cases"][0]["reason"]


def test_a_harness_that_records_nothing_leaves_error_rows_not_a_green_sweep(sandbox, monkeypatch):
    monkeypatch.setattr(shell, "run_group", lambda *_a: 0)
    assert cli.main(["--repo", str(sandbox)]) == 1
    assert summary()["counts"]["error"] >= 6


def test_harness_command_pins_model_cap_one_run_and_one_case():
    argv, env, _t = shell.harness_command(core.Group("link-next", ("c1",)), Path("/r"), "m-1")
    assert argv[2:] == ["--runs", "1", "--model", "m-1", "--max-cost-usd", "1.50", "--case", "c1"] and env == {}
    argv, env, _t = shell.harness_command(core.Group("lifecycle-manifests", core.LIFECYCLE_CASES), Path("/r"), "m-1")
    assert env == {"EVAL_MODEL": "m-1", "EVAL_MAX_BUDGET_USD": "1.50"}


def _plan(link_next=("a",)):
    return {(g.harness, g.selector or g.cases[0]): g for g in core.plan_groups(list(link_next))}


def test_agent_gates_command_passes_no_model_every_case_and_its_own_ceiling():
    group = _plan()[("agent-gates", "NP1")]
    argv, env, _t = shell.harness_command(group, Path("/r"), "m-1")
    assert "--model" not in argv and "m-1" not in argv and "EVAL_MODEL" not in env
    assert argv[2:] == ["--max-budget-usd", "0.50"] + [x for c in core.AGENT_GATES_CASES for x in ("--case", c)]


@pytest.mark.parametrize("selector", ["review", "resume", "break-glass"])
def test_orchestrator_skills_command_selects_one_skill_group_on_the_pinned_model(selector):
    group = _plan()[("orchestrator-skills", selector)]
    argv, env, _t = shell.harness_command(group, Path("/r"), "m-1")
    assert argv[1:] == ["/r/evals/orchestrator-skills/live.sh", "--case", selector]
    assert env == {"EVAL_MODEL": "m-1", "EVAL_MAX_BUDGET_USD": "0.75"}


def test_today_utc_is_the_date_part_of_utc_now_unless_pinned(monkeypatch):
    monkeypatch.setattr(shell, "utc_now", lambda: "2026-11-03T23:59:59Z")
    monkeypatch.delenv("BORG_EVAL_SWEEP_TODAY", raising=False)
    assert shell.today_utc() == "2026-11-03"
    monkeypatch.setenv("BORG_EVAL_SWEEP_TODAY", "2027-01-01")
    assert shell.today_utc() == "2027-01-01"


def test_resolve_claude_prefers_an_absolute_override_then_the_search_dirs(tmp_path, monkeypatch):
    exe = tmp_path / "bin" / "claude"
    exe.parent.mkdir()
    exe.write_text("#!/bin/sh\n")
    exe.chmod(0o755)
    monkeypatch.setenv("PATH", "/usr/bin:/bin")
    monkeypatch.delenv("BORG_CLAUDE_BIN", raising=False)
    monkeypatch.setenv("BORG_CLAUDE_SEARCH_DIRS", str(exe.parent))
    monkeypatch.setattr("shutil.which", lambda _n: None)
    assert shell.resolve_claude() == str(exe)
    monkeypatch.setenv("BORG_CLAUDE_BIN", "relative/claude")
    assert shell.resolve_claude() == str(exe)
    monkeypatch.setenv("BORG_CLAUDE_BIN", str(exe))
    assert shell.resolve_claude() == str(exe)
    assert os.access(exe, os.X_OK)


def test_write_summary_replaces_the_file_whole(sandbox):
    shell.write_summary({"a": 1})
    shell.write_summary({"b": 2})
    assert summary() == {"b": 2}
    assert [p.name for p in shell.summary_path().parent.iterdir() if p.suffix == ".tmp"] == []


def fake_repo(tmp_path: Path, build_body: str, live_body: str = "exit 0") -> Path:
    repo = tmp_path / "frepo"
    (repo / "scripts").mkdir(parents=True)
    (repo / "scripts" / "build-plugin.sh").write_text(build_body + "\n")
    (repo / "evals" / "link-next").mkdir(parents=True)
    (repo / "evals" / "link-next" / "live.sh").write_text(live_body + "\n")
    return repo


def test_build_plugin_passes_the_destination_through_the_override_env(tmp_path):
    repo = fake_repo(tmp_path, 'mkdir -p "$PLUGIN_DIR_OVERRIDE" && touch "$PLUGIN_DIR_OVERRIDE/built"')
    assert shell.build_plugin(repo, tmp_path / "out") == ""
    assert (tmp_path / "out" / "built").is_file()


def test_build_plugin_failure_names_the_exit_and_the_last_line(tmp_path):
    repo = fake_repo(tmp_path, "echo first >&2; echo kaboom >&2; exit 3")
    assert shell.build_plugin(repo, tmp_path / "out") == "plugin build exited 3: kaboom"


def test_run_group_returns_the_harness_exit_code_and_reports_a_missing_script(tmp_path):
    repo = fake_repo(tmp_path, "exit 0", "exit 4")
    group = core.Group("link-next", ("c1",))
    assert shell.run_group(group, repo, "m", dict(os.environ)) == 4
    (repo / "evals" / "link-next" / "live.sh").unlink()
    assert shell.run_group(group, repo, "m", dict(os.environ)) != 0


def test_run_group_times_out_with_124(tmp_path, monkeypatch):
    repo = fake_repo(tmp_path, "exit 0", "sleep 5")
    monkeypatch.setattr(shell, "LINK_NEXT_TIMEOUT_SEC", 0.2)
    assert shell.run_group(core.Group("link-next", ("c1",)), repo, "m", dict(os.environ)) == 124


def test_link_next_cases_are_the_case_directories_sorted(tmp_path):
    assert shell.link_next_cases(tmp_path) == []
    (tmp_path / "evals" / "link-next" / "cases" / "b").mkdir(parents=True)
    (tmp_path / "evals" / "link-next" / "cases" / "a").mkdir()
    (tmp_path / "evals" / "link-next" / "cases" / "f.txt").write_text("x")
    assert shell.link_next_cases(tmp_path) == ["a", "b"]


def test_git_sha_reads_head_and_is_none_outside_a_repo(tmp_path):
    assert shell.git_sha(tmp_path) is None
    assert shell.git_sha(Path(__file__).resolve().parents[3])
