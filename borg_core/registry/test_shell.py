"""Unit tests for borg_core.registry.shell (I/O layer)."""

import json
import os
import time
from pathlib import Path

import pytest

from borg_core.registry import shell


@pytest.fixture()
def isolated_env(tmp_path, monkeypatch):
    borg_dir = tmp_path / "borg-dir"
    monkeypatch.setenv("BORG_DIR", str(borg_dir))
    monkeypatch.delenv("XDG_CONFIG_HOME", raising=False)
    monkeypatch.delenv("BORG_REGISTRY", raising=False)
    monkeypatch.delenv("BORG_TMUX_SESSION", raising=False)
    return tmp_path


# ── config resolution ────────────────────────────────────────────────────────


def test_borg_dir_uses_explicit_env(isolated_env):
    assert shell.borg_dir() == isolated_env / "borg-dir"


def test_borg_dir_falls_back_to_xdg(tmp_path, monkeypatch):
    monkeypatch.delenv("BORG_DIR", raising=False)
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path / "xdg"))
    assert shell.borg_dir() == tmp_path / "xdg" / "borg"


def test_registry_path_default_is_under_borg_dir(isolated_env):
    assert shell.registry_path() == isolated_env / "borg-dir" / "registry.json"


def test_registry_path_uses_explicit_override(isolated_env, monkeypatch):
    monkeypatch.setenv("BORG_REGISTRY", "/sentinel/registry.json")
    assert shell.registry_path() == Path("/sentinel/registry.json")


def test_tmux_session_name_default(isolated_env):
    assert shell.tmux_session_name() == "borg"


def test_tmux_session_name_uses_override(isolated_env, monkeypatch):
    monkeypatch.setenv("BORG_TMUX_SESSION", "custom")
    assert shell.tmux_session_name() == "custom"


# ── registry read/write/has/merge/remove ──────────────────────────────────────


def test_read_registry_initializes_when_missing(isolated_env):
    registry = shell.read_registry()
    assert registry == {"projects": {}}
    assert shell.registry_path().is_file()


def test_read_registry_returns_existing_content(isolated_env):
    shell.registry_path().parent.mkdir(parents=True, exist_ok=True)
    shell.registry_path().write_text(json.dumps({"projects": {"a": {"path": "/a"}}}))
    assert shell.read_registry() == {"projects": {"a": {"path": "/a"}}}


def test_read_registry_raises_clear_error_on_malformed_json(isolated_env):
    shell.registry_path().parent.mkdir(parents=True, exist_ok=True)
    shell.registry_path().write_text("{not valid json")
    with pytest.raises(ValueError, match="not valid JSON"):
        shell.read_registry()


def test_write_registry_is_atomic_no_leftover_tmp_file(isolated_env):
    shell.write_registry({"projects": {"x": {"path": "/x"}}})
    files = list(shell.registry_path().parent.iterdir())
    assert files == [shell.registry_path()]


def test_write_registry_accepts_an_empty_projects_object(isolated_env):
    shell.write_registry({"projects": {}})
    assert shell.read_registry() == {"projects": {}}


def test_registry_has_true_for_existing_project(isolated_env):
    shell.write_registry({"projects": {"troth": {"path": "/troth"}}})
    assert shell.registry_has("troth") is True


def test_registry_has_false_for_missing_project(isolated_env):
    shell.write_registry({"projects": {}})
    assert shell.registry_has("ghost") is False


def test_registry_merge_inserts_new_project(isolated_env):
    shell.registry_merge("new-project", {"path": "/new"})
    assert shell.read_registry()["projects"]["new-project"] == {"path": "/new"}


def test_registry_merge_upserts_existing_project_preserving_other_fields(isolated_env):
    shell.write_registry({"projects": {"p": {"path": "/old", "pinned": True}}})
    shell.registry_merge("p", {"path": "/new"})
    assert shell.read_registry()["projects"]["p"] == {"path": "/new", "pinned": True}


def test_registry_remove_deletes_project(isolated_env):
    shell.write_registry({"projects": {"keep": {"path": "/k"}, "drop": {"path": "/d"}}})
    shell.registry_remove("drop")
    projects = shell.read_registry()["projects"]
    assert "drop" not in projects
    assert "keep" in projects


def test_registry_remove_missing_project_is_a_no_op(isolated_env):
    shell.write_registry({"projects": {"keep": {"path": "/k"}}})
    shell.registry_remove("ghost")
    assert shell.read_registry() == {"projects": {"keep": {"path": "/k"}}}


# ── resolve_path ─────────────────────────────────────────────────────────────


def test_resolve_path_existing_path_is_canonicalized(tmp_path):
    real_dir = tmp_path / "real"
    real_dir.mkdir()
    link = tmp_path / "link"
    link.symlink_to(real_dir)
    assert shell.resolve_path(str(link)) == str(real_dir)


def test_resolve_path_nonexistent_path_falls_back_to_raw_input():
    raw = "/definitely/does/not/exist/anywhere"
    assert shell.resolve_path(raw) == raw


# ── claude session lookups ────────────────────────────────────────────────────


def test_claude_encode_path_replaces_slashes():
    assert shell.claude_encode_path("/Users/noah/dev/troth") == "-Users-noah-dev-troth"


def test_claude_encode_path_strips_trailing_slash():
    assert shell.claude_encode_path("/Users/noah/dev/troth/") == "-Users-noah-dev-troth"


def test_claude_encode_path_strips_only_one_trailing_slash():
    # Mirrors zsh's ${1%/} (single suffix removal), not a full rstrip -- a doubled trailing slash
    # leaves one behind as an embedded dash.
    assert shell.claude_encode_path("/a/b//") == "-a-b-"


