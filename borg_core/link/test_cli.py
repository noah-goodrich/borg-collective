"""Tests for borg_core.link.cli -- the `--json` seam (Phase 2, A3).

Calling convention: in-process only (cli._run(...), cli.main([...])). Never subprocess, never
bats-from-pytest. Capture with capsys, assert exits with pytest.raises(SystemExit), parse JSON with
json.loads and index keys -- never string-compare the serialized form.
"""

import json
import os
import sys
from pathlib import Path

import pytest

from borg_core.link import cli, core, shell


@pytest.fixture()
def isolated_env(tmp_path, monkeypatch):
    borg_dir = tmp_path / "borg-dir"
    borg_dir.mkdir()
    monkeypatch.setenv("BORG_DIR", str(borg_dir))
    monkeypatch.delenv("XDG_CONFIG_HOME", raising=False)
    monkeypatch.delenv("BORG_REGISTRY", raising=False)
    monkeypatch.delenv("BORG_REAP_STALE_HOURS", raising=False)
    monkeypatch.delenv("BORG_NO_REAP", raising=False)
    monkeypatch.delenv("BORG_CORTEX_WAKES", raising=False)
    monkeypatch.delenv("BORG_CORTEX_STATE", raising=False)
    monkeypatch.delenv("BORG_TMUX_SESSION", raising=False)
    monkeypatch.delenv("BORG_MAX_ACTIVE", raising=False)
    monkeypatch.delenv("BORG_ORCHESTRATOR_ROOT", raising=False)
    monkeypatch.setattr(Path, "home", lambda: tmp_path)
    monkeypatch.setenv("PATH", "/nonexistent-bin-dir")  # no real tmux on PATH
    monkeypatch.setattr(shell, "live_windows", lambda: [])
    return tmp_path


def _write_registry(root, projects):
    registry_file = root / "borg-dir" / "registry.json"
    registry_file.write_text(json.dumps({"projects": projects}), encoding="utf-8")
    return registry_file


def _project_dir(root, name):
    directory = root / "ws" / name
    directory.mkdir(parents=True, exist_ok=True)
    return str(directory)


def _delta_workspace(root):
    """Mirrors tests/cli_contract.bats's _link_build_deep_ws: plan 1/3 met, 5 checkpoints (name
    sort deliberately contradicts mtime), 2 directives, 1 assimilated."""
    directory = Path(_project_dir(root, "delta"))
    (directory / ".borg" / "checkpoints").mkdir(parents=True, exist_ok=True)
    (directory / "docs" / "plans" / "directives").mkdir(parents=True, exist_ok=True)
    (directory / "docs" / "plans" / "assimilated").mkdir(parents=True, exist_ok=True)

    (directory / "PROJECT_PLAN.md").write_text(
        "# Project Plan: Delta\n\n## Objective\n\nKeep it stable.\n\n## Acceptance Criteria\n\n"
        "- [x] First criterion, already met.\n- [ ] Second criterion, outstanding.\n"
        "- [ ] Third criterion, outstanding.\n",
        encoding="utf-8",
    )
    checkpoints = directory / ".borg" / "checkpoints"
    for name, body in (
        ("2026-08-01-1000.md", "# Checkpoint one\n\nBody one.\n"),
        ("2026-08-02-1000.md", "# Checkpoint two\n\nBody two.\n"),
        ("2026-08-03-1000.md", "# Checkpoint three\n\nBody three.\n"),
        ("2026-08-04-1000.md", "# Checkpoint four\n\nBody four.\n"),
    ):
        (checkpoints / name).write_text(body, encoding="utf-8")
    head_lines = "\n".join(f"body line {i:02d}" for i in range(2, 26))
    (checkpoints / "2026-08-05-1000.md").write_text(f"# Checkpoint five\n{head_lines}\n", encoding="utf-8")

    directives = directory / "docs" / "plans" / "directives"
    (directives / "2026-04-01-delta-one.md").write_text("# Delta directive one\n", encoding="utf-8")
    (directives / "2026-04-02-delta-two.md").write_text("# Delta directive two\n", encoding="utf-8")

    assimilated = directory / "docs" / "plans" / "assimilated"
    (assimilated / "2026-03-01-delta-only.md").write_text(
        "# Delta shipped only\nShipped: 2026-03-01\n", encoding="utf-8"
    )
    return str(directory)


