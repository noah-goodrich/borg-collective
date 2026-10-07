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


LINK_DOC = {
    "grid": {
        "manifests": [
            {
                "path": "/p/a/.borg/chains/x.json",
                "nodes": {"o/r#1": {"ref": "o/r#1", "state": "open", "ready": True}},
                "gates": [],
                "ready": {"state": "known", "refs": ["o/r#1"]},
            }
        ]
    }
}
PATH_REGISTRY = {
    "projects": {
        "a": {"status": "waiting", "last_activity": "2026-09-01", "path": "/p/a"},
        "b": {"status": "idle", "last_activity": "2026-10-01", "path": "/p/b"},
    }
}


def _rows_run(monkeypatch, capsys, doc, argv=("--rows",)):
    seen = []
    monkeypatch.setattr(shell, "link_document", lambda local: seen.append(local) or doc)
    monkeypatch.setattr("sys.stdin", io.StringIO(json.dumps(PATH_REGISTRY)))
    assert cli.main(list(argv)) == 0
    return capsys.readouterr().out.splitlines(), seen


def test_rows_mode_prints_screen_then_names_line(state, monkeypatch, capsys):
    lines, seen = _rows_run(monkeypatch, capsys, LINK_DOC)
    assert lines[0] == "WHERE COULD YOUR FOCUS GO?"
    assert any(line.startswith(" 1 a · o/r#1") for line in lines)
    assert lines[-1] == "names\ta\tb"
    assert seen == [False]
    assert not state.exists()


def test_rows_mode_passes_local_through(state, monkeypatch, capsys):
    _, seen = _rows_run(monkeypatch, capsys, LINK_DOC, ("--rows", "--local"))
    assert seen == [True]


def test_rows_mode_blank_cells_when_link_build_fails(state, monkeypatch, capsys):
    lines, _ = _rows_run(monkeypatch, capsys, None)
    assert " 1 a" in lines[3] and "o/r#1" not in "".join(lines)
    assert lines[-1] == "names\ta\tb"


def test_link_document_failure_is_none(monkeypatch):
    def boom(*_a, **_k):
        raise OSError("no python")

    monkeypatch.setattr(shell.subprocess, "run", boom)
    assert shell.link_document(True) is None


def test_link_document_runs_in_orchestrator_root(tmp_path, monkeypatch):
    calls = []

    class Done:
        returncode = 0
        stdout = '{"grid": {}}'

    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", str(tmp_path))
    monkeypatch.setattr(shell.subprocess, "run", lambda argv, **kw: calls.append((argv, kw)) or Done())
    assert shell.link_document(True) == {"grid": {}}
    argv, kw = calls[0]
    assert argv[-2:] == ["--json", "--local"]
    assert kw["cwd"] == str(tmp_path.resolve())


def test_read_log_rows_reads_rotated_then_live(state):
    state.parent.mkdir(parents=True)
    state.with_name(state.name + ".1").write_text('{"n": 1}\nbad\n')
    state.write_text('{"n": 2}\n')
    assert shell.read_log_rows() == [{"n": 1}, {"n": 2}]


def test_link_document_uses_the_named_timeout(tmp_path, monkeypatch):
    calls = []

    class Done:
        returncode = 0
        stdout = "{}"

    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", str(tmp_path))
    monkeypatch.setattr(shell.subprocess, "run", lambda argv, **kw: calls.append(kw) or Done())
    shell.link_document(True)
    assert shell.LINK_TIMEOUT_S == 15
    assert calls[0]["timeout"] == 15


def _json_run(monkeypatch, capsys, doc, log_rows=(), argv=("--rows", "--json")):
    monkeypatch.setattr(shell, "link_document", lambda local: doc)
    monkeypatch.setattr(shell, "read_log_rows", lambda: list(log_rows))
    monkeypatch.setattr("sys.stdin", io.StringIO(json.dumps(PATH_REGISTRY)))
    assert cli.main(list(argv)) == 0
    return json.loads(capsys.readouterr().out)


def test_rows_json_payload_shape(state, monkeypatch, capsys):
    payload = _json_run(monkeypatch, capsys, LINK_DOC)
    assert set(payload) == {"rows", "rec", "suggestion"}
    assert payload["rec"] == "a"
    assert payload["suggestion"] is None
    first = payload["rows"][0]
    assert set(first) == {"n", "project", "item", "next_step", "owner", "ready"}
    assert first["n"] == 1 and first["project"] == "a" and first["item"] == "o/r#1"
    assert not state.exists()


def test_rows_json_suggestion_is_row_number_once_gate_passes(state, monkeypatch, capsys):
    followed = [{"chooser": True, "scripted": False, "opened": "a", "rec": "a"}] * 20
    assert _json_run(monkeypatch, capsys, LINK_DOC, followed)["suggestion"] == 1
    below = followed[:19]
    assert _json_run(monkeypatch, capsys, LINK_DOC, below)["suggestion"] is None


def test_rows_json_blank_cells_when_link_build_fails(state, monkeypatch, capsys):
    payload = _json_run(monkeypatch, capsys, None)
    assert [row["project"] for row in payload["rows"]] == ["a", "b"]
    assert all(row["item"] == "" and row["owner"] == "" for row in payload["rows"])


def test_rows_json_is_valid_json_even_when_everything_fails(state, monkeypatch, capsys):
    def boom(*_a, **_k):
        raise RuntimeError("down")

    monkeypatch.setattr(shell, "link_document", boom)
    monkeypatch.setattr("sys.stdin", io.StringIO("not json"))
    assert cli.main(["--rows", "--json"]) == 0
    assert json.loads(capsys.readouterr().out) == {"rows": [], "rec": None, "suggestion": None}


def test_unmeasured_logs_null_opened_after(state):
    args, _ = cli._parser().parse_known_args(["--chooser", "--opened", "a", "--unmeasured"])
    row = cli.build_row(args, PATH_REGISTRY["projects"], __import__("datetime").datetime(2026, 1, 1))
    assert row["opened"] == "a" and row["opened_after_s"] is None and row["scripted"] is False
