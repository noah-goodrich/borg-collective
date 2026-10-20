"""CLI + shell tests: one row per run, fail-open, no stdout."""

from __future__ import annotations

import io
import json
import os
from pathlib import Path

import pytest

from borg_core.nextpick import cli, shell

REGISTRY = {
    "repositories": {
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
        "repositories": {
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

    def fake_recon(_repositories, local):
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
    registry = _plan_registry(tmp_path)
    payload, _ = _json_run(monkeypatch, capsys, registry, {"a": [PR_ITEM]})
    assert set(payload) == {"rows", "rec", "suggestion", "quiet", "degraded", "hidden"}
    assert [(r["n"], r["project"], r["owner"]) for r in payload["rows"]] == [(1, "a", "YOU"), (2, "a", "YOU")]
    assert payload["hidden"] == {"agent": 2, "stale": 0, "overflow": 0}
    session, merge = payload["rows"]
    everything, _ = _json_run(monkeypatch, capsys, registry, {"a": [PR_ITEM]}, argv=("--rows", "--json", "--all"))
    assert everything["hidden"] == {"agent": 0, "stale": 0, "overflow": 0}
    assert [(r["n"], r["project"], r["owner"]) for r in everything["rows"]] == [
        (1, "a", "YOU"),
        (2, "a", "YOU"),
        (3, "c", "AGENT"),
        (4, "b", "AGENT"),
    ]
    step, plan = everything["rows"][2:]
    assert set(session) == {
        "n",
        "project",
        "item",
        "next_step",
        "owner",
        "ready",
        "ref",
        "url",
        "age",
        "status",
        "waiting_reason",
        "card",
    }
    assert session["card"][0] == ("a · " + session["item"] if session["item"] else "a")
    assert session["card"][-1] == "borg next --open a --chosen"
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
    assert [r["project"] for r in payload["rows"]] == ["a"]
    assert payload["hidden"]["agent"] == 2


def test_rows_mode_prints_item_rows_quiet_line_then_names_line(state, monkeypatch, capsys, tmp_path):
    out, seen = _rows_run(monkeypatch, capsys, _plan_registry(tmp_path), {"a": [PR_ITEM]})
    lines = out.splitlines()
    assert lines[0] == "WHERE COULD YOUR FOCUS GO?"
    assert any(line.startswith(" 2 a · ship it") and "merge #7" in line for line in lines)
    assert "+1 quiet: d" in lines
    assert "+2 agent tasks" in lines
    assert lines[-1] == "names\ta\ta"
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
    monkeypatch.setattr(shell.link_shell, "sweep", lambda repositories: {"swept": True, "tracks": tracks})
    items, note = shell.recon_items({"a": {}, "z": {"status": "archived"}}, False)
    assert items == {"a": [{"project": "a", "ref": "o/r#1"}]}
    assert note == "sweep source failed: slack"


def test_recon_items_unswept_and_raising_sweeps_degrade(monkeypatch):
    monkeypatch.setattr(
        shell.link_shell, "sweep", lambda repositories: {"swept": False, "tracks": [], "warnings": ["w1"]}
    )
    assert shell.recon_items({"a": {}}, False) == ({}, "w1")

    def boom(_repositories):
        raise OSError("down")

    monkeypatch.setattr(shell.link_shell, "sweep", boom)
    assert shell.recon_items({"a": {}}, False) == ({}, "sweep failed: down")


def test_recon_items_never_writes_the_last_run_marker(monkeypatch):
    def marker(*_a, **_k):
        raise AssertionError("marker written")

    monkeypatch.setattr(shell.link_shell.recon_shell, "write_last_run_marker", marker)
    monkeypatch.setattr(shell.link_shell, "sweep", lambda repositories: {"swept": True, "tracks": []})
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
    repositories = {"r": {"path": str(tmp_path / "r")}, "d": {"path": str(tmp_path / "d")}, "n": {"path": "null"}}
    got = shell.read_plans(repositories, ["r", "d", "n", "missing"])
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
    row = cli.build_row(args, REGISTRY["repositories"], __import__("datetime").datetime(2026, 1, 1))
    assert row["opened"] == "a" and row["opened_after_s"] is None and row["scripted"] is False


def _checkpointed_registry(tmp_path: Path) -> dict:
    store = tmp_path / "proj" / ".borg" / "checkpoints"
    store.mkdir(parents=True)
    (store / "2026-10-01-0900.md").write_text("## 5. Next Session\n\n1. old step\n")
    newest = "tl;dr nothing\n\n## 5. Next Session\n\n1. ship the   chooser\n2. two\n"
    (store / "2026-10-02-0900.md").write_text(newest)
    return {
        "repositories": {
            "p": {"status": "idle", "last_activity": "2026-10-01T00:00:00Z", "path": str(tmp_path / "proj")},
            "q": {"status": "idle", "path": str(tmp_path / "nope")},
        }
    }


def test_checkpoint_owned_reads_the_whole_latest_checkpoint(tmp_path):
    reg = _checkpointed_registry(tmp_path)
    got = shell.checkpoint_owned(reg["repositories"], ["p", "q"])
    assert list(got) == ["p"]
    assert got["p"]["items"] == [
        {"text": "ship the chooser", "owner": "AGENT"},
        {"text": "two", "owner": "AGENT"},
    ]
    assert got["p"]["mtime"] == (tmp_path / "proj" / ".borg" / "checkpoints" / "2026-10-02-0900.md").stat().st_mtime


def test_checkpoint_owned_is_fail_open(monkeypatch):
    def boom(*_a, **_k):
        raise OSError("denied")

    monkeypatch.setattr(shell.link_shell, "read_latest_checkpoint", boom)
    assert shell.checkpoint_owned({"p": {"path": "/x"}}, ["p"]) == {}


def test_rows_json_checkpoint_fallback_keeps_a_row_out_of_quiet(state, monkeypatch, capsys, tmp_path):
    reg = _checkpointed_registry(tmp_path)
    payload, _ = _json_run(monkeypatch, capsys, reg, argv=("--rows", "--json", "--all"))
    assert [r["project"] for r in payload["rows"]] == ["p", "p"]
    assert [r["next_step"] for r in payload["rows"]] == ["ship the chooser", "two"]
    assert payload["quiet"] == ["q"]
    capped, _ = _json_run(monkeypatch, capsys, reg)
    assert capped["rows"] == [] and capped["hidden"]["agent"] == 2 and capped["quiet"] == ["q"]


def _crowded(tmp_path: Path, count: int = 8) -> tuple[dict, dict]:
    """Two repositories sharing one repo plus a lone one; `count` YOU PRs on `solo`, one stale draft on `a`."""
    registry = {
        "repositories": {
            "a": {"status": "idle", "last_activity": "2026-09-01", "path": str(tmp_path / "a"), "repo": "/g"},
            "a2": {"status": "idle", "last_activity": "2026-09-02", "path": str(tmp_path / "a2"), "repo": "/g"},
            "solo": {"status": "idle", "last_activity": "2026-09-29", "path": str(tmp_path / "s")},
        }
    }
    shared = {**PR_ITEM, "ref": "o/r#1"}
    stale = {**PR_ITEM, "ref": "o/r#2", "draft": True, "changed": "updated 2020-01-01T00:00:00Z; draft"}
    many = [{**PR_ITEM, "ref": f"o/s#{n}", "title": f"pr {n}"} for n in range(10, 10 + count)]
    return registry, {"a": [shared, stale], "a2": [shared], "solo": many}


def test_rows_json_caps_dedupes_and_counts_stale(state, monkeypatch, capsys, tmp_path):
    registry, items = _crowded(tmp_path)
    payload, _ = _json_run(monkeypatch, capsys, registry, items)
    assert [r["n"] for r in payload["rows"]] == [1, 2, 3, 4, 5]
    assert [r["ref"] for r in payload["rows"]] == ["o/r#1", "o/s#10", "o/s#11", "o/s#12", "o/s#13"]
    assert payload["hidden"] == {"agent": 0, "stale": 1, "overflow": 4}


def test_chooser_screen_and_json_agree_and_all_lists_everything(state, monkeypatch, capsys, tmp_path):
    registry, items = _crowded(tmp_path)
    payload, _ = _json_run(monkeypatch, capsys, registry, items)
    out, _ = _rows_run(monkeypatch, capsys, registry, items)
    lines = out.splitlines()
    assert lines[-1] == "names\t" + "\t".join(r["project"] for r in payload["rows"])
    assert "+4 more decisions" in lines and "+1 stale drafts" in lines
    full, _ = _json_run(monkeypatch, capsys, registry, items, argv=("--rows", "--json", "--all"))
    assert len(full["rows"]) == 10 and full["hidden"] == {"agent": 0, "stale": 0, "overflow": 0}
    assert [r["n"] for r in full["rows"]] == list(range(1, 11))
    assert "o/r#2" in [r["ref"] for r in full["rows"]]



def test_nextpick_never_writes_the_glance_cache(state: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """`borg link` is the glance cache's only writer (it alone sees manifest decisions); `--rows` must not touch it."""
    rows = [{"project": "a", "item": "", "next_step": "merge #9", "owner": "YOU", "ready": "", "ref": "o/a#9"}]
    monkeypatch.setattr(cli, "item_rows", lambda *_a, **_k: (rows, [], None, {"agent": 0, "stale": 0, "overflow": 0}))
    cli.rows_json(REGISTRY["repositories"], False)
    assert not (state.parent / "next-glance").exists()
    assert shell.write_glance("x", 1) is True


NEW_FORM = (
    "tl;dr nothing\n\n" + "## 1. Goal\n\n" + "filler\n" * 25 + "\n## 4. Blockers\n\n"
    "Waits on you:\n- **Rotate the key.** Only the owner can.\n- Pick a name\n  for the thing\n\n"
    "## 5. Next Session\n\n1. **Ship it.** Then verify.\n   - sub one\n2. Tidy up\n"
)
LEGACY_FORM = "## 4. Blockers\n\nNo blockers. These wait on Pat:\n\n- Approve the spend\n\n## 5. Next Session\n\n1. Go\n"


def _repo(tmp_path: Path, name: str, *checkpoints: tuple[str, str]) -> dict:
    store = tmp_path / name / ".borg" / "checkpoints"
    store.mkdir(parents=True)
    for filename, text in checkpoints:
        (store / filename).write_text(text)
    return {"status": "idle", "last_activity": "2026-10-01", "path": str(tmp_path / name)}


def _item_rows(registry: dict) -> tuple[list[dict], list[str]]:
    rows, quiet, _degraded, _hidden = cli.item_rows(registry["repositories"], True, show_all=True)
    return rows, quiet


def test_item_rows_reads_wait_items_past_line_20_from_real_checkpoint_files(tmp_path):
    registry = {"repositories": {"p": _repo(tmp_path, "p", ("2026-10-01-0900.md", NEW_FORM))}}
    rows, quiet = _item_rows(registry)
    assert quiet == []
    assert [(r["owner"], r["detail"]) for r in rows] == [
        ("YOU", "**Rotate the key.** Only the owner can."),
        ("YOU", "Pick a name for the thing"),
        ("AGENT", "**Ship it.** Then verify. - sub one"),
        ("AGENT", "Tidy up"),
    ]
    assert all(r["item"] == "" and r["ready"] == "" and r["ref"] is None for r in rows)


def test_item_rows_legacy_form_and_no_blockers_prose(tmp_path):
    registry = {
        "repositories": {
            "legacy": _repo(tmp_path, "legacy", ("2026-10-01-0900.md", LEGACY_FORM)),
            "none": _repo(tmp_path, "none", ("2026-10-01-0900.md", "## 4. Blockers\n\nNo blockers.\n\n## 5. Next Session\n")),
        }
    }
    rows, quiet = _item_rows(registry)
    assert [(r["project"], r["owner"], r["next_step"]) for r in rows] == [
        ("legacy", "YOU", "Approve the spend"),
        ("legacy", "AGENT", "Go"),
    ]
    assert quiet == ["none"]


def test_item_rows_use_the_newest_checkpoint_by_name_not_by_mtime(tmp_path):
    older_name_newer_file = ("2026-10-01-0900.md", "## 5. Next Session\n\n1. old step\n")
    registry = {"repositories": {"p": _repo(tmp_path, "p", ("2026-10-02-0900.md", LEGACY_FORM), older_name_newer_file)}}
    rows, _ = _item_rows(registry)
    assert [r["detail"] for r in rows] == ["Approve the spend", "Go"]


def _age(path: Path, seconds: int) -> None:
    stat = path.stat()
    os.utime(path, (stat.st_atime + seconds, stat.st_mtime + seconds))


@pytest.mark.parametrize("checkpoint_is_newer", [True, False])
def test_item_rows_a_newer_checkpoint_beats_the_plan(tmp_path, checkpoint_is_newer):
    entry = _repo(tmp_path, "p", ("2026-10-01-0900.md", "## 5. Next Session\n\n1. from the checkpoint\n"))
    plan = tmp_path / "p" / "PROJECT_PLAN.md"
    plan.write_text(PLAN)
    _age(tmp_path / "p" / ".borg" / "checkpoints" / "2026-10-01-0900.md", 100 if checkpoint_is_newer else -100)
    rows, _ = _item_rows({"repositories": {"p": entry}})
    expected = ["from the checkpoint"] if checkpoint_is_newer else [rows[0]["next_step"]]
    assert [r["next_step"] for r in rows] == expected
    assert (rows[0]["item"] == "") == checkpoint_is_newer