def test_run_emits_exactly_one_line_of_parseable_json_on_stdout(isolated_env, capsys):
    _write_registry(isolated_env, {})

    exit_code = cli._run("", False, "json")  # pylint: disable=protected-access

    assert exit_code == 0
    captured = capsys.readouterr()
    assert captured.err == ""
    assert captured.out.count("\n") == 1
    doc = json.loads(captured.out)
    assert doc["version"] == 2


def test_run_human_mode_renders_the_seven_section_document(isolated_env, capsys):
    _write_registry(isolated_env, {"solo": {"status": "idle", "last_activity": "2026-08-01T00:00:00Z"}})

    exit_code = cli._run("", False, "human")  # pylint: disable=protected-access

    assert exit_code == 0
    captured = capsys.readouterr()
    assert captured.err == ""
    assert "THE BORG COLLECTIVE" in captured.out
    assert "solo" in captured.out


def test_run_reads_the_wall_clock_exactly_once_per_document(isolated_env, monkeypatch, capsys):
    _write_registry(isolated_env, {"solo": {"status": "idle", "last_activity": "2026-08-01T00:00:00Z"}})
    fixed = 1_800_000_000
    calls = {"n": 0}

    def counting_now():
        calls["n"] += 1
        return fixed

    monkeypatch.setattr(shell, "now_epoch", counting_now)

    cli._run("", False, "json")  # pylint: disable=protected-access

    assert calls["n"] == 1
    doc = json.loads(capsys.readouterr().out)
    assert doc["generated_at"] == core.format_iso(fixed)
    assert doc["projects"]["solo"]["relative_activity"] != "never"


def test_run_resolves_the_registry_from_borg_dir_with_no_env_override(isolated_env, capsys):
    # The recorded blind spot: every other test sets BORG_REGISTRY itself. This one does not, so it
    # exercises paths.registry_path()'s BORG_DIR-derived fallback.
    _write_registry(isolated_env, {"solo": {"status": "idle"}})

    cli._run("", False, "json")  # pylint: disable=protected-access

    doc = json.loads(capsys.readouterr().out)
    assert "solo" in doc["order"]


def test_run_focus_block_for_a_named_project(isolated_env, capsys):
    path = _delta_workspace(isolated_env)
    _write_registry(isolated_env, {"delta": {"path": path, "status": "idle"}})

    cli._run("delta", False, "json")  # pylint: disable=protected-access

    doc = json.loads(capsys.readouterr().out)
    focus = doc["focus"]
    assert focus["name"] == "delta"
    assert focus["plan"] == {
        "objective": "Keep it stable.",
        "met": 1,
        "total": 3,
    }
    assert isinstance(focus["plan"]["met"], int)
    assert isinstance(focus["plan"]["total"], int)
    assert focus["checkpoints"] == ["2026-08-05-1000.md", "2026-08-04-1000.md", "2026-08-03-1000.md"]
    assert len(focus["checkpoints"]) == 3
    head_lines = focus["checkpoint_head"].split("\n")
    assert len(head_lines) == 20
    assert not focus["checkpoint_head"].endswith("\n")
    assert focus["directives"] == [
        {"slug": "2026-04-01-delta-one", "title": "Delta directive one"},
        {"slug": "2026-04-02-delta-two", "title": "Delta directive two"},
    ]
    for directive in focus["directives"]:
        assert "project" not in directive
    assert "relative_activity" in focus["entry"]


def test_run_focus_plan_is_null_when_the_project_has_no_project_plan(isolated_env, capsys):
    path = _project_dir(isolated_env, "noplan")
    _write_registry(isolated_env, {"noplan": {"path": path, "status": "idle"}})

    cli._run("noplan", False, "json")  # pylint: disable=protected-access

    doc = json.loads(capsys.readouterr().out)
    assert doc["focus"]["plan"] is None
    assert doc["focus"]["name"] == "noplan"
    assert doc["focus"]["entry"] is not None


