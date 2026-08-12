"""Tests for borg_core.registry.cli — the dispatch layer (add/rm argument handling, exit codes).

Mirrors the parity contract pinned in tests/cli_contract.bats, including the KNOWN BUG where
`borg add` exits 1 when no Claude session is found for the newly-registered project.
"""

import os
from pathlib import Path

import pytest

from borg_core.registry import cli, shell


@pytest.fixture()
def isolated_env(tmp_path, monkeypatch):
    monkeypatch.setenv("BORG_DIR", str(tmp_path / "borg-dir"))
    monkeypatch.delenv("XDG_CONFIG_HOME", raising=False)
    monkeypatch.delenv("BORG_REGISTRY", raising=False)
    monkeypatch.delenv("BORG_TMUX_SESSION", raising=False)
    monkeypatch.setattr(Path, "home", lambda: tmp_path)
    monkeypatch.setenv("PATH", "/nonexistent-bin-dir")  # no real tmux on PATH
    return tmp_path


# ── cmd_add ────────────────────────────────────────────────────────────────────


def test_cmd_add_registers_new_project_keyed_by_basename(isolated_env, capsys):
    proj_dir = isolated_env / "sample-project"
    proj_dir.mkdir()

    exit_code = cli.cmd_add(str(proj_dir))

    out = capsys.readouterr().out
    assert "Registered: sample-project" in out
    registry = shell.read_registry()
    assert registry["projects"]["sample-project"]["path"] == str(proj_dir)
    assert registry["projects"]["sample-project"]["source"] == "cli"
    # KNOWN BUG (parity, not a regression): exits 1 when no Claude session is found.
    assert exit_code == 1


def test_cmd_add_with_no_path_registers_current_directory(isolated_env, capsys, monkeypatch):
    proj_dir = isolated_env / "cwd-project"
    proj_dir.mkdir()
    monkeypatch.chdir(proj_dir)

    exit_code = cli.cmd_add(None)

    out = capsys.readouterr().out
    assert "Registered: cwd-project" in out
    assert exit_code == 1


def test_cmd_add_with_discoverable_session_exits_0_and_prints_latest_session(isolated_env, capsys):
    proj_dir = isolated_env / "has-session"
    proj_dir.mkdir()
    session_dir = shell.claude_project_dir(str(proj_dir))
    session_dir.mkdir(parents=True)
    (session_dir / "abc-123.jsonl").write_text("{}")

    exit_code = cli.cmd_add(str(proj_dir))

    out = capsys.readouterr().out
    assert "Registered: has-session" in out
    assert "Latest session: abc-123" in out
    assert exit_code == 0
    registry = shell.read_registry()
    assert registry["projects"]["has-session"]["claude_session_id"] == "abc-123"
    assert registry["projects"]["has-session"]["last_activity"] is not None


def test_cmd_add_upserts_preserving_unrelated_existing_fields(isolated_env, capsys):
    proj_dir = isolated_env / "existing-project"
    proj_dir.mkdir()
    shell.write_registry({"projects": {"existing-project": {"path": "/old", "pinned": True}}})

    cli.cmd_add(str(proj_dir))
    capsys.readouterr()

    registry = shell.read_registry()
    assert registry["projects"]["existing-project"]["pinned"] is True
    assert registry["projects"]["existing-project"]["path"] == str(proj_dir)


# ── cmd_rm ─────────────────────────────────────────────────────────────────────


def test_cmd_rm_removes_existing_project(isolated_env, capsys):
    shell.write_registry({"projects": {"keep-me": {"path": "/tmp/keep"}, "drop-me": {"path": "/tmp/drop"}}})

    exit_code = cli.cmd_rm("drop-me")

    out = capsys.readouterr().out
    assert "Removed: drop-me" in out
    assert exit_code == 0
    registry = shell.read_registry()
    assert "drop-me" not in registry["projects"]
    assert "keep-me" in registry["projects"]


def test_cmd_rm_with_no_project_argument_dies_with_usage(isolated_env):
    shell.write_registry({"projects": {"keep-me": {"path": "/tmp/keep"}}})

    with pytest.raises(SystemExit) as exc_info:
        cli.cmd_rm(None)

    assert exc_info.value.code == 1
    registry = shell.read_registry()
    assert "keep-me" in registry["projects"]


