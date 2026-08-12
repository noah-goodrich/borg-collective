"""Unit tests for borg_core.recon.shell (I/O layer)."""

import json
import os
import stat
import time
from pathlib import Path

import pytest

from borg_core.recon import shell


@pytest.fixture()
def isolated_env(tmp_path, monkeypatch):
    borg_dir = tmp_path / "borg-dir"
    monkeypatch.setenv("BORG_DIR", str(borg_dir))
    monkeypatch.delenv("XDG_CONFIG_HOME", raising=False)
    monkeypatch.delenv("BORG_RECON_ADAPTER_PATH", raising=False)
    monkeypatch.delenv("BORG_RECON_LIB_DIR", raising=False)
    return tmp_path


def _make_executable(path, content="#!/usr/bin/env bash\necho hi\n"):
    path.write_text(content)
    path.chmod(path.stat().st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)


# ── config resolution ────────────────────────────────────────────────────────


def test_borg_dir_uses_explicit_env(isolated_env):
    assert shell.borg_dir() == isolated_env / "borg-dir"


def test_borg_dir_falls_back_to_xdg(tmp_path, monkeypatch):
    monkeypatch.delenv("BORG_DIR", raising=False)
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path / "xdg"))
    assert shell.borg_dir() == tmp_path / "xdg" / "borg"


def test_lib_dir_uses_override(isolated_env, monkeypatch):
    monkeypatch.setenv("BORG_RECON_LIB_DIR", "/sentinel/lib")
    assert shell.lib_dir() == Path("/sentinel/lib")


def test_adapter_search_path_uses_override(isolated_env, monkeypatch):
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", "/a:/b")
    assert shell.adapter_search_path() == "/a:/b"


def test_adapter_search_path_default_includes_borg_dir_and_lib_dir(isolated_env):
    result = shell.adapter_search_path()
    assert str(isolated_env / "borg-dir" / "recon" / "adapters") in result
    assert "lib/recon/adapters" in result


def test_max_tracks_default_and_override(isolated_env, monkeypatch):
    assert shell.max_tracks() == 8
    monkeypatch.setenv("BORG_RECON_MAX_TRACKS", "3")
    assert shell.max_tracks() == 3


def test_track_timeout_default_and_override(isolated_env, monkeypatch):
    assert shell.track_timeout() == 30
    monkeypatch.setenv("BORG_RECON_TRACK_TIMEOUT", "5")
    assert shell.track_timeout() == 5


# ── mtime / checkpoints ──────────────────────────────────────────────────────


def test_file_mtime_missing_file(tmp_path):
    assert shell.file_mtime(tmp_path / "nope") is None


def test_file_mtime_existing_file(tmp_path):
    f = tmp_path / "f"
    f.write_text("x")
    assert isinstance(shell.file_mtime(f), int)


def test_newest_checkpoint_epoch_picks_newest(tmp_path):
    proj = tmp_path / "proj"
    cdir = proj / ".borg" / "checkpoints"
    cdir.mkdir(parents=True)
    old = cdir / "old.md"
    new = cdir / "new.md"
    old.write_text("old")
    new.write_text("new")
    os.utime(old, (1000000000, 1000000000))
    os.utime(new, (2000000000, 2000000000))
    assert shell.newest_checkpoint_epoch([str(proj)]) == 2000000000


def test_newest_checkpoint_epoch_no_checkpoints(tmp_path):
    assert shell.newest_checkpoint_epoch([str(tmp_path / "no-such-project")]) is None


# ── last-run marker ──────────────────────────────────────────────────────────


def test_read_last_run_marker_absent(isolated_env):
    assert shell.read_last_run_marker() is None


def test_write_then_read_last_run_marker(isolated_env):
    shell.write_last_run_marker("2023-05-05T05:05:05Z")
    assert shell.read_last_run_marker() == "2023-05-05T05:05:05Z"


def test_read_last_run_marker_empty_file(isolated_env):
    marker_dir = isolated_env / "borg-dir" / "recon"
    marker_dir.mkdir(parents=True)
    (marker_dir / "last-run").write_text("")
    assert shell.read_last_run_marker() is None


# ── resolve_since (I/O + core precedence) ────────────────────────────────────


def test_resolve_since_explicit_short_circuits(isolated_env):
    assert shell.resolve_since("2025-01-02T03:04:05Z", []) == "2025-01-02T03:04:05Z"


def test_resolve_since_falls_back_to_marker(isolated_env):
    shell.write_last_run_marker("2023-05-05T05:05:05Z")
    result = shell.resolve_since("", [str(isolated_env / "no-such-project")])
    assert result == "2023-05-05T05:05:05Z"


def test_resolve_since_falls_back_to_24h(isolated_env):
    result = shell.resolve_since("", [str(isolated_env / "no-such-project")])
    assert result.endswith("Z")
    assert result.startswith("20")


# ── adapter discovery ────────────────────────────────────────────────────────


def test_discover_adapters_finds_executables(isolated_env, monkeypatch):
    adapters_dir = isolated_env / "adapters"
    adapters_dir.mkdir()
    _make_executable(adapters_dir / "recon-adapter-github")
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", str(adapters_dir))
    result = shell.discover_adapters()
    assert result[0][0] == "github"