def test_run_focus_unknown_project_raises_project_not_found(isolated_env):
    # `_run`/`_document`/`_focus` stay mode-agnostic: they RAISE rather than dying. Only `main`'s
    # single exception boundary knows the mode and picks a `_die*` format -- see
    # test_main_json_unknown_project_dies_with_the_deep_dive_message and
    # test_main_human_mode_unknown_project_dies_via_die_human below.
    _write_registry(isolated_env, {})

    with pytest.raises(cli.ProjectNotFound) as exc_info:
        cli._run("nope", False, "json")  # pylint: disable=protected-access

    assert exc_info.value.project == "nope"


def test_main_json_unknown_project_dies_with_the_deep_dive_message(isolated_env, capsys):
    _write_registry(isolated_env, {})

    with pytest.raises(SystemExit) as exc_info:
        cli.main(["--json", "--", "nope"])

    assert exc_info.value.code == 1
    captured = capsys.readouterr()
    assert captured.out == ""
    assert "project 'nope' not in registry. Run: borg add [path]" in captured.err


def test_main_human_mode_unknown_project_dies_via_die_human(isolated_env, capsys):
    _write_registry(isolated_env, {})

    with pytest.raises(SystemExit) as exc_info:
        cli.main(["--deep", "--", "nope"])

    assert exc_info.value.code == 1
    captured = capsys.readouterr()
    assert captured.out == ""
    assert captured.err.startswith("\033[0;31m▸ ERROR:\033[0m")
    assert "project 'nope' not in registry. Run: borg add [path]" in captured.err


def test_main_human_mode_clean_error_not_traceback_on_malformed_project_entry(isolated_env, capsys):
    _write_registry(isolated_env, {"foo": None})

    with pytest.raises(SystemExit) as exc_info:
        cli.main(["--porcelain"])

    assert exc_info.value.code == 1
    captured = capsys.readouterr()
    assert captured.out == ""
    assert captured.err.startswith("\033[0;31m▸ ERROR:\033[0m")
    assert "Traceback" not in captured.err


def test_main_json_mode_clean_error_not_traceback_on_malformed_project_entry(isolated_env, capsys):
    # Before this fix, `--json`'s narrow `except (ValueError, OSError)` let a null project entry's
    # AttributeError (core.py's `entry.get()`/`entry.items()`) fall through as a raw traceback on
    # stdout -- verified live. `--json` must die exactly like the human modes: stderr only, empty
    # stdout, no "Traceback".
    _write_registry(isolated_env, {"foo": None})

    with pytest.raises(SystemExit) as exc_info:
        cli.main(["--json"])

    assert exc_info.value.code == 1
    captured = capsys.readouterr()
    assert captured.out == ""
    assert captured.err.startswith("borg link: ")
    assert "Traceback" not in captured.err


def test_main_json_mode_clean_error_not_traceback_on_non_object_projects(isolated_env, capsys):
    registry_file = isolated_env / "borg-dir" / "registry.json"
    registry_file.write_text(json.dumps({"projects": [1, 2, 3]}), encoding="utf-8")

    with pytest.raises(SystemExit) as exc_info:
        cli.main(["--json"])

    assert exc_info.value.code == 1
    captured = capsys.readouterr()
    assert captured.out == ""
    assert captured.err.startswith("borg link: ")
    assert "Traceback" not in captured.err


def test_main_json_mode_clean_error_not_traceback_on_non_object_registry_root(isolated_env, capsys):
    registry_file = isolated_env / "borg-dir" / "registry.json"
    registry_file.write_text(json.dumps([1, 2, 3]), encoding="utf-8")

    with pytest.raises(SystemExit) as exc_info:
        cli.main(["--json"])

    assert exc_info.value.code == 1
    captured = capsys.readouterr()
    assert captured.out == ""
    assert captured.err.startswith("borg link: ")
    assert "Traceback" not in captured.err


