"""Tests for borg_core.retention: the Python sibling of lib/borg-hooks.sh::_borg_rotate_log."""

from __future__ import annotations

from pathlib import Path

import pytest

from borg_core import paths, retention


@pytest.fixture(autouse=True)
def _sandbox(tmp_path, monkeypatch):
    """HOME and every XDG dir inside tmp_path: nothing here may resolve to the real machine."""
    monkeypatch.setenv("HOME", str(tmp_path / "home"))
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path / "config"))
    monkeypatch.setenv("XDG_STATE_HOME", str(tmp_path / "state"))
    monkeypatch.setenv("XDG_DATA_HOME", str(tmp_path / "data"))
    (tmp_path / "state" / "borg").mkdir(parents=True)


def _log(tmp_path: Path, size: int) -> Path:
    p = paths.state_root() / "x.log"
    p.write_bytes(b"a" * size)
    return p


def test_default_cap_is_one_mebibyte():
    assert retention.LOG_CAP_BYTES == 1048576


def test_under_cap_is_untouched(tmp_path):
    p = _log(tmp_path, 99)
    assert retention.rotate_log(p, cap=100) is False
    assert p.stat().st_size == 99 and not p.with_name("x.log.1").exists()


def test_exactly_at_cap_rotates(tmp_path):
    p = _log(tmp_path, 100)
    assert retention.rotate_log(p, cap=100) is True
    assert not p.exists() and p.with_name("x.log.1").stat().st_size == 100


def test_over_cap_rotates_and_replaces_the_previous_generation(tmp_path):
    p = _log(tmp_path, 150)
    p.with_name("x.log.1").write_text("old")
    assert retention.rotate_log(p, cap=100) is True
    assert p.with_name("x.log.1").stat().st_size == 150
    assert not p.with_name("x.log.2").exists()


def test_missing_file_and_symlink_are_a_noop(tmp_path):
    missing = paths.state_root() / "nope.log"
    assert retention.rotate_log(missing, cap=1) is False
    target = _log(tmp_path, 500)
    link = paths.state_root() / "link.log"
    link.symlink_to(target)
    assert retention.rotate_log(link, cap=1) is False
    assert target.exists()


def test_oserror_is_swallowed(tmp_path, monkeypatch):
    p = _log(tmp_path, 500)

    def boom(*_a, **_k):
        raise PermissionError("denied")

    monkeypatch.setattr(retention.os, "replace", boom)
    assert retention.rotate_log(p, cap=1) is False
    assert p.exists()


def test_read_generations_is_oldest_first_across_the_rotation(tmp_path):
    p = paths.state_root() / "h.log"
    p.with_name("h.log.1").write_text("1\n2\n")
    p.write_text("3\n")
    assert list(retention.read_generations(p)) == ["1\n", "2\n", "3\n"]


def test_read_generations_tolerates_either_generation_missing(tmp_path):
    p = paths.state_root() / "h.log"
    assert list(retention.read_generations(p)) == []
    p.write_text("only\n")
    assert list(retention.read_generations(p)) == ["only\n"]
    p.unlink()
    p.with_name("h.log.1").write_text("rotated\n")
    assert list(retention.read_generations(p)) == ["rotated\n"]