def test_discover_adapters_ignores_non_executable(isolated_env, monkeypatch):
    adapters_dir = isolated_env / "adapters"
    adapters_dir.mkdir()
    (adapters_dir / "recon-adapter-noexec").write_text("{}")
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", str(adapters_dir))
    assert shell.discover_adapters() == []


def test_discover_adapters_dedups_first_dir_wins(isolated_env, monkeypatch):
    userdir = isolated_env / "userdir"
    repodir = isolated_env / "repodir"
    userdir.mkdir()
    repodir.mkdir()
    _make_executable(userdir / "recon-adapter-dup")
    _make_executable(repodir / "recon-adapter-dup")
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", f"{userdir}:{repodir}")
    result = shell.discover_adapters()
    assert len(result) == 1
    assert str(userdir) in result[0][1]


def test_discover_adapters_safe_with_missing_dir(isolated_env, monkeypatch):
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", str(isolated_env / "missing"))
    assert shell.discover_adapters() == []


# ── adapter execution ────────────────────────────────────────────────────────


def test_run_adapter_valid_output(isolated_env, tmp_path):
    script = tmp_path / "recon-adapter-demo"
    _make_executable(
        script,
        '#!/usr/bin/env bash\ncat <<\'JSON\'\n{"source":"demo","summary":"ok","items":[]}\nJSON\n',
    )
    result = shell.run_adapter("demo", str(script), "2025-01-01T00:00:00Z", "/dev/null")
    assert result["ok"] is True


def test_run_adapter_nonzero_exit_is_failed_track(isolated_env, tmp_path):
    script = tmp_path / "recon-adapter-broken"
    _make_executable(script, "#!/usr/bin/env bash\nexit 1\n")
    result = shell.run_adapter("broken", str(script), "2025-01-01T00:00:00Z", "/dev/null")
    assert result["ok"] is False


def test_run_adapter_missing_binary_is_failed_track(isolated_env, tmp_path):
    result = shell.run_adapter("nope", str(tmp_path / "does-not-exist"), "2025-01-01T00:00:00Z", "/dev/null")
    assert result["ok"] is False


def test_fanout_runs_all_adapters(isolated_env, tmp_path):
    script = tmp_path / "recon-adapter-demo"
    _make_executable(
        script,
        '#!/usr/bin/env bash\ncat <<\'JSON\'\n{"source":"demo","summary":"ok","items":[]}\nJSON\n',
    )
    results = shell.fanout("2025-01-01T00:00:00Z", "/dev/null", [("demo", str(script))])
    assert len(results) == 1
    assert results[0]["source"] == "demo"


def test_fanout_empty_adapter_list(isolated_env):
    assert shell.fanout("since", "/dev/null", []) == []


# ── checkpoint blockers ──────────────────────────────────────────────────────


def test_read_checkpoint_blockers_extracts_section(tmp_path):
    proj = tmp_path / "proj"
    cdir = proj / ".borg" / "checkpoints"
    cdir.mkdir(parents=True)
    (cdir / "2025-01-01-0900.md").write_text("# checkpoint\n## 4. Blockers\n- repo#7 waiting\n## 5. Next\nx\n")
    result = shell.read_checkpoint_blockers(str(proj))
    assert "repo#7 waiting" in result


def test_read_checkpoint_blockers_no_checkpoints_dir(tmp_path):
    assert shell.read_checkpoint_blockers(str(tmp_path / "no-project")) == ""


def test_read_checkpoint_blockers_picks_newest_by_name(tmp_path):
    proj = tmp_path / "proj"
    cdir = proj / ".borg" / "checkpoints"
    cdir.mkdir(parents=True)
    (cdir / "2025-01-01-0900.md").write_text("## 4. Blockers\nold\n")
    (cdir / "2025-02-01-0900.md").write_text("## 4. Blockers\nnew\n")
    result = shell.read_checkpoint_blockers(str(proj))
    assert "new" in result
    assert "old" not in result


# ── registry projects ────────────────────────────────────────────────────────


def test_load_registry_projects_no_filter(tmp_path):
    registry = tmp_path / "registry.json"
    registry.write_text(json.dumps({"projects": {"a": {"path": "/a"}, "b": {"path": "/b"}}}))
    result = shell.load_registry_projects(str(registry), None)
    assert set(result) == {"a", "b"}


def test_load_registry_projects_with_filter(tmp_path):
    registry = tmp_path / "registry.json"
    registry.write_text(json.dumps({"projects": {"a": {"path": "/a"}, "b": {"path": "/b"}}}))
    result = shell.load_registry_projects(str(registry), ["a"])
    assert set(result) == {"a"}


def test_write_projects_file_roundtrip(tmp_path):
    out = tmp_path / "projects.json"
    shell.write_projects_file({"a": {"path": "/a"}}, str(out))
    assert json.loads(out.read_text()) == {"a": {"path": "/a"}}


def test_time_import_used_for_fallback(isolated_env):
    # Sanity check that resolve_since's fallback window is derived from real wall-clock time,
    # not a fixed constant, without pinning an exact value.
    before = int(time.time())
    result = shell.resolve_since("", [str(isolated_env / "no-such-project")])
    assert result.startswith(str(time.gmtime(before).tm_year))