def test_main_human_mode_clean_error_not_traceback_on_non_object_projects(isolated_env, capsys):
    registry_file = isolated_env / "borg-dir" / "registry.json"
    registry_file.write_text(json.dumps({"projects": "nope"}), encoding="utf-8")

    with pytest.raises(SystemExit) as exc_info:
        cli.main(["--porcelain"])

    assert exc_info.value.code == 1
    captured = capsys.readouterr()
    assert captured.out == ""
    assert captured.err.startswith("\033[0;31m▸ ERROR:\033[0m")
    assert "Traceback" not in captured.err


def test_main_human_mode_clean_error_not_traceback_on_non_object_registry_root(isolated_env, capsys):
    registry_file = isolated_env / "borg-dir" / "registry.json"
    registry_file.write_text(json.dumps("just a string"), encoding="utf-8")

    with pytest.raises(SystemExit) as exc_info:
        cli.main(["--deep"])

    assert exc_info.value.code == 1
    captured = capsys.readouterr()
    assert captured.out == ""
    assert captured.err.startswith("\033[0;31m▸ ERROR:\033[0m")
    assert "Traceback" not in captured.err


def test_main_porcelain_and_deep_render_through_render_py(isolated_env, capsys):
    path = _delta_workspace(isolated_env)
    _write_registry(isolated_env, {"delta": {"path": path, "status": "idle", "summary": "Delta."}})

    with pytest.raises(SystemExit) as exc_info:
        cli.main(["--porcelain"])
    assert exc_info.value.code == 0
    out = capsys.readouterr().out
    assert out.startswith("delta\t")

    with pytest.raises(SystemExit) as exc_info:
        cli.main(["--deep", "--", "delta"])
    assert exc_info.value.code == 0
    out = capsys.readouterr().out
    assert "Session ID:" in out


def test_repository_scope_calls_no_aggregate_collector_on_the_human_path(isolated_env, capsys, monkeypatch):
    # C1. The two aggregate collectors are a directory-glob-plus-markdown-read pass over EVERY
    # registered project, and both hot loops (drone.zsh's per-tmux-window status table, borg.zsh's
    # per-keypress fzf preview) pass a NAME -- so both land in repository scope and must skip them
    # exactly as the retired `deep` mode did. Mutating `need_aggregate` to `mode != "porcelain"`
    # turns this red and puts a 14-project glob back into both.
    path = _delta_workspace(isolated_env)
    _write_registry(isolated_env, {"delta": {"path": path, "status": "idle"}})

    calls = {"directives": 0, "assimilated": 0}
    real_directives = shell.collect_all_directives
    real_assimilated = shell.collect_all_assimilated

    def counting_directives(registry):
        calls["directives"] += 1
        return real_directives(registry)

    def counting_assimilated(registry, max_items=3):
        calls["assimilated"] += 1
        return real_assimilated(registry, max_items)

    monkeypatch.setattr(shell, "collect_all_directives", counting_directives)
    monkeypatch.setattr(shell, "collect_all_assimilated", counting_assimilated)

    with pytest.raises(SystemExit):
        cli.main(["--porcelain"])
    capsys.readouterr()
    assert calls == {"directives": 0, "assimilated": 0}

    with pytest.raises(SystemExit):
        cli.main(["--deep", "--", "delta"])
    capsys.readouterr()
    assert calls == {"directives": 0, "assimilated": 0}

    with pytest.raises(SystemExit):
        cli.main(["--json"])
    capsys.readouterr()
    assert calls == {"directives": 1, "assimilated": 1}

    with pytest.raises(SystemExit):
        cli.main([])
    capsys.readouterr()
    assert calls == {"directives": 2, "assimilated": 2}