def test_claude_project_dir_is_under_home_claude_projects(monkeypatch, tmp_path):
    monkeypatch.setattr(Path, "home", lambda: tmp_path)
    assert shell.claude_project_dir("/a/b") == tmp_path / ".claude" / "projects" / "-a-b"


def test_claude_latest_session_id_returns_none_when_dir_missing(monkeypatch, tmp_path):
    monkeypatch.setattr(Path, "home", lambda: tmp_path)
    assert shell.claude_latest_session_id("/no/such/project") is None


def test_claude_latest_session_id_returns_none_when_no_jsonl_files(monkeypatch, tmp_path):
    monkeypatch.setattr(Path, "home", lambda: tmp_path)
    project_dir = shell.claude_project_dir("/a/b")
    project_dir.mkdir(parents=True)
    assert shell.claude_latest_session_id("/a/b") is None


def test_claude_latest_session_id_picks_newest_by_mtime(monkeypatch, tmp_path):
    monkeypatch.setattr(Path, "home", lambda: tmp_path)
    project_dir = shell.claude_project_dir("/a/b")
    project_dir.mkdir(parents=True)
    older = project_dir / "older-session.jsonl"
    newer = project_dir / "newer-session.jsonl"
    older.write_text("{}")
    time.sleep(0.01)
    newer.write_text("{}")
    assert shell.claude_latest_session_id("/a/b") == "newer-session"


def test_claude_session_jsonl_builds_expected_path(monkeypatch, tmp_path):
    monkeypatch.setattr(Path, "home", lambda: tmp_path)
    result = shell.claude_session_jsonl("/a/b", "sess-1")
    assert result == tmp_path / ".claude" / "projects" / "-a-b" / "sess-1.jsonl"


def test_mtime_or_epoch_returns_zero_for_a_file_that_no_longer_exists(tmp_path):
    # Guards the TOCTOU window in claude_latest_session_id's max(): a candidate that vanishes
    # between the glob and the stat (e.g. a concurrent transcript rotation) must not crash the
    # whole lookup.
    ghost = tmp_path / "ghost.jsonl"
    assert shell._mtime_or_epoch(ghost) == 0.0


def test_mtime_or_epoch_returns_real_mtime_for_existing_file(tmp_path):
    f = tmp_path / "f"
    f.write_text("x")
    assert shell._mtime_or_epoch(f) == f.stat().st_mtime


# ── file_mtime_iso ───────────────────────────────────────────────────────────


def test_file_mtime_iso_missing_file_returns_none(tmp_path):
    assert shell.file_mtime_iso(tmp_path / "nope") is None


def test_file_mtime_iso_existing_file_returns_iso_shaped_string(tmp_path):
    f = tmp_path / "f"
    f.write_text("x")
    result = shell.file_mtime_iso(f)
    assert result is not None
    assert result.endswith("Z")
    assert "T" in result


def test_file_mtime_iso_uses_local_time_not_utc(tmp_path, monkeypatch):
    # KNOWN BUG, preserved for parity (see the module docstring): BSD `stat -f %Sm -t
    # "...Z"` formats in local time and appends a literal 'Z' -- it never actually converts to
    # UTC. Pin a non-UTC zone so this test fails if a future change "fixes" this into genuine UTC,
    # which would silently break the reaper's matching mis-parse (see shell.py's docstring).
    monkeypatch.setenv("TZ", "America/Denver")
    time.tzset()
    try:
        f = tmp_path / "f"
        f.write_text("x")
        mtime = f.stat().st_mtime
        expected = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.localtime(mtime))
        result = shell.file_mtime_iso(f)
        assert result == expected
        # Sanity: prove this ISN'T UTC by comparing against a genuine UTC conversion, which must
        # differ (Denver is never UTC+0).
        utc_equivalent = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(mtime))
        assert result != utc_equivalent
    finally:
        monkeypatch.delenv("TZ", raising=False)
        time.tzset()


# ── tmux_window_exists ────────────────────────────────────────────────────────


def _mock_tmux(monkeypatch, tmp_path, script: str):
    mock_bin = tmp_path / "mock-bin"
    mock_bin.mkdir(exist_ok=True)
    tmux_script = mock_bin / "tmux"
    tmux_script.write_text(f"#!/usr/bin/env bash\n{script}\n")
    tmux_script.chmod(0o755)
    monkeypatch.setenv("PATH", f"{mock_bin}{os.pathsep}{os.environ['PATH']}")


def test_tmux_window_exists_true_when_name_in_window_list(monkeypatch, tmp_path, isolated_env):
    _mock_tmux(monkeypatch, tmp_path, 'echo "orchestrator"\necho "troth"\nexit 0')
    assert shell.tmux_window_exists("troth") is True


def test_tmux_window_exists_false_when_name_absent(monkeypatch, tmp_path, isolated_env):
    _mock_tmux(monkeypatch, tmp_path, 'echo "orchestrator"\nexit 0')
    assert shell.tmux_window_exists("troth") is False


def test_tmux_window_exists_false_when_session_not_alive(monkeypatch, tmp_path, isolated_env):
    _mock_tmux(monkeypatch, tmp_path, "exit 1")
    assert shell.tmux_window_exists("troth") is False


def test_tmux_window_exists_false_when_tmux_binary_missing(monkeypatch, isolated_env):
    monkeypatch.setenv("PATH", "/nonexistent-bin-dir")
    assert shell.tmux_window_exists("troth") is False


def test_tmux_window_exists_matches_exact_name_not_substring(monkeypatch, tmp_path, isolated_env):
    _mock_tmux(monkeypatch, tmp_path, 'echo "troth-old"\nexit 0')
    assert shell.tmux_window_exists("troth") is False
