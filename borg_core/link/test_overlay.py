"""The overlay entry point prints what `borg link` builds its view from, summaries from checkpoints."""

import io
import json

import pytest

from borg_core.link import overlay, shell


def _checkpointed(tmp_path, name, body):
    """A registry entry whose directory holds one real checkpoint with `body`."""
    store = tmp_path / name / ".borg" / "checkpoints"
    store.mkdir(parents=True)
    (store / "2026-10-01-0900.md").write_text(body, encoding="utf-8")
    return {"path": str(tmp_path / name), "status": "idle", "summary": "stale registry sentence"}


def test_main_prints_the_link_overlay_as_json(monkeypatch, capsys):
    doc = {"projects": {"a": {"status": "waiting", "path": "/x"}}}
    monkeypatch.setattr(shell, "registry_with_state", lambda: doc)
    assert overlay.main([]) == 0
    out = json.loads(capsys.readouterr().out)
    assert out["projects"]["a"] == {"status": "waiting", "path": "/x", "summary": None}


def test_overlay_summary_is_the_checkpoint_tldr_not_the_stored_one(monkeypatch, capsys, tmp_path):
    entry = _checkpointed(tmp_path, "a", "# Checkpoint\n\n**tl;dr** -- shipped the front door.\n")
    monkeypatch.setattr(shell, "registry_with_state", lambda: {"projects": {"a": entry}})
    assert overlay.main([]) == 0
    assert json.loads(capsys.readouterr().out)["projects"]["a"]["summary"] == "shipped the front door."


def test_summaries_mode_derives_every_repository_from_stdin(monkeypatch, capsys, tmp_path):
    registry = {
        "projects": {
            "a": _checkpointed(tmp_path, "a", "**tl;dr** -- first.\n"),
            "b": _checkpointed(tmp_path, "b", "## Accomplished\n- the bullet\n"),
            "c": {"path": str(tmp_path / "none"), "summary": "stale"},
        }
    }
    monkeypatch.setattr("sys.stdin", io.StringIO(json.dumps(registry)))
    assert overlay.main(["--summaries"]) == 0
    got = json.loads(capsys.readouterr().out)["projects"]
    assert {name: row["summary"] for name, row in got.items()} == {"a": "first.", "b": "the bullet", "c": None}


def test_summary_mode_prints_one_repository_and_nothing_for_none(monkeypatch, capsys, tmp_path):
    registry = {"projects": {"a": _checkpointed(tmp_path, "a", "**tl;dr** -- only this.\n"), "b": {"path": "/x"}}}
    monkeypatch.setattr(shell, "read_registry", lambda: registry)
    assert overlay.main(["--summary", "a"]) == 0
    assert capsys.readouterr().out == "only this.\n"
    assert overlay.main(["--summary", "b"]) == 0
    assert capsys.readouterr().out == "\n"
    assert overlay.main(["--summary", "missing"]) == 0
    assert capsys.readouterr().out == "\n"


@pytest.mark.parametrize("args", [["--nope"], ["--summary"], ["--summary", "a", "b"]])
def test_unknown_arguments_exit_two(args, capsys):
    assert overlay.main(args) == 2
    assert "usage" in capsys.readouterr().err