def test_focus_is_gathered_for_a_positional_and_for_repository_scope_but_never_for_porcelain(
    isolated_env, capsys, monkeypatch
):
    path = _delta_workspace(isolated_env)
    _write_registry(isolated_env, {"delta": {"path": path, "status": "idle"}})

    calls = {"n": 0}
    real_focus = cli._focus  # pylint: disable=protected-access

    def counting_focus(project, registry, now_epoch):
        calls["n"] += 1
        return real_focus(project, registry, now_epoch)

    monkeypatch.setattr(cli, "_focus", counting_focus)

    with pytest.raises(SystemExit):
        cli.main(["--porcelain"])
    capsys.readouterr()
    assert calls["n"] == 0

    with pytest.raises(SystemExit):
        cli.main([])
    capsys.readouterr()
    assert calls["n"] == 0

    with pytest.raises(SystemExit):
        cli.main(["--deep", "--", "delta"])
    capsys.readouterr()
    assert calls["n"] == 1

    with pytest.raises(SystemExit):
        cli.main(["--json", "--", "delta"])
    capsys.readouterr()
    assert calls["n"] == 2


def test_run_focus_finds_an_archived_project_even_without_all(isolated_env, capsys):
    path = _project_dir(isolated_env, "delta")
    _write_registry(isolated_env, {"delta": {"path": path, "status": "archived"}})

    exit_code = cli._run("delta", False, "json")  # pylint: disable=protected-access

    assert exit_code == 0
    doc = json.loads(capsys.readouterr().out)
    assert doc["focus"]["name"] == "delta"
    assert "delta" not in doc["order"]
    assert "delta" not in doc["projects"]


def test_main_parses_argv_including_a_dash_leading_project_and_wraps_a_corrupt_registry(isolated_env, capsys):
    _write_registry(isolated_env, {"delta": {"path": _project_dir(isolated_env, "delta"), "status": "idle"}})

    with pytest.raises(SystemExit) as exc_info:
        cli.main(["--json"])
    assert exc_info.value.code == 0
    capsys.readouterr()

    with pytest.raises(SystemExit) as exc_info:
        cli.main(["--json", "--all", "--", "delta"])
    assert exc_info.value.code == 0
    doc = json.loads(capsys.readouterr().out)
    assert doc["show_all"] is True

    with pytest.raises(SystemExit) as exc_info:
        cli.main(["--json", "--", "-weird"])
    assert exc_info.value.code == 1
    captured = capsys.readouterr()
    assert "not in registry" in captured.err

    (isolated_env / "borg-dir" / "registry.json").write_text("NOT JSON", encoding="utf-8")
    with pytest.raises(SystemExit) as exc_info:
        cli.main(["--json"])
    assert exc_info.value.code == 1
    captured = capsys.readouterr()
    assert captured.err.count("\n") == 1


# --- scope threading through _document (S1) ----------------------------------------------------


def _scope_registry(root):
    alpha = root / "alpha"
    beta = root / "beta"
    alpha.mkdir()
    beta.mkdir()
    registry_file = root / "borg-dir" / "registry.json"
    registry_file.write_text(
        json.dumps({"projects": {"alpha": {"path": str(alpha)}, "beta": {"path": str(beta)}}}),
        encoding="utf-8",
    )
    return alpha, beta


def test_document_emits_scope_resolved_from_cwd(isolated_env, monkeypatch):
    alpha, _beta = _scope_registry(isolated_env)
    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", str(isolated_env))
    monkeypatch.chdir(alpha)
    doc = cli._document("", False, "json")
    assert doc["scope"]["kind"] == "repository"
    assert doc["scope"]["repository"] == "alpha"


def test_document_scope_is_orchestrator_at_the_workspace_root(isolated_env, monkeypatch):
    _scope_registry(isolated_env)
    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", str(isolated_env))
    monkeypatch.chdir(isolated_env)
    doc = cli._document("", False, "json")
    assert doc["scope"]["kind"] == "orchestrator"
    assert doc["scope"]["repository"] is None


def test_document_explicit_project_dominates_cwd(isolated_env, monkeypatch):
    # B3 end-to-end, through the real _document rather than the pure resolver: standing in alpha and
    # asking for beta must scope to BETA. Resolving breadth from cwd here would render alpha's facts
    # under beta's header -- and every scripted caller passes a name from a fixed cwd
    # (drone.zsh:964's per-window loop, borg.zsh:266's fzf preview).
    alpha, _beta = _scope_registry(isolated_env)
    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", str(isolated_env))
    monkeypatch.chdir(alpha)
    doc = cli._document("beta", False, "json")
    assert doc["scope"]["repository"] == "beta"
    assert doc["focus"]["name"] == "beta"


