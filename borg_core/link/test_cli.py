"""Tests for borg_core.link.cli -- the `--json` seam (Phase 2, A3).

Calling convention: in-process only (cli._run(...), cli.main([...])). Never subprocess, never
bats-from-pytest. Capture with capsys, assert exits with pytest.raises(SystemExit), parse JSON with
json.loads and index keys -- never string-compare the serialized form.
"""

import json
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


def test_run_overview_mode_renders_the_human_table(isolated_env, capsys):
    _write_registry(isolated_env, {"solo": {"status": "idle", "last_activity": "2026-08-01T00:00:00Z"}})

    exit_code = cli._run("", False, "overview")  # pylint: disable=protected-access

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