def test_cmd_rm_usage_message_matches_contract(isolated_env, capsys):
    with pytest.raises(SystemExit):
        cli.cmd_rm(None)
    err = capsys.readouterr().err
    assert "usage: borg rm" in err


def test_cmd_rm_of_unregistered_project_dies_cleanly(isolated_env, capsys):
    shell.write_registry({"projects": {"keep-me": {"path": "/tmp/keep"}}})

    with pytest.raises(SystemExit) as exc_info:
        cli.cmd_rm("ghost-project")

    assert exc_info.value.code == 1
    err = capsys.readouterr().err
    assert "not in registry" in err
    registry = shell.read_registry()
    assert "keep-me" in registry["projects"]


# ── main() dispatch ──────────────────────────────────────────────────────────


def test_main_dispatches_add(isolated_env, capsys):
    proj_dir = isolated_env / "via-main"
    proj_dir.mkdir()

    with pytest.raises(SystemExit) as exc_info:
        cli.main(["add", str(proj_dir)])

    assert exc_info.value.code == 1  # known-bug parity: no session found
    out = capsys.readouterr().out
    assert "Registered: via-main" in out


def test_main_dispatches_rm(isolated_env, capsys):
    shell.write_registry({"projects": {"gone": {"path": "/tmp/gone"}}})

    with pytest.raises(SystemExit) as exc_info:
        cli.main(["rm", "gone"])

    assert exc_info.value.code == 0
    out = capsys.readouterr().out
    assert "Removed: gone" in out


def test_main_requires_a_subcommand(isolated_env):
    with pytest.raises(SystemExit):
        cli.main([])


def test_main_rejects_unknown_command(isolated_env, capsys):
    with pytest.raises(SystemExit) as exc_info:
        cli.main(["frobnicate", "x"])
    assert exc_info.value.code == 1
    err = capsys.readouterr().err
    assert "unknown registry command" in err


def test_main_ignores_extra_positional_arguments_like_zsh_did(isolated_env, capsys):
    # zsh's cmd_add/cmd_rm only ever read $1; a stray trailing token was always silently dropped,
    # not rejected. argparse's default nargs="?" would instead hard-fail on this -- this pins the
    # fix (direct argv indexing) that restores the original permissive behavior.
    proj_dir = isolated_env / "extra-args-ok"
    proj_dir.mkdir()

    with pytest.raises(SystemExit) as exc_info:
        cli.main(["add", str(proj_dir), "some", "extra", "tokens"])

    assert exc_info.value.code == 1  # known-bug parity path, not an argparse usage error
    out = capsys.readouterr().out
    assert "Registered: extra-args-ok" in out
    registry = shell.read_registry()
    assert "extra-args-ok" in registry["projects"]


def test_main_treats_dash_prefixed_value_as_literal_data_not_a_flag(isolated_env, capsys, monkeypatch):
    # zsh's cmd_rm has no flag parsing -- "--help" is just a project name to look up, and the
    # lookup fails normally. argparse would instead intercept --help and print usage text with
    # exit 0; this pins the fix.
    monkeypatch.chdir(isolated_env)

    with pytest.raises(SystemExit) as exc_info:
        cli.main(["rm", "--help"])

    assert exc_info.value.code == 1
    err = capsys.readouterr().err
    assert "project '--help' not in registry" in err


def test_main_wraps_malformed_registry_in_a_clean_die_not_a_traceback(isolated_env, capsys):
    shell.registry_path().parent.mkdir(parents=True, exist_ok=True)
    shell.registry_path().write_text("{not valid json")

    with pytest.raises(SystemExit) as exc_info:
        cli.main(["rm", "anything"])

    assert exc_info.value.code == 1
    err = capsys.readouterr().err
    assert "not valid JSON" in err


def test_basename_helper_mirrors_zsh_pattern_removal():
    assert cli._basename("/Users/noah/dev/troth") == "troth"
    assert cli._basename("troth") == "troth"
    assert cli._basename("/Users/noah/dev/troth/") == ""


def test_env_path_isolation_marker(isolated_env):
    # Sanity check the fixture itself isolates PATH so tmux lookups can't touch a real session.
    assert os.environ["PATH"] == "/nonexistent-bin-dir"