def test_document_scope_records_local(isolated_env, monkeypatch):
    alpha, _beta = _scope_registry(isolated_env)
    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", str(isolated_env))
    monkeypatch.chdir(alpha)
    assert cli._document("", False, "json", True)["scope"]["local"] is True
    assert cli._document("", False, "json", False)["scope"]["local"] is False


def test_local_flag_parses_and_defaults_off():
    assert cli._build_parser().parse_args([]).local is False
    assert cli._build_parser().parse_args(["--local"]).local is True


def test_scope_is_present_in_every_mode(isolated_env, monkeypatch):
    # porcelain and deep skip the aggregate collectors, but scope is not an aggregate -- it must be
    # resolved for every mode, or the document's breadth claim depends on which renderer asked.
    alpha, _beta = _scope_registry(isolated_env)
    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", str(isolated_env))
    monkeypatch.chdir(alpha)
    for mode in ("json", "overview", "porcelain"):
        assert cli._document("", False, mode)["scope"]["repository"] == "alpha"
    assert cli._document("alpha", False, "deep")["scope"]["repository"] == "alpha"


def test_json_carries_the_aggregates_in_every_scope(isolated_env, monkeypatch):
    """C2. `--json` is SCOPE-INDEPENDENT, and that is the actual precondition for not bumping
    DOCUMENT_VERSION. skills/borg-link/SKILL.md runs a bare `borg link --json | jq '.directives |=
    (...)'` from inside whatever repository the session happens to be in; scope-gating the
    aggregates would report "Queued: 0 directives" for the whole collective at `.version == 2`,
    which SKILL.md maps to "CLI path. Never fall back." A wrong answer, not a missing one.

    Mutation: `need_aggregate = mode != "porcelain" and scope["kind"] == "orchestrator"`.
    """
    alpha, _beta = _scope_registry(isolated_env)
    directives = alpha / "docs" / "plans" / "directives"
    directives.mkdir(parents=True)
    (directives / "2026-04-01-alpha-one.md").write_text("# Alpha directive one\n", encoding="utf-8")
    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", str(isolated_env))

    monkeypatch.chdir(isolated_env)
    from_root = cli._document("", False, "json")  # pylint: disable=protected-access
    monkeypatch.chdir(alpha)
    from_inside = cli._document("", False, "json")  # pylint: disable=protected-access

    assert from_root["scope"]["kind"] == "orchestrator"
    assert from_inside["scope"]["kind"] == "repository"
    assert from_inside["version"] == from_root["version"] == 2
    assert [d["title"] for d in from_inside["directives"]] == ["Alpha directive one"]
    assert from_inside["directives"] == from_root["directives"]


def test_focus_follows_scope_when_no_positional_is_given(isolated_env, monkeypatch):
    """C3. `cd <repo> && borg link` -- the modal human invocation -- must render the repository's own
    card, its directives and its shipped plans. `_focus` short-circuits on an empty positional, so
    passing `project` alone (rather than `project or scope["repository"]`) renders the IN FOCUS
    placeholder, no `Status:` line, and empty QUEUED/SHIPPED for a repository with files on disk."""
    alpha, _beta = _scope_registry(isolated_env)
    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", str(isolated_env))
    monkeypatch.chdir(alpha)

    doc = cli._document("", False, "human")  # pylint: disable=protected-access

    assert doc["scope"]["repository"] == "alpha"
    assert doc["focus"] is not None
    assert doc["focus"]["name"] == "alpha"


