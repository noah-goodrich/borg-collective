"""Tests for borg_core.registry.cli — the dispatch layer (add/rm argument handling, exit codes).

Mirrors the parity contract pinned in tests/cli_contract.bats, including the KNOWN BUG where
`borg add` exits 1 when no Claude session is found for the newly-registered project.
"""

import os
import subprocess
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


def test_cmd_add_keeps_an_existing_short_tmux_window(isolated_env, capsys):
    proj_dir = isolated_env / "widget-factory"
    proj_dir.mkdir()
    shell.write_registry({"projects": {"widget-factory": {"path": "/old", "tmux_window": "wf"}}})

    cli.cmd_add(str(proj_dir))
    capsys.readouterr()

    entry = shell.read_registry()["projects"]["widget-factory"]
    assert entry["tmux_window"] == "wf"
    assert entry["path"] == str(proj_dir)


def test_cmd_add_keeps_the_short_name_even_when_a_long_named_window_is_live(isolated_env, monkeypatch, capsys):
    proj_dir = isolated_env / "widget-factory"
    proj_dir.mkdir()
    shell.write_registry({"projects": {"widget-factory": {"tmux_window": "wf"}}})
    monkeypatch.setattr(shell, "tmux_window_exists", lambda name: name == "widget-factory")

    cli.cmd_add(str(proj_dir))
    capsys.readouterr()

    assert shell.read_registry()["projects"]["widget-factory"]["tmux_window"] == "wf"


def test_cmd_add_fresh_and_null_entries_still_take_the_computed_window(isolated_env, monkeypatch, capsys):
    monkeypatch.setattr(shell, "tmux_window_exists", lambda name: True)
    for name, seed in (("fresh-one", None), ("null-one", {"tmux_window": None})):
        proj_dir = isolated_env / name
        proj_dir.mkdir()
        if seed is not None:
            shell.write_registry({"projects": {name: seed}})
        cli.cmd_add(str(proj_dir))
        capsys.readouterr()
        assert shell.read_registry()["projects"][name]["tmux_window"] == name


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


# ── cmd_backfill_repo ────────────────────────────────────────────────────────
#
# `isolated_env` sets PATH to a nonexistent directory so no real tmux is reachable, which also hides
# `git`. That is right for the `add` tests above -- they assert registration, not identity -- and it
# is why these use their own fixture: backfill's whole job is to resolve a real common dir, and a
# suite that hid `git` from it would pass while proving nothing, the same shape as the reaper default
# that stayed green for three months by never running in production's configuration.


@pytest.fixture()
def git_env(tmp_path, monkeypatch):
    monkeypatch.setenv("BORG_DIR", str(tmp_path / "borg-dir"))
    monkeypatch.delenv("XDG_CONFIG_HOME", raising=False)
    monkeypatch.delenv("BORG_REGISTRY", raising=False)
    return tmp_path


def _repository(root, name):
    directory = root / name
    directory.mkdir(parents=True, exist_ok=True)
    subprocess.run(["git", "init", "-q"], cwd=str(directory), check=True, capture_output=True)
    subprocess.run(
        ["git", "commit", "-q", "--allow-empty", "-m", "root"],
        cwd=str(directory),
        check=True,
        capture_output=True,
    )
    return str(directory)


def _worktree(repository, path, branch):
    subprocess.run(
        ["git", "worktree", "add", "-q", "-b", branch, str(path)],
        cwd=repository,
        check=True,
        capture_output=True,
    )
    return str(path)


def _register(name, path, **extra):
    entry = {"path": path, "source": "cli", "summary": None}
    entry.update(extra)
    shell.registry_merge(name, entry)


def test_backfill_repo_groups_a_worktree_with_its_parent(git_env, capsys):
    repository = _repository(git_env, "sp")
    worktree = _worktree(repository, git_env / "sp-olf", "feat/olf")
    _register("sp", repository)
    _register("sp-olf", worktree)

    assert cli.cmd_backfill_repo() == 0

    projects = shell.read_registry()["projects"]
    assert projects["sp"]["repo"] == projects["sp-olf"]["repo"]
    assert projects["sp"]["repo"] is not None
    assert "filled 2" in capsys.readouterr().out


def test_backfill_repo_is_idempotent_and_never_overwrites_a_set_value(git_env, capsys):
    repository = _repository(git_env, "sp")
    _register("sp", repository)
    _register("pinned", repository, repo="/hand/corrected/.git")

    cli.cmd_backfill_repo()
    first = shell.read_registry()["projects"]

    cli.cmd_backfill_repo()
    second = shell.read_registry()["projects"]

    assert first == second
    assert second["pinned"]["repo"] == "/hand/corrected/.git"
    assert "already set" in capsys.readouterr().out


def test_backfill_repo_skips_an_entry_outside_any_git_repository(git_env, capsys):
    plain = git_env / "not-a-repo"
    plain.mkdir()
    _register("plain", str(plain))

    assert cli.cmd_backfill_repo() == 0

    out = capsys.readouterr().out
    assert "skip   plain" in out
    assert "skipped 1" in out
    # Null is not written over null: a no-op must not read as work.
    assert "repo" not in shell.read_registry()["projects"]["plain"]


