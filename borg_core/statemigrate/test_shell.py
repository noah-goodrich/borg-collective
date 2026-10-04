"""Shell + cli against a fully sandboxed HOME / XDG dirs. Nothing here may touch the real machine."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from borg_core.statemigrate import cli, shell


@pytest.fixture(name="roots")
def _roots(tmp_path, monkeypatch):
    for var, sub in (
        ("HOME", "home"),
        ("XDG_CONFIG_HOME", "config"),
        ("XDG_STATE_HOME", "state"),
        ("XDG_DATA_HOME", "data"),
    ):
        monkeypatch.setenv(var, str(tmp_path / sub))
    monkeypatch.delenv("BORG_DIR", raising=False)
    old, new = tmp_path / "config" / "borg", tmp_path / "state" / "borg"
    old.mkdir(parents=True)
    return old, new


def _put(root: Path, rel: str, text: str) -> None:
    (root / rel).parent.mkdir(parents=True, exist_ok=True)
    (root / rel).write_text(text)


def test_move_when_absent_at_new(roots):
    old, new = roots
    _put(old, "cortex-wakes.json", '{"a": 1}')
    _put(old, "recon/last-run", "123")
    _put(old, "devcontainer-hashes/p.hash", "h")
    cli.main([])
    assert json.loads((new / "cortex-wakes.json").read_text()) == {"a": 1}
    assert (new / "recon/last-run").read_text() == "123"
    assert (new / "devcontainer-hashes/p.hash").read_text() == "h"
    assert not (old / "cortex-wakes.json").exists()


def test_append_old_history_first_and_keep_new_for_json(roots):
    old, new = roots
    _put(old, "agents.jsonl", '{"id":1}\n')
    _put(new, "agents.jsonl", '{"id":2}\n')
    _put(old, "usage-guardian.json", '{"v":"old"}')
    _put(new, "usage-guardian.json", '{"v":"new"}')
    cli.main([])
    assert (new / "agents.jsonl").read_text() == '{"id":1}\n{"id":2}\n'
    assert json.loads((new / "usage-guardian.json").read_text()) == {"v": "new"}
    assert not (old / "agents.jsonl").exists() and not (old / "usage-guardian.json").exists()


def test_backup_taken_before_removal(roots):
    old, new = roots
    _put(old, "memory-hits.log", "x\n")
    _put(new, "memory-hits.log", "y\n")
    cli.main([])
    (stamp,) = (new / "tidy-backups").iterdir()
    assert (stamp / "memory-hits.log").read_text() == "x\n"
    assert (stamp / "memory-hits.log.new").read_text() == "y\n"


def test_second_run_is_a_noop_and_makes_no_backup_dir(roots, capsys):
    old, new = roots
    _put(old, "agents.jsonl", "a\n")
    cli.main([])
    before = sorted(p.name for p in (new / "tidy-backups").iterdir())
    capsys.readouterr()
    cli.main([])
    assert "nothing to migrate" in capsys.readouterr().out
    assert sorted(p.name for p in (new / "tidy-backups").iterdir()) == before


def test_dry_run_touches_nothing(roots, capsys):
    old, new = roots
    _put(old, "agents.jsonl", "a\n")
    cli.main(["--dry-run"])
    assert "would move" in capsys.readouterr().out
    assert (old / "agents.jsonl").exists()
    assert not new.exists()


def test_stays_files_untouched(roots):
    old, new = roots
    for rel in ("registry.json", "config.zsh", "extensions/x.md", "desktop/s.json", "launchd-prefix"):
        _put(old, rel, "keep")
    _put(old, "agents.jsonl", "a\n")
    cli.main([])
    for rel in ("registry.json", "config.zsh", "extensions/x.md", "desktop/s.json", "launchd-prefix"):
        assert (old / rel).read_text() == "keep"
        assert not (new / rel).exists()


def test_failed_verification_keeps_old_copy(roots, capsys):
    old, new = roots
    _put(old, "cortex-wakes.json", "{not json")
    with pytest.raises(SystemExit) as exc:
        cli.main([])
    assert exc.value.code == 1
    assert (old / "cortex-wakes.json").exists()
    assert "FAILED" in capsys.readouterr().err


def test_discover_uses_both_roots_for_families(roots):
    old, new = roots
    _put(old, "briefing-a-stderr.log", "1")
    _put(new, "devcontainer-hashes/z.hash", "2")
    got = {e.rel: (e.old_present, e.new_present) for e in shell.discover(old, new)}
    assert got["briefing-a-stderr.log"] == (True, False)
    assert got["devcontainer-hashes/z.hash"] == (False, True)


def test_discover_briefing_stderr_log_exact_name(roots):
    """Verify discovery of briefing-stderr.log (the plain name, not a staged variant)."""
    old, new = roots
    _put(old, "briefing-stderr.log", "old stderr")
    got = {e.rel: (e.old_present, e.new_present) for e in shell.discover(old, new)}
    assert got["briefing-stderr.log"] == (True, False)
