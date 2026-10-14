"""Tests for borg_core.link.cli -- the `--json` seam (Phase 2, A3).

Calling convention: in-process only (cli._run(...), cli.main([...])). Never subprocess, never
bats-from-pytest. Capture with capsys, assert exits with pytest.raises(SystemExit), parse JSON with
json.loads and index keys -- never string-compare the serialized form.
"""

import io
import json
import os
import shutil
import sys
from pathlib import Path

import pytest

from borg_core.link import cli, core, picture, shell


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


def _stand_at_queen(root, monkeypatch):
    """Make cwd the Queen root: the only place (besides `--overview`) the cross-repository page renders.

    Since 2026-10-13 a cwd that is neither the Queen root nor inside a registered path prints the hint page, so
    a test that wants the overview must stand where the overview lives.
    """
    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", str(root))
    monkeypatch.chdir(root)


def _write_registry(root, repositories):
    registry_file = root / "borg-dir" / "registry.json"
    registry_file.write_text(json.dumps({"projects": repositories}), encoding="utf-8")
    return registry_file


def _repository_dir(root, name):
    directory = root / "ws" / name
    directory.mkdir(parents=True, exist_ok=True)
    return str(directory)


def _delta_workspace(root):
    """Mirrors tests/cli_contract.bats's _link_build_deep_ws: plan 1/3 met, 5 checkpoints (name
    sort deliberately contradicts mtime), 2 directives, 1 assimilated."""
    directory = Path(_repository_dir(root, "delta"))
    (directory / ".borg" / "checkpoints").mkdir(parents=True, exist_ok=True)
    (directory / "docs" / "plans" / "directives").mkdir(parents=True, exist_ok=True)
    (directory / "docs" / "plans" / "assimilated").mkdir(parents=True, exist_ok=True)

    # A WRAPPED PARAGRAPH, matching the bats fixture: the objective is read as a paragraph and folded
    # to the page, and a one-line fixture here would leave the pytest side blind to both.
    (directory / "PROJECT_PLAN.md").write_text(
        "# Project Plan: Delta\n\n## Objective\n\n"
        "Keep it stable, and keep the objective a wrapped paragraph\n"
        "so this workspace exercises the same read the bats fixture does.\n\n"
        "## Acceptance Criteria\n\n"
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


_LINK_FIXTURES = Path(__file__).resolve().parents[2] / "tests" / "fixtures" / "link"


def _manifest_workspace(root, name="warehouse"):
    """A registered repository carrying a SHIPPED fixture manifest under `.stacks/`.

    The bytes are `tests/fixtures/link/manifests/warehouse-rollout.json`'s, not an inline copy: the
    goldens pin the same file's rendered form, so a test that built its own rows could stay green
    while the fixture the goldens measure moved underneath it.
    """
    programs = Path(_repository_dir(root, name)) / ".stacks"
    programs.mkdir(parents=True, exist_ok=True)
    shutil.copy(_LINK_FIXTURES / "manifests" / "warehouse-rollout.json", programs)
    return str(Path(_repository_dir(root, name)))


def test_json_publishes_the_measured_picture_width_on_the_grid_block(isolated_env, capsys, monkeypatch):
    """The width-check directive's first AC: the widest picture row is OBSERVABLE WITHOUT ANSI.

    MUTATION, APPLIED AND CONFIRMED RED: replace `picture.max_row_width(block["manifests"])` in
    `cli._grid` with the literal `0`, or delete the stamp entirely. Either drops `picture_width` to
    0/absent while the manifests on the very same block still rasterize to a 61-column picture, and
    the equality below fails.

    THE DOCUMENT MUST CARRY A PICTURE FOR THIS TO MEAN ANYTHING, which is why a repository holding a
    real manifest is registered rather than an empty registry asserted at 0. An empty registry
    supplies the condition that makes the derived value equal its own default -- the `borg recon`
    failure this repo shipped for months -- so it is asserted at the END, as the empty case, and never
    as the evidence that the measurement ran.

    THE EXPECTED NUMBER IS NOT WRITTEN DOWN. It is re-derived from the manifests the document itself
    published, so moving the fixture moves both sides together and the assertion never goes stale
    against a number nobody re-measures. `tests/cli_contract.bats`'s companion case
    ("grid.picture_width is the width of the widest picture row the same run rendered") is the half
    that derives it INDEPENDENTLY, off the rendered ANSI page rather than off `max_row_width`.

    NESTED UNDER `.grid` AND ASSERTED THERE. `skills/borg-link/SKILL.md` pipes the document through a
    `jq` whitelist that selects `grid` wholesale; a top-level `picture_width` would be silently
    dropped on the skill's own path while passing a naive top-level assertion here.
    """
    directory = _manifest_workspace(isolated_env)
    _write_registry(isolated_env, {"warehouse": {"path": directory, "status": "idle"}})
    # cwd decides scope, and the worktree this suite runs in is a git repository -- which would make
    # the invocation repository-scoped against borg-collective and select no manifest at all.
    monkeypatch.chdir(isolated_env)

    exit_code = cli._run("", False, "json", local=True)  # pylint: disable=protected-access

    assert exit_code == 0
    doc = json.loads(capsys.readouterr().out)
    manifests = doc["grid"]["manifests"]
    assert manifests, "no manifest reached the document; the assertion below would be vacuous"

    width = doc["grid"]["picture_width"]
    assert isinstance(width, int) and not isinstance(width, bool)
    assert width == picture.max_row_width(manifests) > 0
    assert doc["version"] == 2, "an additive key inside an additive block does not bump the version"

    # ...and only now the empty case, which is a statement about the DEFAULT and not about the
    # measurement: a repository with nothing declared has a picture zero columns wide, not an error.
    capsys.readouterr()
    _write_registry(isolated_env, {})
    assert cli._run("", False, "json", local=True) == 0  # pylint: disable=protected-access
    empty = json.loads(capsys.readouterr().out)["grid"]
    assert empty["manifests"] == [] and empty["picture_width"] == 0


def test_run_human_mode_renders_the_seven_section_document(isolated_env, capsys, monkeypatch):
    _write_registry(isolated_env, {"solo": {"status": "idle", "last_activity": "2026-08-01T00:00:00Z"}})
    _stand_at_queen(isolated_env, monkeypatch)

    exit_code = cli._run("", False, "human")  # pylint: disable=protected-access

    assert exit_code == 0
    captured = capsys.readouterr()
    assert captured.err == ""
    assert "THE BORG COLLECTIVE" in captured.out
    assert "solo" in captured.out


def test_an_unregistered_cwd_prints_the_hint_page_exits_zero_and_reads_nothing_else(isolated_env, capsys, monkeypatch):
    """Decision (3), end to end: neither the Queen root nor inside a registered path => a short page, exit 0.

    The hint page reads NOTHING: no sweep, no manifest glob, no aggregate. MUTATION: remove `hint_only` in
    `_document` and the three counters below go red while the page itself stays identical -- the cost of a page
    that throws its whole document away. `--json` is NOT short-circuited: it carries the full document from any
    cwd and says `scope.unregistered` (additive; `kind` is still "orchestrator").
    """
    registered = _repository_dir(isolated_env, "registered-secret")
    _write_registry(isolated_env, {"registered-secret": {"path": registered, "status": "idle"}})
    stranger = isolated_env / "stranger"
    stranger.mkdir()
    queen = isolated_env / "queen"
    queen.mkdir()
    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", str(queen))
    monkeypatch.chdir(stranger)

    calls = {"sweep": 0, "discover": 0, "aggregate": 0}

    def counting(name, real):
        def wrapper(*args, **kwargs):
            calls[name] += 1
            return real(*args, **kwargs)

        return wrapper

    monkeypatch.setattr(shell, "sweep", counting("sweep", shell.sweep))
    monkeypatch.setattr(shell, "discover_manifests", counting("discover", shell.discover_manifests))
    monkeypatch.setattr(shell, "collect_all_directives", counting("aggregate", shell.collect_all_directives))

    assert cli._run("", False, "human") == 0  # pylint: disable=protected-access
    captured = capsys.readouterr()
    page = captured.out
    assert captured.err == ""
    assert "This directory is not a registered repository." in page
    assert "borg add" in page and "borg link --overview" in page
    assert "registered-secret" not in page and "THE BORG COLLECTIVE" not in page and "REPOSITORIES" not in page
    assert calls == {"sweep": 0, "discover": 0, "aggregate": 0}

    assert cli._run("", False, "json", local=True) == 0  # pylint: disable=protected-access
    doc = json.loads(capsys.readouterr().out)
    assert doc["scope"]["kind"] == "orchestrator" and doc["scope"]["unregistered"] is True
    assert doc["order"] == ["registered-secret"], "--json carries the whole document from any cwd"

    # `--overview` asks for the Queen view by name, from the same stranger directory, and gets it.
    assert cli._run("", False, "human", local=True, overview=True) == 0  # pylint: disable=protected-access
    overview = capsys.readouterr().out
    assert "registered-secret" in overview and "not a registered repository" not in overview


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


def test_run_focus_block_for_a_named_repository(isolated_env, capsys):
    path = _delta_workspace(isolated_env)
    _write_registry(isolated_env, {"delta": {"path": path, "status": "idle"}})

    cli._run("delta", False, "json")  # pylint: disable=protected-access

    doc = json.loads(capsys.readouterr().out)
    focus = doc["focus"]
    assert focus["name"] == "delta"
    assert focus["plan"] == {
        # THE WHOLE WRAPPED PARAGRAPH, joined with single spaces, not its first physical line.
        # `core.plan_objective` used to transcribe the shell's `head -1`, so a real objective --
        # prose, hard-wrapped at 120 columns in this tree -- reached the wire as a fragment.
        "objective": (
            "Keep it stable, and keep the objective a wrapped paragraph "
            "so this workspace exercises the same read the bats fixture does."
        ),
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


def test_run_focus_plan_is_null_when_the_repository_has_no_project_plan(isolated_env, capsys):
    path = _repository_dir(isolated_env, "noplan")
    _write_registry(isolated_env, {"noplan": {"path": path, "status": "idle"}})

    cli._run("noplan", False, "json")  # pylint: disable=protected-access

    doc = json.loads(capsys.readouterr().out)
    assert doc["focus"]["plan"] is None
    assert doc["focus"]["name"] == "noplan"
    assert doc["focus"]["entry"] is not None


def test_run_focus_unknown_repository_raises_repository_not_found(isolated_env):
    # `_run`/`_document`/`_focus` stay mode-agnostic: they RAISE rather than dying. Only `main`'s
    # single exception boundary knows the mode and picks a `_die*` format -- see
    # test_main_json_unknown_repository_dies_with_the_deep_dive_message and
    # test_main_human_mode_unknown_repository_dies_via_die_human below.
    _write_registry(isolated_env, {})

    with pytest.raises(cli.RepositoryNotFound) as exc_info:
        cli._run("nope", False, "json")  # pylint: disable=protected-access

    assert exc_info.value.repository == "nope"


def test_main_json_unknown_repository_dies_with_the_deep_dive_message(isolated_env, capsys):
    _write_registry(isolated_env, {})

    with pytest.raises(SystemExit) as exc_info:
        cli.main(["--json", "--", "nope"])

    assert exc_info.value.code == 1
    captured = capsys.readouterr()
    assert captured.out == ""
    assert "repository 'nope' not in registry. Run: borg add [path]" in captured.err


def test_main_human_mode_unknown_repository_dies_via_die_human(isolated_env, capsys):
    _write_registry(isolated_env, {})

    with pytest.raises(SystemExit) as exc_info:
        cli.main(["--deep", "--", "nope"])

    assert exc_info.value.code == 1
    captured = capsys.readouterr()
    assert captured.out == ""
    assert captured.err.startswith("\033[0;31m▸ ERROR:\033[0m")
    assert "repository 'nope' not in registry. Run: borg add [path]" in captured.err


def test_main_human_mode_clean_error_not_traceback_on_malformed_repository_entry(isolated_env, capsys):
    _write_registry(isolated_env, {"foo": None})

    with pytest.raises(SystemExit) as exc_info:
        cli.main(["--porcelain"])

    assert exc_info.value.code == 1
    captured = capsys.readouterr()
    assert captured.out == ""
    assert captured.err.startswith("\033[0;31m▸ ERROR:\033[0m")
    assert "Traceback" not in captured.err


def test_main_json_mode_clean_error_not_traceback_on_malformed_repository_entry(isolated_env, capsys):
    # Before this fix, `--json`'s narrow `except (ValueError, OSError)` let a null repository entry's
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


# ── --render-document: one document, two consumers ────────────────────────────────────────────────


def test_render_document_prints_the_same_page_the_human_arm_would(isolated_env, capsys, monkeypatch):
    """AC1's fold, stated as an equality rather than as a claim about call sites.

    `borg link --brief` builds the document ONCE with `--json`, projects it into the narrative
    prompt, and pipes THOSE SAME BYTES back through `--render-document` when the narrative fails. If
    that round trip did not reproduce the human page byte for byte, the fallback would be a second
    truth level inside one invocation -- which is the defect the fold exists to remove.

    THE CLOCK IS PINNED FOR THE COMPARISON, and that is the point rather than a convenience: without
    it the two builds below would legitimately differ in `generated_at` and every relative time, and
    the equality would have to be weakened to a substring check that could not see a real
    divergence. Pinning it is also what makes the failure mode visible -- the reason the fallback
    must NOT rebuild is precisely that a rebuild reads the clock a second time.
    """
    path = _delta_workspace(isolated_env)
    _write_registry(isolated_env, {"delta": {"path": path, "status": "idle", "summary": "Delta."}})
    _stand_at_queen(isolated_env, monkeypatch)
    monkeypatch.setattr(shell, "now_epoch", lambda: 1_800_000_000)

    with pytest.raises(SystemExit) as exc_info:
        cli.main(["--json"])
    assert exc_info.value.code == 0
    document_json = capsys.readouterr().out

    with pytest.raises(SystemExit) as exc_info:
        cli.main([])
    assert exc_info.value.code == 0
    human_page = capsys.readouterr().out

    monkeypatch.setattr(sys, "stdin", io.StringIO(document_json))
    with pytest.raises(SystemExit) as exc_info:
        cli.main(["--render-document"])
    assert exc_info.value.code == 0
    rendered_from_json = capsys.readouterr().out

    assert rendered_from_json == human_page
    assert "THE BORG COLLECTIVE" in rendered_from_json


def test_render_document_builds_nothing_of_its_own(isolated_env, capsys, monkeypatch):
    """The whole reason the seam exists: no clock read, no registry read, no sweep, no manifest glob.

    Asserted by making every one of those explode. A `--render-document` that quietly rebuilt would
    be indistinguishable from this one on stdout -- it would print the same page -- and only
    something that fails on contact can tell them apart.
    """
    _write_registry(isolated_env, {"solo": {"status": "idle", "last_activity": "2026-08-01T00:00:00Z"}})
    _stand_at_queen(isolated_env, monkeypatch)
    with pytest.raises(SystemExit):
        cli.main(["--json"])
    document_json = capsys.readouterr().out

    def _forbidden(*_args, **_kwargs):
        raise AssertionError("--render-document must not build a document of its own")

    monkeypatch.setattr(shell, "now_epoch", _forbidden)
    monkeypatch.setattr(shell, "read_registry", _forbidden)
    monkeypatch.setattr(shell, "registry_with_state", _forbidden)
    monkeypatch.setattr(shell, "sweep", _forbidden)
    monkeypatch.setattr(shell, "discover_manifests", _forbidden)
    monkeypatch.setattr(sys, "stdin", io.StringIO(document_json))

    with pytest.raises(SystemExit) as exc_info:
        cli.main(["--render-document"])
    assert exc_info.value.code == 0
    assert "solo" in capsys.readouterr().out


def test_render_document_dies_clean_on_malformed_stdin(isolated_env, capsys, monkeypatch):
    """A truncated pipe must die through `main`'s one exception boundary, not as a traceback.

    The caller is a zsh fallback path that has ALREADY had one thing fail; a Python traceback
    spliced onto its stdout would be the second failure reported as the first.
    """
    monkeypatch.setattr(sys, "stdin", io.StringIO('{"version": 2, "projec'))

    with pytest.raises(SystemExit) as exc_info:
        cli.main(["--render-document"])
    assert exc_info.value.code == 1
    captured = capsys.readouterr()
    assert captured.out == ""
    assert "▸ ERROR:" in captured.err
    assert "Traceback" not in captured.err


@pytest.mark.parametrize("mode_flag", ["--json", "--porcelain"])
def test_render_document_refuses_to_be_combined_with_a_mode(isolated_env, capsys, monkeypatch, mode_flag):
    """`--render-document` is not a mode, so pairing it with one is refused rather than reconciled.

    IT USED TO BE ANSWERED BY IGNORING HALF OF IT. `mode = _mode(args)` runs before the
    `args.render_document` branch, so `--json --render-document` selected `_die_json` as the failure
    formatter and then printed the human ANSI page on success -- a shape wart rather than a live bug
    (borg.zsh's one caller passes `--render-document` alone), but the kind that becomes a bug the
    first time somebody adds a second caller.

    ARGPARSE'S OWN ERROR PATH, exit 2 with usage on stderr, NOT a `_die_*` exit 1: this is a malformed
    invocation, not a failed one, and it must stay distinguishable from a corrupt document. Zero bytes
    on stdout either way.
    """
    monkeypatch.setattr(sys, "stdin", io.StringIO('{"version": 2}'))

    with pytest.raises(SystemExit) as exc_info:
        cli.main([mode_flag, "--render-document"])
    assert exc_info.value.code == 2
    captured = capsys.readouterr()
    assert captured.out == ""
    assert "--render-document is not a mode" in captured.err


def test_repository_scope_calls_no_aggregate_collector_on_the_human_path(isolated_env, capsys, monkeypatch):
    # C1. The two aggregate collectors are a directory-glob-plus-markdown-read pass over EVERY
    # registered repository, and a NAMED invocation lands in repository scope, which must skip them
    # exactly as the retired `deep` mode did. Mutating `need_aggregate` to `mode != "porcelain"`
    # turns this red and puts a 14-repository glob back on every `borg link <repository>`.
    # (This used to justify the skip by "both hot loops (drone.zsh's per-tmux-window status table,
    # borg.zsh's per-keypress fzf preview) pass a NAME". Both were retired 2026-08-27, so the skip
    # now saves the glob once per typed command rather than per keypress. What lapsed is the size of
    # the prize, not the invariant -- the assertion is unchanged.)
    path = _delta_workspace(isolated_env)
    _write_registry(isolated_env, {"delta": {"path": path, "status": "idle"}})
    _stand_at_queen(isolated_env, monkeypatch)

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

    def counting_focus(repository, registry, now_epoch):
        calls["n"] += 1
        return real_focus(repository, registry, now_epoch)

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


def test_run_focus_finds_an_archived_repository_even_without_all(isolated_env, capsys):
    path = _repository_dir(isolated_env, "delta")
    _write_registry(isolated_env, {"delta": {"path": path, "status": "archived"}})

    exit_code = cli._run("delta", False, "json")  # pylint: disable=protected-access

    assert exit_code == 0
    doc = json.loads(capsys.readouterr().out)
    assert doc["focus"]["name"] == "delta"
    assert "delta" not in doc["order"]
    assert "delta" not in doc["projects"]


def test_main_parses_argv_including_a_dash_leading_repository_and_wraps_a_corrupt_registry(isolated_env, capsys):
    _write_registry(isolated_env, {"delta": {"path": _repository_dir(isolated_env, "delta"), "status": "idle"}})

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


def test_document_explicit_repository_dominates_cwd(isolated_env, monkeypatch):
    # B3 end-to-end, through the real _document rather than the pure resolver: standing in alpha and
    # asking for beta must scope to BETA. Resolving breadth from cwd here would render alpha's facts
    # under beta's header, which is indistinguishable from a right one. `drone link` still passes
    # `${PWD##*/}` from whatever cwd its window is in. (The two examples this used to give --
    # "drone.zsh:964's per-window loop, borg.zsh:266's fzf preview" -- were retired 2026-08-27.)
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
    passing `repository` alone (rather than `repository or scope["repository"]`) renders the IN FOCUS
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
    full board instead of exit 1. `bool(repository) or ...` preserves it.

    The collectors are monkeypatched to RAISE rather than counted: `_focus` sits above them so a
    miss costs nothing, and moving the assignment back below the aggregate block makes an unknown
    tmux window name pay a 14-repository glob before it fails.
    """
    _scope_registry(isolated_env)
    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", str(isolated_env))
    monkeypatch.chdir(isolated_env)

    def _boom(*_args, **_kwargs):
        raise AssertionError("an aggregate collector ran before the RepositoryNotFound raise")

    monkeypatch.setattr(shell, "collect_all_directives", _boom)
    monkeypatch.setattr(shell, "collect_all_assimilated", _boom)

    with pytest.raises(cli.RepositoryNotFound) as exc_info:
        cli._document("ghost", False, "human")  # pylint: disable=protected-access
    assert exc_info.value.repository == "ghost"


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
    dispatcher passes it -- borg.zsh's positional `link` arm, which you find by grepping
    `_link_py_args=(--deep)` -- and deleting the argument makes argparse exit 2 on every
    `borg link <repository>` a human types and on every `drone link`.

    ANCHORED BY THE CODE, NOT BY A LINE NUMBER (2026-08-28). This docstring, cli.py's twin comment
    and two lines of CLAUDE.md all pinned `borg.zsh:3111`, which matched neither main nor the branch
    that last edited them; a pin is invalidated by any insertion above it and nothing fails when it
    goes stale. The same edit dropped "which is the fzf preview's path" -- `cmd_switch`'s `fzf` call
    carries no `--preview` flag, so that justification described a loop that does not exist.

    An earlier version also counted THREE copies, adding bin/link-parity-harness and its byte-copy at
    ~/.claude/bin/. Neither ever passed `--deep` (the harness looped a bare positional), and AC2/S4
    retired the harness leg that looped at all. Corrected, not weakened: the surviving copy is the
    one every reader of this command actually runs, which is the whole reason the flag is kept.

    Mutation: drop the `parser.add_argument("--deep", ...)` line -> SystemExit(2), empty stdout.
    """
    args = cli._build_parser().parse_args(["--deep", "--", "delta"])  # pylint: disable=protected-access
    assert args.deep is True
    assert cli._mode(args) == "human"  # pylint: disable=protected-access

    path = _repository_dir(isolated_env, "delta")
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


def test_focus_of_an_empty_repository_is_none(isolated_env):  # pylint: disable=unused-argument
    """`_focus`'s empty-positional guard became UNREACHABLE from `_document` in AC2: `need_focus` is
    `bool(repository) or scope["kind"] == "repository"`, and both arms guarantee a non-empty name by the
    time `repository or scope["repository"]` is evaluated. It stays because the function must be total
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
    # The visibility filter is `entry.get("status") != "archived"` (core.visible_repositories) -- NOT an
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


def test_json_publishes_a_refused_count_on_the_grid_block(isolated_env, capsys, monkeypatch):
    """The fourth STACKS diagnosis is only as good as the key it reads.

    MUTATION, APPLIED AND CONFIRMED RED: replace the `shell.refused_manifest_paths(...)` stamp in
    `cli._grid` with the literal `0`. Without this case the whole arm survives that mutation --
    `test_render.py` proves the sentence renders when the key is set, and nothing proves anything
    ever sets it. That is the exact shape of a check pointed at the wrong thing.

    THE MANIFEST IS BROKEN ON DISK RATHER THAN THE COUNT BEING INJECTED, because the value under test
    is the round trip: a real file that `discover` refuses, whose warning survives the trip through
    `refused_manifest_paths`, narrowed to the resolved directory. Injecting the number would assert
    that the renderer can read a key this test just wrote.

    A REFUSED MANIFEST PUBLISHES NO NODES, which is what makes `refused` load-bearing: `declared`
    stays 0 and `manifests` stays empty, so nothing else on the block distinguishes "broken" from
    "absent".
    """
    directory = _repository_dir(isolated_env, "warehouse")
    programs = Path(directory) / ".stacks"
    programs.mkdir(parents=True, exist_ok=True)
    # One row, missing `order` -- structurally a manifest, refused whole by `validate`.
    (programs / "broken.json").write_text(json.dumps({"rows": [{"ref": "acme/ledger#1"}]}), encoding="utf-8")
    _write_registry(isolated_env, {"warehouse": {"path": directory, "status": "idle"}})
    monkeypatch.chdir(isolated_env)

    exit_code = cli._run("", False, "json", local=True)  # pylint: disable=protected-access

    assert exit_code == 0
    grid_block = json.loads(capsys.readouterr().out)["grid"]
    assert grid_block["refused"] == 1
    assert grid_block["manifests"] == [], "precondition: a refused manifest publishes no nodes"
    assert any("broken.json" in warning for warning in grid_block["warnings"])


def test_a_registry_of_readable_manifests_publishes_refused_zero(isolated_env, capsys, monkeypatch):
    """The negative half. Without it, a stamp that hardcoded `1` would pass the case above."""
    directory = _manifest_workspace(isolated_env)
    _write_registry(isolated_env, {"warehouse": {"path": directory, "status": "idle"}})
    monkeypatch.chdir(isolated_env)

    assert cli._run("", False, "json", local=True) == 0  # pylint: disable=protected-access
    grid_block = json.loads(capsys.readouterr().out)["grid"]
    assert grid_block["manifests"], "precondition: a manifest did load"
    assert grid_block["refused"] == 0


def test_json_reports_a_stacks_manifest_with_its_stacks_path(isolated_env, capsys, monkeypatch):
    """A manifest in `.stacks/` is on the wire with the REAL file path, not a `.borg/chains` one."""
    directory = _repository_dir(isolated_env, "warehouse")
    stacks = Path(directory) / ".stacks"
    stacks.mkdir()
    shutil.copy(_LINK_FIXTURES / "manifests" / "warehouse-rollout.json", stacks)
    _write_registry(isolated_env, {"warehouse": {"path": directory, "status": "idle"}})
    monkeypatch.chdir(isolated_env)

    assert cli._run("", False, "json", local=True) == 0  # pylint: disable=protected-access
    grid_block = json.loads(capsys.readouterr().out)["grid"]
    assert [m["path"] for m in grid_block["manifests"]] == [str(stacks / "warehouse-rollout.json")]
    assert not (Path(directory) / ".borg").exists()


@pytest.mark.parametrize("directory_name", ["chains", "programs"])
def test_a_manifest_only_under_a_retired_root_renders_nowhere_and_borg_link_names_the_migration(
    isolated_env, capsys, monkeypatch, directory_name
):
    """THE CONTRACT, THROUGH `borg link`. A VALID manifest under `.borg/<directory>` is not read: it is on no node,
    it is not a "refused" file, and the page does not say "no stack manifests in the registry yet" about a
    repository that declares one. It says which repository, and what to run.

    The same shipped fixture that `test_a_registry_of_readable_manifests_publishes_refused_zero` loads from
    `.stacks/` is placed under the retired root here, so the only variable is where it sits.

    MUTATION: restore the `.borg/chains` read in `shell.manifest_roots` and `manifests` is non-empty; drop the
    `unmigrated` stamp in `cli._grid` and the STACKS sentence reverts to the false "in the registry yet" one.
    """
    directory = _repository_dir(isolated_env, "warehouse")
    target = Path(directory) / ".borg" / directory_name
    target.mkdir(parents=True)
    shutil.copy(_LINK_FIXTURES / "manifests" / "warehouse-rollout.json", target)
    _write_registry(isolated_env, {"warehouse": {"path": directory, "status": "idle"}})
    _stand_at_queen(isolated_env, monkeypatch)

    assert cli._run("", False, "json", local=True) == 0  # pylint: disable=protected-access
    grid_block = json.loads(capsys.readouterr().out)["grid"]
    assert grid_block["manifests"] == [] and grid_block["declared"] == 0, "the retired root is not read"
    assert grid_block["refused"] == 0 and grid_block["unmigrated"] == 1
    named = [w for w in grid_block["warnings"] if "borg stack migrate" in w]
    assert len(named) == 1 and directory in named[0] and f".borg/{directory_name}" in named[0]

    assert cli._run("", False, "human", local=True) == 0  # pylint: disable=protected-access
    page = capsys.readouterr().out
    assert "manifests in 1 repository are still under .borg/chains and are no longer read" in page
    assert "in the registry yet" not in page and "to scaffold one" not in page
    signals = page[page.index("SIGNALS") :]
    assert directory in signals and "borg stack migrate" in signals, "SIGNALS names the repository and the cure"


def test_a_registry_with_no_retired_manifest_publishes_unmigrated_zero(isolated_env, capsys, monkeypatch):
    """The negative half: a stamp that hardcoded `1` would pass the case above."""
    directory = _manifest_workspace(isolated_env)
    _write_registry(isolated_env, {"warehouse": {"path": directory, "status": "idle"}})
    monkeypatch.chdir(isolated_env)

    assert cli._run("", False, "json", local=True) == 0  # pylint: disable=protected-access
    grid_block = json.loads(capsys.readouterr().out)["grid"]
    assert grid_block["manifests"] and grid_block["unmigrated"] == 0
    assert not any("borg stack migrate" in w for w in grid_block["warnings"])


def test_the_unmigrated_count_follows_the_scope_it_is_asked_about(isolated_env, capsys, monkeypatch):
    """Warnings are registry-wide; the count is narrowed to the resolved directory, as `refused` is, so a stranded
    manifest in some OTHER repository does not change what this repository's page says about itself.

    MUTATION: drop the `directory` argument in the `unmigrated_repositories` stamp and the repository leg reads 2.
    """
    stranded = _repository_dir(isolated_env, "warehouse")
    other = _repository_dir(isolated_env, "depot")
    for directory in (stranded, other):
        target = Path(directory) / ".borg" / "chains"
        target.mkdir(parents=True)
        shutil.copy(_LINK_FIXTURES / "manifests" / "warehouse-rollout.json", target)
    _write_registry(
        isolated_env,
        {"warehouse": {"path": stranded, "status": "idle"}, "depot": {"path": other, "status": "idle"}},
    )

    _stand_at_queen(isolated_env, monkeypatch)
    assert cli._run("", False, "json", local=True) == 0  # pylint: disable=protected-access
    assert json.loads(capsys.readouterr().out)["grid"]["unmigrated"] == 2

    monkeypatch.chdir(stranded)
    assert cli._run("", False, "json", local=True) == 0  # pylint: disable=protected-access
    assert json.loads(capsys.readouterr().out)["grid"]["unmigrated"] == 1


def test_a_manifest_with_one_bad_row_is_refused_end_to_end_and_named_in_signals(isolated_env, capsys, monkeypatch):
    """AC3 of refuse-the-manifest-stop-salvaging-rows, against a REAL file through the real sweep.

    MUTATION: restore row salvage in `shell._load_manifest` and the file loads (refused == 0, rows on the
    grid) with a "rows dropped" warning, so every assertion here goes red. The refusal must name the path
    and the validator's first error in SIGNALS, and STACKS must say the manifest could not be read rather
    than print an emptiness sentence.
    """
    directory = _repository_dir(isolated_env, "warehouse")
    target = Path(directory) / ".stacks"
    target.mkdir(parents=True)
    bad_row = {"order": "2", "ref": "o/r#2", "status": "stacked", "gate": {"kind": "decision", "blocked_by": "x"}}
    good_row = {"order": "1", "ref": "o/r#1", "status": "stacked"}
    refused_file = target / "broken.json"
    refused_file.write_text(json.dumps({"program": "broken", "rows": [good_row, bad_row]}))
    _write_registry(isolated_env, {"warehouse": {"path": directory, "status": "idle"}})
    _stand_at_queen(isolated_env, monkeypatch)

    assert cli._run("", False, "json", local=True) == 0  # pylint: disable=protected-access
    grid_block = json.loads(capsys.readouterr().out)["grid"]
    assert grid_block["manifests"] == [] and grid_block["refused"] == 1

    assert cli._run("", False, "human", local=True) == 0  # pylint: disable=protected-access
    page = capsys.readouterr().out
    signals = page[page.index("SIGNALS") :]
    assert str(refused_file) in signals, "SIGNALS names the refused file path"
    assert "gate.resolved_by is required" in signals, "and the validator first error"
    assert "1 manifest could not be read" in page, "STACKS shows the fourth diagnosis"
    assert "to scaffold one" not in page and "in the registry yet" not in page
    assert "rows dropped" not in page


# ── WAITING ON YOU shares ONE router with `borg next` ────────────────────────────────────────────


def _open_pr(number: int, **extra) -> dict:
    return {"project": "alpha", "source": "github", "ref": f"o/alpha#{number}", "title": f"feat: change {number}",
            "state": "open", "changed": "2026-10-01T00:00:00Z", **extra}


def test_waiting_rows_and_hidden_counts_match_the_chooser_exactly():
    """Board decision 2026-10-09. MUTATION: build `waiting.rows` from anything but `nextpick_cli.item_rows`
    (or re-run the sweep with different items) and the two lists diverge. The sweep is handed in, so this
    also pins that `borg link` asks `gh` nothing extra."""
    from borg_core.nextpick import cli as nextpick_cli  # pylint: disable=import-outside-toplevel
    from borg_core.recon import core as recon_core  # pylint: disable=import-outside-toplevel

    repositories = {"alpha": {"path": "/nonexistent/alpha", "status": "idle", "last_activity": None, "pinned": False}}
    tracks = [{"source": "github", "ok": True, "items": [_open_pr(n) for n in range(1, 8)]
               + [_open_pr(20, draft=True), _open_pr(21, checks="fail")]}]
    scope = {"kind": "orchestrator", "repository": None, "local": False}

    waiting = cli._waiting(repositories, scope, False, tracks)  # pylint: disable=protected-access
    rows, _quiet, _degraded, hidden = nextpick_cli.item_rows(
        repositories, False, False, swept=(recon_core.merge_by_repository(tracks), None)
    )

    assert [r["ref"] for r in waiting["rows"]] == [r["ref"] for r in rows if r["owner"] == "YOU"]
    assert len(waiting["rows"]) == 5
    assert waiting["hidden"] == hidden and hidden["overflow"] == 2 and hidden["agent"] == 2
    assert waiting["hidden_lines"] == ["+2 more decisions", "+2 agent tasks"]

    page = cli.render.document({"projects": repositories, "grid": {"manifests": []}, "waiting": waiting})
    body = [line for line in page.split("\x1b[1m▸ WAITING ON YOU")[1].split("\n")[1:] if line.strip()]
    assert len(body) == 5 + 2 + 1
    assert "+2 more decisions" in body[-3] and "+2 agent tasks" in body[-2]
    assert "next" in body[-1]
# ── the worktree page (2026-10-13): a directory reads ONLY that directory ───────────────────────────


def _two_worktrees(root):
    """`borg` (a main checkout) and `door` (a linked worktree of it), registered under one `repo` key.

    The git layout is written by hand, exactly as git writes it: the main checkout's `.git` is a directory, the
    worktree's `.git` is a FILE naming `<main>/.git/worktrees/door`, whose `commondir` is `../..` and whose
    `HEAD` is a symbolic ref. `read_git_identity` reads those files, so the fixture needs no `git` on PATH.
    Each directory holds its OWN checkpoint, the main checkout's NEWER by filename -- the shape that made the
    union read leak a sibling's checkpoint onto the worktree's page.
    """
    main = Path(_repository_dir(root, "borg"))
    door = Path(_repository_dir(root, "door"))
    (main / ".git").mkdir()
    (main / ".git" / "HEAD").write_text("ref: refs/heads/main\n", encoding="utf-8")
    gitdir = main / ".git" / "worktrees" / "door"
    gitdir.mkdir(parents=True)
    (gitdir / "commondir").write_text("../..\n", encoding="utf-8")
    (gitdir / "HEAD").write_text("ref: refs/heads/feat-door\n", encoding="utf-8")
    (door / ".git").write_text(f"gitdir: {gitdir}\n", encoding="utf-8")
    for directory, name, summary in (
        (main, "2026-10-13-1200.md", "Main summary."),
        (door, "2026-10-12-0900.md", "Door summary."),
    ):
        store = directory / ".borg" / "checkpoints"
        store.mkdir(parents=True)
        (store / name).write_text(f"**tl;dr** — {summary}\n\n## Next Session\n\nOwn work.\n", encoding="utf-8")
    common = str(Path(os.path.realpath(main / ".git")))
    _write_registry(
        root,
        {
            "borg": {"path": str(main), "repo": common, "status": "idle"},
            "door": {"path": str(door), "repo": common, "status": "active"},
        },
    )
    return main, door


def test_a_worktrees_checkpoints_and_summary_are_its_own_never_a_siblings(isolated_env, monkeypatch):
    """Noah's report from borg-probes, as a test. RED AGAINST THE UNION READ: with `core.repo_sources` in
    `_focus`, `door`'s checkpoint list leads with the main checkout's newer `2026-10-13-1200.md @borg`, its head
    is the main checkout's body, and its summary is `Main summary.`"""
    main, door = _two_worktrees(isolated_env)
    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", str(isolated_env))

    monkeypatch.chdir(door)
    doc = cli._document("", False, "json")  # pylint: disable=protected-access
    assert doc["focus"]["name"] == "door"
    assert doc["focus"]["checkpoints"] == ["2026-10-12-0900.md"]
    assert "Door summary." in doc["focus"]["checkpoint_head"] and "Main summary." not in doc["focus"]["checkpoint_head"]
    assert doc["focus"]["entry"]["summary"] == "Door summary."
    # ...and the board rows the document carries are each their own directory's, not the group's.
    assert doc["projects"]["door"]["summary"] == "Door summary."
    assert doc["projects"]["borg"]["summary"] == "Main summary."

    monkeypatch.chdir(main)
    doc = cli._document("", False, "json")  # pylint: disable=protected-access
    assert doc["focus"]["checkpoints"] == ["2026-10-13-1200.md"]
    assert doc["focus"]["entry"]["summary"] == "Main summary."


def test_focus_states_what_git_says_the_directory_is(isolated_env, monkeypatch):
    main, door = _two_worktrees(isolated_env)
    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", str(isolated_env))

    monkeypatch.chdir(door)
    assert cli._document("", False, "json")["focus"]["identity"] == {  # pylint: disable=protected-access
        "kind": "worktree",
        "branch": "feat-door",
        "worktree_of": "borg",
    }
    monkeypatch.chdir(main)
    assert cli._document("", False, "json")["focus"]["identity"] == {  # pylint: disable=protected-access
        "kind": "checkout",
        "branch": "main",
        "worktree_of": "",
    }


def test_the_human_page_in_a_worktree_is_strictly_that_worktree(isolated_env, monkeypatch, capsys):
    _main, door = _two_worktrees(isolated_env)
    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", str(isolated_env))
    monkeypatch.chdir(door)

    assert cli._run("", False, "human", local=True) == 0  # pylint: disable=protected-access
    out = capsys.readouterr().out
    assert "IN FOCUS" in out and "door — worktree of borg" in out
    assert "Door summary." in out and "2026-10-12-0900.md" in out
    assert "Main summary." not in out and "2026-10-13-1200.md" not in out
    assert "REPOSITORIES" not in out and "THE BORG COLLECTIVE" not in out
    assert "borg link --overview" in out


def test_overview_forces_the_queen_view_from_a_worktree(isolated_env, monkeypatch, capsys):
    """MUTATION: drop `overview=overview` from the `scope_for` call and the worktree keeps its own page."""
    _main, door = _two_worktrees(isolated_env)
    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", str(isolated_env))
    monkeypatch.chdir(door)

    doc = cli._document("", False, "json", True, True)  # pylint: disable=protected-access
    assert doc["scope"] == {"kind": "orchestrator", "repository": None, "local": True}
    assert doc["focus"] is None
    # ...a positional is not honoured against the flag: the request for the whole collective wins.
    ignored = cli._document("door", False, "json", True, True)  # pylint: disable=protected-access
    assert ignored["scope"]["kind"] == "orchestrator" and ignored["focus"] is None

    assert cli._run("", False, "human", local=True, overview=True) == 0  # pylint: disable=protected-access
    out = capsys.readouterr().out
    assert "REPOSITORIES" in out and "THE BORG COLLECTIVE" in out
    assert "worktree of" not in out


def test_overview_parses_and_defaults_off():
    assert cli._build_parser().parse_args([]).overview is False  # pylint: disable=protected-access
    assert cli._build_parser().parse_args(["--overview"]).overview is True  # pylint: disable=protected-access


def test_json_keeps_every_key_the_directory_page_stopped_rendering(isolated_env, monkeypatch):
    """Decision 5: the human page narrows, the wire does not. Registry-wide keys are present and unchanged in
    repository scope, and the only key ADDED is `focus.identity` (additive, so DOCUMENT_VERSION stays 2)."""
    _main, door = _two_worktrees(isolated_env)
    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", str(isolated_env))

    monkeypatch.chdir(door)
    inside = cli._document("", False, "json")  # pylint: disable=protected-access
    monkeypatch.chdir(isolated_env)
    queen = cli._document("", False, "json")  # pylint: disable=protected-access

    assert set(inside) == set(queen)
    assert inside["version"] == queen["version"] == 2
    for registry_wide in ("order", "projects", "directives", "assimilated", "capacity", "grid"):
        assert registry_wide in inside
    assert inside["order"] == queen["order"]
    assert set(inside["focus"]) == {
        "name",
        "entry",
        "identity",
        "plan",
        "checkpoints",
        "checkpoint_head",
        "directives",
        "assimilated",
    }


# ── NO_COLOR (https://no-color.org) ───────────────────────────────────────────────────────────────


@pytest.mark.parametrize(
    ("environ", "expected"),
    [
        ({}, True),
        ({"NO_COLOR": ""}, True),
        ({"NO_COLOR": "1"}, False),
        ({"NO_COLOR": "0"}, False),
        ({"NO_COLOR": "anything"}, False),
        ({"TERM": "xterm"}, True),
    ],
)
def test_color_is_off_only_for_a_non_empty_no_color(environ, expected):
    assert cli._color_enabled(environ) is expected  # pylint: disable=protected-access


def _page_with_a_picture(isolated_env, monkeypatch):
    """A registered repository holding the shipped manifest, so the page carries SGR AND OSC-8 bytes."""
    directory = _manifest_workspace(isolated_env)
    _write_registry(isolated_env, {"warehouse": {"path": directory, "status": "idle"}})
    monkeypatch.chdir(isolated_env)
    monkeypatch.setattr(shell, "now_epoch", lambda: 1_800_000_000)


def _main_stdout(argv, capsys):
    with pytest.raises(SystemExit) as exc_info:
        cli.main(argv)
    assert exc_info.value.code == 0
    return capsys.readouterr().out


def test_no_color_strips_every_escape_from_the_human_page_and_empty_keeps_colour(isolated_env, capsys, monkeypatch):
    """The page is built coloured and stripped once at the boundary; the strip must find every site.

    THE CONTROL IS THE FIRST HALF. With NO_COLOR unset the same invocation must contain both an SGR and an
    OSC-8 sequence, or "no ESC byte" below would hold of a page that never had one. MUTATION: make `_page`
    return its text unchanged and the NO_COLOR=1 half goes red. The stripped page is also asserted to be the
    coloured page minus its escapes, so a column that shifted (padding computed on the wrong length) fails.
    """
    _page_with_a_picture(isolated_env, monkeypatch)
    argv = ["--local", "--overview"]

    coloured = _main_stdout(argv, capsys)
    assert "\033[" in coloured and "\033]8;;" in coloured, "the control page carries no colour to remove"

    monkeypatch.setenv("NO_COLOR", "")
    assert _main_stdout(argv, capsys) == coloured, "an EMPTY NO_COLOR is unset, per no-color.org"

    monkeypatch.setenv("NO_COLOR", "1")
    plain = _main_stdout(argv, capsys)
    assert "\033" not in plain
    assert plain == picture.plain(coloured)
    assert "warehouse" in plain and "REPOSITORIES" in plain, "stripping must not eat the page"


def test_no_color_leaves_json_and_porcelain_byte_identical(isolated_env, capsys, monkeypatch):
    _page_with_a_picture(isolated_env, monkeypatch)
    for flag in ("--json", "--porcelain"):
        argv = [flag, "--local", "--overview"]
        unset = _main_stdout(argv, capsys)
        monkeypatch.setenv("NO_COLOR", "1")
        assert _main_stdout(argv, capsys) == unset, f"NO_COLOR changed {flag}"
        monkeypatch.delenv("NO_COLOR")
        assert unset, f"{flag} printed nothing; the comparison above is vacuous"


def test_no_color_applies_to_the_render_document_fallback_too(isolated_env, capsys, monkeypatch):
    """`--render-document` (the `--brief` fallback) is the second human arm; it must honour the flag."""
    _page_with_a_picture(isolated_env, monkeypatch)
    document = _main_stdout(["--json", "--local", "--overview"], capsys)
    monkeypatch.setattr(sys, "stdin", io.StringIO(document))
    assert "\033[" in _main_stdout(["--render-document"], capsys)

    monkeypatch.setenv("NO_COLOR", "1")
    monkeypatch.setattr(sys, "stdin", io.StringIO(document))
    assert "\033" not in _main_stdout(["--render-document"], capsys)


def test_no_color_strips_the_error_line_but_json_errors_never_had_colour(isolated_env, capsys, monkeypatch):
    _write_registry(isolated_env, {})
    monkeypatch.setenv("NO_COLOR", "1")

    with pytest.raises(SystemExit):
        cli.main(["--deep", "--", "nope"])
    err = capsys.readouterr().err
    assert err == "▸ ERROR: repository 'nope' not in registry. Run: borg add [path]\n"
    assert "\033" not in err