def test_an_unregistered_positional_raises_before_any_aggregate_collector_runs(isolated_env, monkeypatch):
    """C4 + B8. `scope_for` honours a positional only when it is IN THE REGISTRY, so `borg link
    ghost` from the workspace root resolves to ORCHESTRATOR scope -- which is exactly the shape
    where a purely scope-derived `need_focus` would skip `_focus`, skip the raise, and exit 0 with a
    full board instead of exit 1. `bool(project) or ...` preserves it.

    The collectors are monkeypatched to RAISE rather than counted: `_focus` sits above them so a
    miss costs nothing, and moving the assignment back below the aggregate block makes an unknown
    tmux window name pay a 14-project glob before it fails.
    """
    _scope_registry(isolated_env)
    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", str(isolated_env))
    monkeypatch.chdir(isolated_env)

    def _boom(*_args, **_kwargs):
        raise AssertionError("an aggregate collector ran before the ProjectNotFound raise")

    monkeypatch.setattr(shell, "collect_all_directives", _boom)
    monkeypatch.setattr(shell, "collect_all_assimilated", _boom)

    with pytest.raises(cli.ProjectNotFound) as exc_info:
        cli._document("ghost", False, "human")  # pylint: disable=protected-access
    assert exc_info.value.project == "ghost"


def test_porcelain_computes_no_focus_no_aggregates_and_no_cortex_pending(isolated_env, monkeypatch):
    """C5. `--porcelain` narrows nothing and computes nothing: it reads only `order`/`projects`.
    `cortex_pending` is included here because AC2 un-gated it from the aggregates -- the pause row
    hangs off a BOARD row, and the board renders in both human contexts but in no machine one."""
    alpha, _beta = _scope_registry(isolated_env)
    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", str(isolated_env))
    monkeypatch.chdir(alpha)  # repository scope, where focus WOULD otherwise be computed

    def _boom(*_args, **_kwargs):
        raise AssertionError("porcelain computed work no TSV row reads")

    monkeypatch.setattr(shell, "collect_all_directives", _boom)
    monkeypatch.setattr(shell, "collect_all_assimilated", _boom)
    monkeypatch.setattr(shell, "cortex_pending", _boom)
    monkeypatch.setattr(cli, "_focus", _boom)

    doc = cli._document("", False, "porcelain")  # pylint: disable=protected-access

    assert doc["focus"] is None
    assert doc["directives"] == []
    assert doc["assimilated"] == []
    assert doc["cortex_pending"] == []


def test_cortex_pending_is_read_on_both_human_contexts(isolated_env, monkeypatch):
    """The other half of C5: the board's cortex pause row must survive in REPOSITORY scope too, and
    it would not if `cortex_pending` had stayed gated with the aggregates."""
    alpha, _beta = _scope_registry(isolated_env)
    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", str(isolated_env))
    calls = {"n": 0}

    def counting_pending(now=None):  # pylint: disable=unused-argument
        calls["n"] += 1
        return []

    monkeypatch.setattr(shell, "cortex_pending", counting_pending)

    monkeypatch.chdir(alpha)
    cli._document("", False, "human")  # pylint: disable=protected-access
    monkeypatch.chdir(isolated_env)
    cli._document("", False, "human")  # pylint: disable=protected-access
    assert calls["n"] == 2


def test_deep_is_accepted_and_ignored(isolated_env, capsys):
    """C6. `--deep` collapsed into repository scope but STAYS in the parser: one live copy of the
    dispatcher passes it -- borg.zsh's positional arm at borg.zsh:3111, which is the fzf preview's
    path -- and deleting the argument makes argparse exit 2 where `drone status` and the fzf preview
    both swallow the failure silently.

    This docstring used to say THREE copies, counting bin/link-parity-harness and its byte-copy at
    ~/.claude/bin/. Neither ever passed `--deep` (the harness looped a bare positional), and AC2/S4
    retired the harness leg that looped at all. Corrected, not weakened: the surviving copy is the
    one whose failure is invisible, which is the whole reason the flag is kept.

    Mutation: drop the `parser.add_argument("--deep", ...)` line -> SystemExit(2), empty stdout.
    """
    args = cli._build_parser().parse_args(["--deep", "--", "delta"])  # pylint: disable=protected-access
    assert args.deep is True
    assert cli._mode(args) == "human"  # pylint: disable=protected-access

    path = _project_dir(isolated_env, "delta")
    _write_registry(isolated_env, {"delta": {"path": path, "status": "idle", "summary": "Delta."}})

    with pytest.raises(SystemExit) as exc_info:
        cli.main(["--deep", "--", "delta"])
    assert exc_info.value.code == 0
    with_deep = capsys.readouterr().out

    with pytest.raises(SystemExit) as exc_info:
        cli.main(["--", "delta"])
    assert exc_info.value.code == 0
    without_deep = capsys.readouterr().out

    assert with_deep == without_deep
    assert "▸ IN FOCUS" in with_deep