def test_backfill_repo_dry_run_reports_without_writing(git_env, capsys):
    repository = _repository(git_env, "sp")
    _register("sp", repository)

    assert cli.cmd_backfill_repo("--dry-run") == 0

    out = capsys.readouterr().out
    assert "would fill 1" in out
    assert "repo" not in shell.read_registry()["projects"]["sp"]

    cli.cmd_backfill_repo()
    assert shell.read_registry()["projects"]["sp"]["repo"] is not None


def test_backfill_repo_rejects_an_unknown_option(git_env):
    with pytest.raises(SystemExit):
        cli.cmd_backfill_repo("--force")


def test_main_dispatches_backfill_repo(git_env):
    repository = _repository(git_env, "sp")
    _register("sp", repository)
    with pytest.raises(SystemExit) as exc:
        cli.main(["backfill-repo"])
    assert exc.value.code == 0
    assert shell.read_registry()["projects"]["sp"]["repo"] is not None


def test_main_rejects_an_unknown_registry_command(git_env, capsys):
    with pytest.raises(SystemExit):
        cli.main(["frobnicate"])
    assert "add, rm, backfill-repo or window-name" in capsys.readouterr().err


def test_cmd_add_records_the_repo_for_a_real_repository(git_env):
    # cmd_add's own expand-phase contract, exercised with a real `git` on PATH.
    repository = _repository(git_env, "sp")
    cli.cmd_add(repository)
    assert shell.read_registry()["projects"]["sp"]["repo"] is not None


def test_cmd_add_records_a_null_repo_outside_a_repository(git_env):
    plain = git_env / "loose"
    plain.mkdir()
    cli.cmd_add(str(plain))
    entry = shell.read_registry()["projects"]["loose"]
    assert entry["repo"] is None
    assert "repo" in entry


# ── window-name ────────────────────────────────────────────────────────────────


def _seed(projects: dict) -> None:
    shell.write_registry({"projects": projects})


def _window(project: str) -> str | None:
    window: str | None = shell.read_registry()["projects"][project].get("tmux_window")
    return window


def test_window_name_prints_stored_value_else_project_name(isolated_env, capsys):
    _seed({"alpha-beta-gamma": {"tmux_window": "abg"}, "widget": {}})
    assert cli.cmd_window_name(["alpha-beta-gamma"]) == 0
    assert cli.cmd_window_name(["widget"]) == 0
    assert capsys.readouterr().out.split() == ["abg", "widget"]


def test_window_name_set_writes_and_prints(isolated_env, capsys):
    _seed({"widget-factory": {"path": "/p"}})
    assert cli.cmd_window_name(["widget-factory", "--set", "wf"]) == 0
    assert capsys.readouterr().out.strip() == "wf"
    entry = shell.read_registry()["projects"]["widget-factory"]
    assert entry["tmux_window"] == "wf" and entry["path"] == "/p"


@pytest.mark.parametrize("bad, needle", [("a.b", "'.' or ':'"), ("", "empty"), ("taken", "name of project")])
def test_window_name_set_rejects_with_reason_and_writes_nothing(isolated_env, capsys, bad, needle):
    _seed({"me": {}, "taken": {}})
    with pytest.raises(SystemExit) as exc:
        cli.cmd_window_name(["me", "--set", bad])
    assert exc.value.code == 1
    assert needle in capsys.readouterr().err
    assert _window("me") is None


def test_window_name_set_rejects_session_name_from_environment(isolated_env, monkeypatch, capsys):
    _seed({"me": {}})
    monkeypatch.setenv("BORG_TMUX_SESSION", "work")
    with pytest.raises(SystemExit):
        cli.cmd_window_name(["me", "--set", "work"])
    assert "session name" in capsys.readouterr().err
    assert cli.cmd_window_name(["me", "--set", "borg"]) == 0
    assert _window("me") == "borg"


def test_window_name_derive_writes_for_legacy_and_default_session_is_borg(isolated_env, capsys):
    _seed({"borg-collective": {"tmux_window": "borg-collective"}})
    assert cli.cmd_window_name(["borg-collective", "--derive"]) == 0
    assert capsys.readouterr().out.strip() == "borg-c"
    assert _window("borg-collective") == "borg-c"


def test_window_name_derive_leaves_explicit_choice_alone(isolated_env, capsys):
    _seed({"alpha-beta-gamma": {"tmux_window": "custom"}})
    assert cli.cmd_window_name(["alpha-beta-gamma", "--derive"]) == 0
    assert capsys.readouterr().out.strip() == "custom"
    assert _window("alpha-beta-gamma") == "custom"


def test_window_name_unknown_project_and_bad_args(isolated_env, capsys):
    _seed({"me": {}})
    for argv in (["ghost"], [], ["me", "--bogus"], ["me", "--set"]):
        with pytest.raises(SystemExit) as exc:
            cli.cmd_window_name(argv)
        assert exc.value.code == 1


def test_main_dispatches_window_name(isolated_env, capsys):
    _seed({"me": {}})
    with pytest.raises(SystemExit) as exc:
        cli.main(["window-name", "me", "--set", "m"])
    assert exc.value.code == 0
    assert _window("me") == "m"
