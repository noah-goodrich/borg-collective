"""Unit tests for borg_core.paths — the one definition of BORG_DIR / BORG_REGISTRY resolution.

borg_core/registry/test_shell.py and borg_core/recon/test_shell.py keep their own cases against
`shell.borg_dir()` / `shell.registry_path()`; those now pin that each package's re-export is wired
up. These pin the behavior itself.
"""

from pathlib import Path

import pytest

from borg_core import paths


@pytest.fixture()
def clean_env(monkeypatch):
    monkeypatch.delenv("BORG_DIR", raising=False)
    monkeypatch.delenv("BORG_REGISTRY", raising=False)
    monkeypatch.delenv("XDG_CONFIG_HOME", raising=False)


def test_borg_dir_prefers_explicit_env(clean_env, monkeypatch):
    monkeypatch.setenv("BORG_DIR", "/sentinel/borg")
    assert paths.borg_dir() == Path("/sentinel/borg")


def test_borg_dir_falls_back_to_xdg_config_home(clean_env, monkeypatch):
    monkeypatch.setenv("XDG_CONFIG_HOME", "/sentinel/xdg")
    assert paths.borg_dir() == Path("/sentinel/xdg/borg")


def test_borg_dir_falls_back_to_home_when_nothing_is_set(clean_env, monkeypatch):
    monkeypatch.setattr(Path, "home", classmethod(lambda cls: Path("/sentinel/home")))
    assert paths.borg_dir() == Path("/sentinel/home/.config/borg")


def test_borg_dir_treats_an_empty_env_var_as_unset(clean_env, monkeypatch):
    # `BORG_DIR=""` reaches a child as an empty string, not as absent. Falling through to XDG is
    # what zsh's `${BORG_DIR:-...}` would do; returning Path("") would resolve to the cwd.
    monkeypatch.setenv("BORG_DIR", "")
    monkeypatch.setenv("XDG_CONFIG_HOME", "/sentinel/xdg")
    assert paths.borg_dir() == Path("/sentinel/xdg/borg")


def test_registry_path_prefers_explicit_env(clean_env, monkeypatch):
    monkeypatch.setenv("BORG_REGISTRY", "/sentinel/registry.json")
    assert paths.registry_path() == Path("/sentinel/registry.json")


def test_registry_path_derives_from_borg_dir_when_unset(clean_env, monkeypatch):
    # The condition every real `borg` invocation runs under: borg.zsh assigns BORG_REGISTRY without
    # `export`, so the python3 child must derive it rather than require it.
    monkeypatch.setenv("BORG_DIR", "/sentinel/borg")
    assert paths.registry_path() == Path("/sentinel/borg/registry.json")


def test_registry_path_treats_an_empty_env_var_as_unset(clean_env, monkeypatch):
    monkeypatch.setenv("BORG_REGISTRY", "")
    monkeypatch.setenv("BORG_DIR", "/sentinel/borg")
    assert paths.registry_path() == Path("/sentinel/borg/registry.json")


@pytest.fixture()
def state_env(monkeypatch, tmp_path):
    """Sandboxed HOME with XDG_STATE_HOME UNSET: the default must be derived, never pre-supplied."""
    monkeypatch.delenv("XDG_STATE_HOME", raising=False)
    monkeypatch.setenv("HOME", str(tmp_path))
    return tmp_path


def test_state_root_derives_default_from_home(state_env):
    assert paths.state_root() == state_env / ".local" / "state" / "borg"


def test_state_root_honours_xdg_state_home(state_env, monkeypatch):
    monkeypatch.setenv("XDG_STATE_HOME", str(state_env / "xdg"))
    assert paths.state_root() == state_env / "xdg" / "borg"


def test_state_root_treats_blank_xdg_state_home_as_unset(state_env, monkeypatch):
    monkeypatch.setenv("XDG_STATE_HOME", "")
    assert paths.state_root() == state_env / ".local" / "state" / "borg"


# ── operational_file: the reader-side dual lookup (expand phase) ─────────────────────────────────


@pytest.fixture()
def dual_env(monkeypatch, tmp_path):
    monkeypatch.setenv("HOME", str(tmp_path / "home"))
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path / "config"))
    monkeypatch.setenv("XDG_STATE_HOME", str(tmp_path / "state"))
    monkeypatch.delenv("BORG_DIR", raising=False)
    return tmp_path


def test_operational_file_reads_old_location_when_only_it_exists(dual_env):
    old = dual_env / "config" / "borg" / "agents.jsonl"
    old.parent.mkdir(parents=True)
    old.write_text("old")
    assert paths.operational_file("agents.jsonl") == old


def test_operational_file_prefers_state_root_when_both_exist(dual_env):
    old = dual_env / "config" / "borg" / "agents.jsonl"
    new = dual_env / "state" / "borg" / "agents.jsonl"
    for f in (old, new):
        f.parent.mkdir(parents=True)
        f.write_text("x")
    assert paths.operational_file("agents.jsonl") == new


def test_operational_file_names_the_old_path_when_neither_exists(dual_env):
    assert paths.operational_file("recon/last-run") == dual_env / "config" / "borg" / "recon" / "last-run"
