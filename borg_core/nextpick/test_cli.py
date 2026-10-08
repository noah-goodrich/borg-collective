"""CLI + shell tests: one row per run, fail-open, no stdout."""

from __future__ import annotations

import io
import json
from pathlib import Path

import pytest

from borg_core.nextpick import cli, shell

REGISTRY = {
    "projects": {
        "a": {"status": "waiting", "last_activity": "2026-09-01"},
        "b": {"status": "idle", "last_activity": "2026-10-01"},
    }
}


@pytest.fixture(name="state")
def _state(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    monkeypatch.setenv("XDG_STATE_HOME", str(tmp_path))
    return tmp_path / "borg" / "next-recs.jsonl"


def _run(monkeypatch: pytest.MonkeyPatch, argv: list[str], stdin: str | None = None) -> int:
    monkeypatch.setattr("sys.stdin", io.StringIO(json.dumps(REGISTRY) if stdin is None else stdin))
    return cli.main(argv)


def _rows(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text().splitlines()]


def test_pick_row(state, monkeypatch, capsys):
    assert _run(monkeypatch, ["--pick", "2", "--active", "b", "--session", "s1"]) == 0
    (row,) = _rows(state)
    assert (row["chooser"], row["scripted"], row["switch"], row["shown"]) == (True, True, False, False)
    assert (row["rec"], row["opened"], row["opened_after_s"], row["active"]) == ("a", "b", 0, "b")
    assert capsys.readouterr().out == ""


def test_bare_row_has_null_rec_and_opened(state, monkeypatch):
    _run(monkeypatch, [])
    (row,) = _rows(state)
    assert row["chooser"] is False and row["rec"] is None and row["opened"] is None and row["active"] is None
    assert [item["project"] for item in row["top3"]] == ["a", "b"]


def test_switch_row(state, monkeypatch):
    _run(monkeypatch, ["--switch"])
    assert _rows(state)[0]["switch"] is True


def test_out_of_range_pick_has_no_opened(state, monkeypatch):
    _run(monkeypatch, ["--pick", "9"])
    assert _rows(state)[0]["opened"] is None


@pytest.mark.parametrize("stdin", ["not json", "", "[]"])
def test_garbage_stdin_is_fail_open(state, monkeypatch, stdin):
    assert _run(monkeypatch, [], stdin) == 0
    assert not state.exists() or state.read_text() == ""


def test_bad_flag_is_fail_open(state, monkeypatch):
    assert _run(monkeypatch, ["--pick", "x"]) == 0
    assert not state.exists()


def test_unwritable_state_dir(tmp_path, monkeypatch):
    blocker = tmp_path / "file"
    blocker.write_text("x")
    monkeypatch.setenv("XDG_STATE_HOME", str(blocker))
    assert shell.append_row({"a": 1}) is False
    assert _run(monkeypatch, []) == 0


def test_unserialisable_row(state):
    assert shell.append_row({"a": object()}) is False
    assert not state.exists() or state.read_text() == ""


def test_chooser_quit_row_has_null_opened(state, monkeypatch):
    _run(monkeypatch, ["--chooser", "--shown"])
    (row,) = _rows(state)
    assert (row["chooser"], row["scripted"], row["shown"]) == (True, False, True)
    assert (row["rec"], row["opened"], row["opened_after_s"]) == ("a", None, None)


def test_chooser_open_row_carries_opened_and_elapsed(state, monkeypatch):
    _run(monkeypatch, ["--chooser", "--opened", "b", "--opened-after", "3"])
    (row,) = _rows(state)
    assert (row["rec"], row["opened"], row["opened_after_s"], row["shown"]) == ("a", "b", 3.0, False)


PR_ITEM = {"state": "open", "ref": "o/r#7", "title": "feat: ship it", "checks": "pass", "mergeable": "MERGEABLE"}
PLAN = "# Project Plan: `Chooser plan`\n\n- [ ] **AC1 — Do the thing.** more\n"


def _plan_registry(tmp_path: Path) -> dict:
    """a waits (and has an open PR), b has a plan, c has a checkpoint, d is idle and empty."""
    for name in "abcd":
        (tmp_path / name / ".borg" / "checkpoints").mkdir(parents=True)
    (tmp_path / "b" / "PROJECT_PLAN.md").write_text(PLAN)
    (tmp_path / "c" / ".borg" / "checkpoints" / "2026-10-01-0900.md").write_text("## 5. Next Session\n\n1. write it\n")
    return {
        "projects": {
            "a": {
                "status": "waiting",
                "waiting_reason": "needs a call",
                "last_activity": "2026-09-01",
                "path": str(tmp_path / "a"),
            },
            "b": {"status": "idle", "last_activity": "2026-10-01", "path": str(tmp_path / "b")},
            "c": {"status": "idle", "last_activity": "2026-09-30", "path": str(tmp_path / "c")},
            "d": {"status": "idle", "last_activity": "2026-09-29", "path": str(tmp_path / "d")},
        }
    }


def _wire(monkeypatch, registry, items=None, note=None, log_rows=()):
    seen = []

    def fake_recon(_projects, local):
        seen.append(local)
        return ({} if local else (items or {})), note

    monkeypatch.setattr(shell, "recon_items", fake_recon)
    monkeypatch.setattr(shell, "read_log_rows", lambda: list(log_rows))
    monkeypatch.setattr("sys.stdin", io.StringIO(json.dumps(registry)))
    return seen


def _rows_run(monkeypatch, capsys, registry, items=None, note=None, argv=("--rows",), log_rows=()):
    seen = _wire(monkeypatch, registry, items, note, log_rows)
    assert cli.main(list(argv)) == 0
    return capsys.readouterr().out, seen


def _json_run(monkeypatch, capsys, registry, items=None, note=None, argv=("--rows", "--json"), log_rows=()):
    out, seen = _rows_run(monkeypatch, capsys, registry, items, note, argv, log_rows)
    return json.loads(out), seen


def test_rows_json_payload_has_you_and_agent_quiet_rows(state, monkeypatch, capsys, tmp_path):
    payload, _ = _json_run(monkeypatch, capsys, _plan_registry(tmp_path), {"a": [PR_ITEM]})
    assert set(payload) == {"rows", "rec", "suggestion", "quiet", "degraded"}
    assert [(r["n"], r["project"], r["owner"]) for r in payload["rows"]] == [
        (1, "a", "YOU"),
        (2, "a", "YOU"),
        (3, "c", "—"),
        (4, "b", "AGENT"),
    ]
    session, merge, step, plan = payload["rows"]
    assert set(session) == {
        "n",
        "project",
        "item",
        "next_step",
        "owner",
        "ready",
        "ref",
        "age",
        "status",
        "waiting_reason",
    }
    assert (session["next_step"], session["waiting_reason"], session["status"]) == (
        "reply to session",
        "needs a call",
        "waiting",
    )
    assert (merge["next_step"], merge["item"], merge["ref"]) == ("merge #7", "ship it", "o/r#7")
    assert (plan["item"], plan["next_step"].startswith("AC1")) == ("Chooser plan", True)
    assert step["next_step"] == "write it"
    assert payload["quiet"] == ["d"]
    assert payload["rec"] == "a" and payload["suggestion"] is None and payload["degraded"] is None
    assert not state.exists()


def test_rows_json_suggestion_is_row_number_once_gate_passes(state, monkeypatch, capsys, tmp_path):
    registry = _plan_registry(tmp_path)
    followed = [{"chooser": True, "scripted": False, "opened": "a", "rec": "a"}] * 20
    assert _json_run(monkeypatch, capsys, registry, log_rows=followed)[0]["suggestion"] == 1
    assert _json_run(monkeypatch, capsys, registry, log_rows=followed[:19])[0]["suggestion"] is None


def test_rows_json_local_skips_the_sweep(state, monkeypatch, capsys, tmp_path):
    payload, seen = _json_run(
        monkeypatch, capsys, _plan_registry(tmp_path), {"a": [PR_ITEM]}, argv=("--rows", "--json", "--local")
    )
    assert seen == [True]
    assert [r["next_step"] for r in payload["rows"]][:1] == ["reply to session"]
    assert all(not r["next_step"].startswith("merge") for r in payload["rows"])


def test_rows_json_degraded_sweep_keeps_the_other_sources(state, monkeypatch, capsys, tmp_path):
    payload, _ = _json_run(monkeypatch, capsys, _plan_registry(tmp_path), note="sweep: no recon adapters found")
    assert payload["degraded"] == "sweep: no recon adapters found"
    assert [r["project"] for r in payload["rows"]] == ["a", "c", "b"]


def test_rows_mode_prints_item_rows_quiet_line_then_names_line(state, monkeypatch, capsys, tmp_path):
    out, seen = _rows_run(monkeypatch, capsys, _plan_registry(tmp_path), {"a": [PR_ITEM]})
    lines = out.splitlines()
    assert lines[0] == "WHERE COULD YOUR FOCUS GO?"
    assert any(line.startswith(" 2 a · ship it") and "merge #7" in line for line in lines)
    assert "+1 quiet: d" in lines
    assert lines[-1] == "names\ta\ta\tc\tb"
    assert seen == [False]
    assert all(len(line) <= 59 for line in lines)
    assert not state.exists()


def test_rows_mode_passes_local_through(state, monkeypatch, capsys, tmp_path):
    _, seen = _rows_run(monkeypatch, capsys, _plan_registry(tmp_path), argv=("--rows", "--local"))
    assert seen == [True]


def test_recon_items_local_runs_no_sweep(monkeypatch):
    def boom(*_a, **_k):
        raise AssertionError("swept under --local")

    monkeypatch.setattr(shell.link_shell, "sweep", boom)
    assert shell.recon_items({"a": {}}, True) == ({}, None)


def test_recon_items_groups_items_and_flags_a_failed_source(monkeypatch):
    tracks = [
        {"source": "github", "ok": True, "items": [{"project": "a", "ref": "o/r#1"}]},
        {"source": "slack", "ok": False, "items": []},
    ]
    monkeypatch.setattr(shell.link_shell, "sweep", lambda projects: {"swept": True, "tracks": tracks})
    items, note = shell.recon_items({"a": {}, "z": {"status": "archived"}}, False)
    assert items == {"a": [{"project": "a", "ref": "o/r#1"}]}
    assert note == "sweep source failed: slack"


def test_recon_items_unswept_and_raising_sweeps_degrade(monkeypatch):
    monkeypatch.setattr(shell.link_shell, "sweep", lambda projects: {"swept": False, "tracks": [], "warnings": ["w1"]})
    assert shell.recon_items({"a": {}}, False) == ({}, "w1")

    def boom(_projects):
        raise OSError("down")

    monkeypatch.setattr(shell.link_shell, "sweep", boom)
    assert shell.recon_items({"a": {}}, False) == ({}, "sweep failed: down")


def test_recon_items_never_writes_the_last_run_marker(monkeypatch):
    def marker(*_a, **_k):
        raise AssertionError("marker written")

    monkeypatch.setattr(shell.link_shell.recon_shell, "write_last_run_marker", marker)
    monkeypatch.setattr(shell.link_shell, "sweep", lambda projects: {"swept": True, "tracks": []})
    assert shell.recon_items({"a": {}}, False) == ({}, None)


def test_plan_name_prefers_title_then_slug_then_fallback():
    assert shell.plan_name("# Project Plan: `Foo bar`\n- Plan-slug: x\n", "p") == "Foo bar"
    assert shell.plan_name("- Plan-slug: `my-slug`\n", "p") == "my-slug"
    assert shell.plan_name("nothing", "p") == "p"


def test_read_plans_finds_root_and_docs_plans(tmp_path):
    (tmp_path / "r").mkdir()
    (tmp_path / "r" / "PROJECT_PLAN.md").write_text("# Project Plan: Root\n")
    (tmp_path / "d" / "docs" / "plans").mkdir(parents=True)
    (tmp_path / "d" / "docs" / "plans" / "PROJECT_PLAN.md").write_text("# Project Plan: Deep\n")
    projects = {"r": {"path": str(tmp_path / "r")}, "d": {"path": str(tmp_path / "d")}, "n": {"path": "null"}}
    got = shell.read_plans(projects, ["r", "d", "n", "missing"])
    assert {k: v["name"] for k, v in got.items()} == {"r": "Root", "d": "Deep"}


def test_read_log_rows_reads_rotated_then_live(state):
    state.parent.mkdir(parents=True)
    state.with_name(state.name + ".1").write_text('{"n": 1}\nbad\n')
    state.write_text('{"n": 2}\n')
    assert shell.read_log_rows() == [{"n": 1}, {"n": 2}]


def test_rows_json_is_valid_json_even_when_everything_fails(state, monkeypatch, capsys):
    def boom(*_a, **_k):
        raise RuntimeError("down")

    monkeypatch.setattr(shell, "recon_items", boom)
    monkeypatch.setattr("sys.stdin", io.StringIO("not json"))
    assert cli.main(["--rows", "--json"]) == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload["rows"] == [] and payload["rec"] is None and payload["suggestion"] is None


def test_unmeasured_logs_null_opened_after(state):
    args, _ = cli._parser().parse_known_args(["--chooser", "--opened", "a", "--unmeasured"])
    row = cli.build_row(args, REGISTRY["projects"], __import__("datetime").datetime(2026, 1, 1))
    assert row["opened"] == "a" and row["opened_after_s"] is None and row["scripted"] is False


def _checkpointed_registry(tmp_path: Path) -> dict:
    store = tmp_path / "proj" / ".borg" / "checkpoints"
    store.mkdir(parents=True)
    (store / "2026-10-01-0900.md").write_text("## 5. Next Session\n\n1. old step\n")
    newest = "tl;dr nothing\n\n## 5. Next Session\n\n1. ship the   chooser\n2. two\n"
    (store / "2026-10-02-0900.md").write_text(newest)
    return {
        "projects": {
            "p": {"status": "idle", "last_activity": "2026-10-01T00:00:00Z", "path": str(tmp_path / "proj")},
            "q": {"status": "idle", "path": str(tmp_path / "nope")},
        }
    }


def test_checkpoint_next_steps_reads_the_latest_checkpoint(tmp_path):
    reg = _checkpointed_registry(tmp_path)
    assert shell.checkpoint_next_steps(reg["projects"], ["p", "q"]) == {"p": "ship the chooser"}


def test_checkpoint_next_steps_is_fail_open(monkeypatch):
    def boom(*_a, **_k):
        raise OSError("denied")

    monkeypatch.setattr(shell.link_shell, "read_latest_checkpoint_head", boom)
    assert shell.checkpoint_next_steps({"p": {"path": "/x"}}, ["p"]) == {}


def test_rows_json_checkpoint_fallback_keeps_a_row_out_of_quiet(state, monkeypatch, capsys, tmp_path):
    reg = _checkpointed_registry(tmp_path)
    payload, _ = _json_run(monkeypatch, capsys, reg)
    assert [r["project"] for r in payload["rows"]] == ["p"]
    assert payload["rows"][0]["next_step"] == "ship the chooser"
    assert payload["quiet"] == ["q"]