def test_mode_collapses_to_three_values(isolated_env):  # pylint: disable=unused-argument
    parser = cli._build_parser()  # pylint: disable=protected-access
    assert cli._mode(parser.parse_args(["--json"])) == "json"  # pylint: disable=protected-access
    assert cli._mode(parser.parse_args(["--porcelain"])) == "porcelain"  # pylint: disable=protected-access
    assert cli._mode(parser.parse_args([])) == "human"  # pylint: disable=protected-access
    # `--json` beats `--porcelain` beats everything; `--deep` never wins anything.
    assert cli._mode(parser.parse_args(["--json", "--porcelain", "--deep"])) == "json"  # pylint: disable=protected-access
    assert cli._mode(parser.parse_args(["--porcelain", "--deep"])) == "porcelain"  # pylint: disable=protected-access


def test_focus_of_an_empty_project_is_none(isolated_env):  # pylint: disable=unused-argument
    """`_focus`'s empty-positional guard became UNREACHABLE from `_document` in AC2: `need_focus` is
    `bool(project) or scope["kind"] == "repository"`, and both arms guarantee a non-empty name by the
    time `project or scope["repository"]` is evaluated. It stays because the function must be total
    for any future caller, and it is covered DIRECTLY rather than left to look like a live path --
    the same treatment `picture.link_ref` gives its unlinkable arm."""
    assert cli._focus("", {"projects": {}}, 0) is None  # pylint: disable=protected-access


def test_a_consumer_that_stops_reading_gets_no_traceback(monkeypatch):
    """SIGPIPE, caught in `_emit` and NEVER in render.py, which stays pure. The seven-section
    document is much larger than the deep dive it replaced and can exceed the 64KB pipe buffer, so
    `borg link | grep -m1 Status:` can leave this writing into a closed pipe. Uncaught, CPython
    prints a BrokenPipeError traceback that drone.zsh's status table would merge into a column."""
    sink = os.open(os.devnull, os.O_WRONLY)

    class ClosedPipe:
        """Every write fails the way a pipe whose reader exited does; `fileno` is real so the
        devnull redirect in the handler has something to dup2 onto."""

        def write(self, _text):
            raise BrokenPipeError(32, "Broken pipe")

        def flush(self):
            raise BrokenPipeError(32, "Broken pipe")

        def fileno(self):
            return sink

    monkeypatch.setattr(sys, "stdout", ClosedPipe())
    try:
        assert cli._emit("x" * 100_000) == 0  # pylint: disable=protected-access
    finally:
        os.close(sink)


def test_document_scope_survives_an_archived_repository(isolated_env, monkeypatch):
    # --all is a DISPLAY filter; an archived repository is still the repository you are standing in.
    # Resolving scope against the filtered map would silently report orchestrator breadth here.
    # The visibility filter is `entry.get("status") != "archived"` (core.visible_projects) -- NOT an
    # `archived: true` boolean. An earlier version of this test wrote the boolean, which archives
    # nothing, so the entry stayed visible and the assertion could not distinguish scope-from-
    # `overlaid` (correct) from scope-from-`projects` (the filtered map). Assert the filter really
    # bit before asserting scope survived it.
    alpha = isolated_env / "alpha"
    alpha.mkdir()
    (isolated_env / "borg-dir" / "registry.json").write_text(
        json.dumps({"projects": {"alpha": {"path": str(alpha), "status": "archived"}}}),
        encoding="utf-8",
    )
    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", str(isolated_env))
    monkeypatch.chdir(alpha)
    doc = cli._document("", False, "json")
    assert doc["order"] == []  # the filter bit: alpha is hidden from the display map
    assert doc["total_projects"] == 1  # but it is still in the registry
    assert doc["scope"]["repository"] == "alpha"  # and it is still where you are standing
