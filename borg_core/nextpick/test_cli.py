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
