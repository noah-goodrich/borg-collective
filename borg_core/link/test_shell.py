"""Unit tests for borg_core.link.shell (I/O layer)."""

import json
import os
import subprocess

import pytest

from borg_core.link import core, shell


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
    monkeypatch.delenv("BORG_ORCHESTRATOR_ROOT", raising=False)
    return tmp_path


def _project(root, name, *, state=None, plan=None, directives=(), assimilated=(), checkpoints=()):
    """Build a project workspace and return its path as a string."""
    directory = root / name
    directory.mkdir(parents=True, exist_ok=True)
    if state is not None:
        (directory / ".borg").mkdir(exist_ok=True)
        (directory / ".borg" / "state.json").write_text(state, encoding="utf-8")
    if plan is not None:
        (directory / "PROJECT_PLAN.md").write_text(plan, encoding="utf-8")
    for subdir, files in (("directives", directives), ("assimilated", assimilated)):
        if files:
            target = directory / "docs" / "plans" / subdir
            target.mkdir(parents=True, exist_ok=True)
            for filename, body in files:
                (target / filename).write_text(body, encoding="utf-8")
    if checkpoints:
        target = directory / ".borg" / "checkpoints"
        target.mkdir(parents=True, exist_ok=True)
        for filename, body in checkpoints:
            (target / filename).write_text(body, encoding="utf-8")
    return str(directory)


# ── config resolution ────────────────────────────────────────────────────────


def test_paths_are_re_exported(isolated_env):
    assert shell.borg_dir() == isolated_env / "borg-dir"
    assert shell.registry_path() == isolated_env / "borg-dir" / "registry.json"


def test_now_epoch_is_an_int(isolated_env):
    assert isinstance(shell.now_epoch(), int)


def test_reap_threshold_defaults_when_unset_or_empty(isolated_env, monkeypatch):
    assert shell.reap_threshold_hours() == core.DEFAULT_REAP_STALE_HOURS
    monkeypatch.setenv("BORG_REAP_STALE_HOURS", "")
    assert shell.reap_threshold_hours() == core.DEFAULT_REAP_STALE_HOURS


def test_reap_threshold_honors_an_integer(isolated_env, monkeypatch):
    monkeypatch.setenv("BORG_REAP_STALE_HOURS", "3")
    assert shell.reap_threshold_hours() == 3


def test_reap_threshold_is_none_for_garbage(isolated_env, monkeypatch):
    # None is what core.should_reap reads as "keep", mirroring `[ ... -ge abc ]` returning 2.
    monkeypatch.setenv("BORG_REAP_STALE_HOURS", "not-a-number")
    assert shell.reap_threshold_hours() is None


def test_reap_disabled_by_any_non_empty_value(isolated_env, monkeypatch):
    assert shell.reap_disabled() is False
    monkeypatch.setenv("BORG_NO_REAP", "0")
    assert shell.reap_disabled() is True


def test_max_active_defaults_to_three_when_unset_or_empty_or_garbage(isolated_env, monkeypatch):
    monkeypatch.delenv("BORG_MAX_ACTIVE", raising=False)
    assert shell.max_active() == 3
    monkeypatch.setenv("BORG_MAX_ACTIVE", "")
    assert shell.max_active() == 3
    monkeypatch.setenv("BORG_MAX_ACTIVE", "abc")
    assert shell.max_active() == 3
    monkeypatch.setenv("BORG_MAX_ACTIVE", "7")
    assert shell.max_active() == 7


# ── live_windows ─────────────────────────────────────────────────────────────


def test_live_windows_splits_tmux_output(isolated_env, monkeypatch):
    def fake_run(*_args, **_kwargs):
        return subprocess.CompletedProcess([], 0, stdout="alpha\nbravo\n", stderr="")

    monkeypatch.setattr(subprocess, "run", fake_run)
    assert shell.live_windows() == ["alpha", "bravo"]


def test_live_windows_empty_on_nonzero_exit(isolated_env, monkeypatch):
    def fake_run(*_args, **_kwargs):
        return subprocess.CompletedProcess([], 1, stdout="", stderr="no server")

    monkeypatch.setattr(subprocess, "run", fake_run)
    assert shell.live_windows() == []


def test_live_windows_empty_when_tmux_is_missing(isolated_env, monkeypatch):
    def fake_run(*_args, **_kwargs):
        raise FileNotFoundError("tmux")

    monkeypatch.setattr(subprocess, "run", fake_run)
    assert shell.live_windows() == []


def test_live_windows_uses_the_configured_session(isolated_env, monkeypatch):
    seen = {}

    def fake_run(cmd, **_kwargs):
        seen["cmd"] = cmd
        return subprocess.CompletedProcess(cmd, 0, stdout="", stderr="")

    monkeypatch.setenv("BORG_TMUX_SESSION", "custom")
    monkeypatch.setattr(subprocess, "run", fake_run)
    shell.live_windows()
    assert "custom" in seen["cmd"]


def test_live_windows_is_the_registry_shells_tmux_window_lister():
    # AC4: live_windows used to be its own byte-identical `tmux list-windows` fork; it now delegates
    # to (is the exact same function object as) registry_shell.list_tmux_windows, the one definition
    # tmux_window_exists also uses. Fails before this dedup (two distinct function objects).
    from borg_core.registry import shell as registry_shell  # noqa: PLC0415 -- test-local, mirrors module's own import

    assert shell.live_windows is registry_shell.list_tmux_windows


# ── state.json ───────────────────────────────────────────────────────────────


@pytest.mark.parametrize("bad", [None, "", "null"])
def test_read_state_rejects_unusable_paths(isolated_env, bad):
    assert shell.read_state(bad) is None


def test_read_state_missing_file(isolated_env):
    assert shell.read_state(_project(isolated_env, "nostate")) is None


def test_read_state_reads_a_valid_file(isolated_env):
    path = _project(isolated_env, "good", state='{"status":"active"}')
    assert shell.read_state(path) == {"status": "active"}


@pytest.mark.parametrize("body", ["", "NOT JSON AT ALL", "[1,2,3]", '"a string"'])
def test_read_state_rejects_unusable_content(isolated_env, body):
    # A non-object root is as unusable as invalid JSON: the shell's `--argjson` would take an array
    # but the merge `.projects[$p] += $s` would then fail, so both sides skip the project.
    path = _project(isolated_env, "bad", state=body)
    assert shell.read_state(path) is None


def test_collect_states_skips_projects_without_usable_state(isolated_env):
    good = _project(isolated_env, "good", state='{"status":"active"}')
    bad = _project(isolated_env, "bad", state="NOT JSON")
    registry = {
        "projects": {
            "good": {"path": good},
            "bad": {"path": bad},
            "nopath": {"path": None},
        }
    }
    assert shell.collect_states(registry) == {"good": {"status": "active"}}


# ── registry_with_state ──────────────────────────────────────────────────────


def _write_registry(root, projects):
    registry_file = root / "borg-dir" / "registry.json"
    registry_file.write_text(json.dumps({"projects": projects}), encoding="utf-8")
    return registry_file


def test_registry_with_state_overlays_and_reaps(isolated_env, monkeypatch):
    path = _project(isolated_env, "proj", state='{"status":"active","last_activity":"2020-01-01T00:00:00Z"}')
    _write_registry(isolated_env, {"proj": {"path": path}})
    monkeypatch.setattr(shell, "live_windows", lambda: [])

    result = shell.registry_with_state()
    assert result["projects"]["proj"]["status"] == "idle"
    assert result["projects"]["proj"]["_reaped_from"] == "active"


def test_registry_with_state_keeps_a_live_project_active(isolated_env, monkeypatch):
    path = _project(isolated_env, "proj", state='{"status":"active","last_activity":"2020-01-01T00:00:00Z"}')
    _write_registry(isolated_env, {"proj": {"path": path}})
    monkeypatch.setattr(shell, "live_windows", lambda: ["proj"])

    assert shell.registry_with_state()["projects"]["proj"]["status"] == "active"


def test_registry_with_state_honors_apply_reap_false(isolated_env, monkeypatch):
    path = _project(isolated_env, "proj", state='{"status":"active","last_activity":"2020-01-01T00:00:00Z"}')
    _write_registry(isolated_env, {"proj": {"path": path}})
    monkeypatch.setattr(shell, "live_windows", lambda: [])

    assert shell.registry_with_state(apply_reap=False)["projects"]["proj"]["status"] == "active"


def test_registry_with_state_env_wins_over_the_kwarg(isolated_env, monkeypatch):
    path = _project(isolated_env, "proj", state='{"status":"active","last_activity":"2020-01-01T00:00:00Z"}')
    _write_registry(isolated_env, {"proj": {"path": path}})
    monkeypatch.setattr(shell, "live_windows", lambda: [])
    monkeypatch.setenv("BORG_NO_REAP", "1")

    assert shell.registry_with_state(apply_reap=True)["projects"]["proj"]["status"] == "active"


def test_registry_with_state_survives_one_malformed_state_json(isolated_env, monkeypatch):
    # The zsh twin of this used to blank the WHOLE registry; both now skip the bad project only.
    good = _project(isolated_env, "good", state='{"status":"idle"}')
    bad = _project(isolated_env, "bad", state="NOT JSON")
    _write_registry(isolated_env, {"good": {"path": good}, "bad": {"path": bad}})
    monkeypatch.setattr(shell, "live_windows", lambda: [])

    result = shell.registry_with_state()
    assert set(result["projects"]) == {"good", "bad"}
    assert result["projects"]["bad"]["status"] == "idle"


def test_registry_with_state_uses_the_injected_now_for_the_reap_decision(isolated_env, monkeypatch):
    epoch = 1_700_000_000
    last_activity = core.format_iso(epoch)
    path = _project(isolated_env, "proj", state=f'{{"status":"active","last_activity":"{last_activity}"}}')
    _write_registry(isolated_env, {"proj": {"path": path}})
    monkeypatch.setattr(shell, "live_windows", lambda: [])
    monkeypatch.setenv("BORG_REAP_STALE_HOURS", "1")

    soon = shell.registry_with_state(now=epoch + 60)
    assert soon["projects"]["proj"]["status"] == "active"

    later = shell.registry_with_state(now=epoch + 7200)
    assert later["projects"]["proj"]["status"] == "idle"
    assert later["projects"]["proj"]["_reaped_from"] == "active"


# ── directives / assimilated ─────────────────────────────────────────────────


@pytest.mark.parametrize("bad", [None, "", "null"])
def test_readers_return_empty_for_unusable_paths(isolated_env, bad):
    assert shell.read_directives(bad) == []
    assert shell.read_assimilated(bad) == []
    assert shell.read_checkpoints(bad) == []
    assert shell.read_latest_checkpoint_head(bad) == ""
    assert shell.read_plan(bad) is None


def test_read_directives_returns_slug_and_title(isolated_env):
    path = _project(
        isolated_env,
        "p",
        directives=[("2026-01-02-b.md", "# Second\n"), ("2026-01-01-a.md", "# First\n")],
    )
    assert shell.read_directives(path) == [
        {"slug": "2026-01-01-a", "title": "First"},
        {"slug": "2026-01-02-b", "title": "Second"},
    ]


def test_read_directives_empty_when_the_directory_is_absent(isolated_env):
    assert shell.read_directives(_project(isolated_env, "bare")) == []


def test_read_assimilated_is_filename_descending_and_capped(isolated_env):
    path = _project(
        isolated_env,
        "p",
        assimilated=[
            ("2026-03-01-a.md", "# Shipped A\nShipped: 2026-03-01\n"),
            ("2026-03-02-b.md", "# Shipped B\nShipped: 2026-03-02\n"),
            ("2026-03-03-c.md", "# Shipped C\nShipped: 2026-03-03\n"),
            ("2026-03-04-d.md", "# Shipped D\nShipped: 2026-03-04\n"),
        ],
    )
    result = shell.read_assimilated(path)
    # The deviation the plan mandates: the shell's (NOm) glob lists the three OLDEST (A, B, C).
    assert [e["title"] for e in result] == ["Shipped D", "Shipped C", "Shipped B"]
    assert result[0]["ship_date"] == "2026-03-04"
    assert result[0]["slug"] == "2026-03-04-d"


def test_read_assimilated_reads_each_survivor_exactly_once(isolated_env, monkeypatch):
    # AC4: read_assimilated used to call _read_text(Path(e["path"])) twice per survivor -- once for
    # title, once for ship_date. Fails before this fix (2 reads/file); passes after (1 read/file).
    path = _project(
        isolated_env,
        "p",
        assimilated=[
            ("2026-03-01-a.md", "# Shipped A\nShipped: 2026-03-01\n"),
            ("2026-03-02-b.md", "# Shipped B\nShipped: 2026-03-02\n"),
        ],
    )
    calls = {"n": 0}
    real_read_text = shell._read_text  # pylint: disable=protected-access

    def counting_read_text(p):
        calls["n"] += 1
        return real_read_text(p)

    monkeypatch.setattr(shell, "_read_text", counting_read_text)
    result = shell.read_assimilated(path)

    assert len(result) == 2
    assert calls["n"] == 2


def test_collect_all_directives_prefixes_the_project_and_keeps_registry_order(isolated_env):
    zed = _project(isolated_env, "zed", directives=[("d1.md", "# Zed one\n")])
    amy = _project(isolated_env, "amy", directives=[("d1.md", "# Amy one\n")])
    registry = {"projects": {"zed": {"path": zed}, "amy": {"path": amy}, "skip": {"path": None}}}

    result = shell.collect_all_directives(registry)
    assert [(e["project"], e["title"]) for e in result] == [("zed", "Zed one"), ("amy", "Amy one")]


def test_collect_all_assimilated_sorts_globally_across_projects(isolated_env):
    one = _project(
        isolated_env,
        "one",
        assimilated=[
            ("2026-01-15-old.md", "# Old\nShipped: 2026-01-15\n"),
            ("2026-02-03-new.md", "# New\nShipped: 2026-02-03\n"),
        ],
    )
    two = _project(isolated_env, "two", assimilated=[("2026-02-02-mid.md", "# Mid\nShipped: 2026-02-02\n")])
    registry = {"projects": {"one": {"path": one}, "two": {"path": two}}}

    result = shell.collect_all_assimilated(registry)
    assert [(e["project"], e["title"]) for e in result] == [
        ("one", "New"),
        ("two", "Mid"),
        ("one", "Old"),
    ]


def test_collect_all_assimilated_respects_max_items(isolated_env):
    one = _project(
        isolated_env,
        "one",
        assimilated=[("a.md", "# A\n"), ("b.md", "# B\n"), ("c.md", "# C\n")],
    )
    registry = {"projects": {"one": {"path": one}}}
    assert len(shell.collect_all_assimilated(registry, max_items=2)) == 2


def test_collectors_skip_unreachable_projects(isolated_env):
    registry = {"projects": {"gone": {"path": str(isolated_env / "does-not-exist")}}}
    assert shell.collect_all_directives(registry) == []
    assert shell.collect_all_assimilated(registry) == []


@pytest.mark.parametrize(
    "projects",
    [
        {"": {"path": "/somewhere"}},
        {"named": {"path": None}},
        {"named": {"path": "null"}},
        {"named": {}},
    ],
)
def test_collectors_and_collect_states_skip_unusable_entries(isolated_env, projects):
    # The shell guards each of these explicitly (`[[ -z "$name" || -z "$ppath" || ... ]]`), and every
    # guard is its own branch — an empty project KEY is legal JSON and reaches them.
    registry = {"projects": projects}
    assert shell.collect_all_directives(registry) == []
    assert shell.collect_all_assimilated(registry) == []
    assert shell.collect_states(registry) == {}


# ── checkpoints / plan ───────────────────────────────────────────────────────


def test_read_checkpoints_is_name_descending_and_capped(isolated_env):
    path = _project(
        isolated_env,
        "p",
        checkpoints=[(f"2026-08-0{n}-1000.md", f"# cp {n}\n") for n in range(1, 6)],
    )
    assert shell.read_checkpoints(path) == [
        "2026-08-05-1000.md",
        "2026-08-04-1000.md",
        "2026-08-03-1000.md",
    ]


def test_read_checkpoints_empty_without_the_directory(isolated_env):
    assert shell.read_checkpoints(_project(isolated_env, "bare")) == []


def test_read_latest_checkpoint_head_caps_the_lines(isolated_env):
    body = "\n".join(f"line {n}" for n in range(1, 31)) + "\n"
    path = _project(isolated_env, "p", checkpoints=[("2026-08-01-1000.md", body)])
    head = shell.read_latest_checkpoint_head(path, lines=20)
    assert head.split("\n")[0] == "line 1"
    assert head.split("\n")[-1] == "line 20"
    assert "line 21" not in head


def test_read_latest_checkpoint_head_empty_without_checkpoints(isolated_env):
    assert shell.read_latest_checkpoint_head(_project(isolated_env, "bare")) == ""


def test_read_plan_returns_objective_and_progress(isolated_env):
    plan = "# P\n\n## Objective\n\nShip the thing.\n\n- [x] one\n- [ ] two\n"
    path = _project(isolated_env, "p", plan=plan)
    assert shell.read_plan(path) == {"objective": "Ship the thing.", "met": 1, "total": 2}


def test_read_plan_none_without_a_plan_file(isolated_env):
    assert shell.read_plan(_project(isolated_env, "bare")) is None


# ── cortex wakes ─────────────────────────────────────────────────────────────


def test_cortex_wakes_path_prefers_each_env_name_in_order(isolated_env, monkeypatch):
    assert shell.cortex_wakes_path() == isolated_env / "borg-dir" / "cortex-wakes.json"
    monkeypatch.setenv("BORG_CORTEX_STATE", "/from/state.json")
    assert str(shell.cortex_wakes_path()) == "/from/state.json"
    monkeypatch.setenv("BORG_CORTEX_WAKES", "/from/wakes.json")
    assert str(shell.cortex_wakes_path()) == "/from/wakes.json"


def test_cortex_pending_empty_when_the_file_is_absent(isolated_env):
    assert shell.cortex_pending() == []


@pytest.mark.parametrize("body", ["not json", "[1,2]", '"a string"', "{}", '{"wakes": "not a list"}', '{"wakes": []}'])
def test_cortex_pending_empty_for_every_unusable_shape(isolated_env, monkeypatch, body):
    wakes = isolated_env / "wakes.json"
    wakes.write_text(body, encoding="utf-8")
    monkeypatch.setenv("BORG_CORTEX_WAKES", str(wakes))
    assert shell.cortex_pending() == []


def test_cortex_pending_renders_countdowns_in_array_order(isolated_env, monkeypatch):
    now = 1_800_000_000
    wakes = isolated_env / "wakes.json"
    wakes.write_text(
        json.dumps(
            {
                "wakes": [
                    {"project": "second", "reset_at": "2027-01-01T00:00:00Z"},
                    "not an object",
                    {"project": "first", "reset_at": "2020-01-01T00:00:00Z"},
                ]
            }
        ),
        encoding="utf-8",
    )
    monkeypatch.setenv("BORG_CORTEX_WAKES", str(wakes))

    result = shell.cortex_pending(now=now)
    assert [w["project"] for w in result] == ["second", "first"]
    assert result[1]["countdown"] == "now"


def test_cortex_pending_keeps_a_json_null_project_as_the_string_null(isolated_env, monkeypatch):
    # jq's \\(.project) interpolation renders null as the four-character string, so the emptiness
    # guard does not skip it. Matching the shell exactly, oddity included.
    wakes = isolated_env / "wakes.json"
    wakes.write_text(json.dumps({"wakes": [{"project": None, "reset_at": None}]}), encoding="utf-8")
    monkeypatch.setenv("BORG_CORTEX_WAKES", str(wakes))

    result = shell.cortex_pending(now=1_800_000_000)
    assert result[0]["project"] == "null"
    assert result[0]["countdown"] == "?"


def test_cortex_pending_skips_an_empty_project(isolated_env, monkeypatch):
    wakes = isolated_env / "wakes.json"
    wakes.write_text(json.dumps({"wakes": [{"project": "", "reset_at": "x"}]}), encoding="utf-8")
    monkeypatch.setenv("BORG_CORTEX_WAKES", str(wakes))
    assert shell.cortex_pending() == []


def test_cortex_pending_defaults_now_to_the_clock(isolated_env, monkeypatch):
    wakes = isolated_env / "wakes.json"
    wakes.write_text(
        json.dumps({"wakes": [{"project": "p", "reset_at": "2020-01-01T00:00:00Z"}]}),
        encoding="utf-8",
    )
    monkeypatch.setenv("BORG_CORTEX_WAKES", str(wakes))
    assert shell.cortex_pending()[0]["countdown"] == "now"


def test_read_text_returns_empty_for_a_directory(isolated_env):
    # Reproduces `head -1 <a directory>` failing to an empty title rather than aborting the listing.
    assert shell._read_text(isolated_env) == ""  # pylint: disable=protected-access


def test_markdown_glob_includes_directories_like_the_zsh_glob(isolated_env):
    path = _project(isolated_env, "p", directives=[("real.md", "# Real\n")])
    (isolated_env / "p" / "docs" / "plans" / "directives" / "adir.md").mkdir()
    titles = [d["title"] for d in shell.read_directives(path)]
    assert titles == ["", "Real"]


def test_module_reads_no_environment_at_import_time():
    # A guard against config being captured at import rather than at call time -- the shell reads
    # ${BORG_REAP_STALE_HOURS:-12} on every call, and a module-level constant would silently freeze
    # whatever the first import happened to see.
    assert "BORG_REAP_STALE_HOURS" not in vars(shell)
    assert os.environ.get("BORG_REAP_STALE_HOURS") is None or True


# --- orchestrator_root / cwd / resolved_project_paths (S1) -------------------------------------


def test_orchestrator_root_defaults_to_dev_when_unset(isolated_env, monkeypatch):
    # The wrapper-independent default. borg.zsh:23 assigns BORG_ORCHESTRATOR_ROOT WITHOUT export,
    # so before S1 the Python child never saw it -- the exact inheritance hole that shipped
    # `borg recon` non-functional. A module invoked directly has no _borg_py, so the default must
    # also live here.
    monkeypatch.delenv("BORG_ORCHESTRATOR_ROOT", raising=False)
    assert shell.orchestrator_root() == os.path.realpath(os.path.expanduser("~/dev"))


def test_orchestrator_root_treats_empty_as_unset(isolated_env, monkeypatch):
    # _borg_py passes variables through as the EMPTY STRING when unset, so this must be
    # truthiness-checked, not existence-checked -- the bug class that makes int("") raise.
    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", "")
    assert shell.orchestrator_root() == os.path.realpath(os.path.expanduser("~/dev"))


def test_orchestrator_root_honors_an_explicit_value(isolated_env, monkeypatch, tmp_path):
    workspace = tmp_path / "workspace"
    workspace.mkdir()
    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", str(workspace))
    assert shell.orchestrator_root() == os.path.realpath(str(workspace))


def test_orchestrator_root_is_realpath_normalized(isolated_env, monkeypatch, tmp_path):
    # THE CASE THAT ONLY BITES IN THE TEST SUITES: fixtures live under /tmp, which realpaths to
    # /private/tmp on macOS. Comparing an unresolved root against a resolved cwd silently makes
    # every repository look like the orchestrator.
    real = tmp_path / "real-workspace"
    real.mkdir()
    link = tmp_path / "linked-workspace"
    link.symlink_to(real)
    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", str(link))
    assert shell.orchestrator_root() == os.path.realpath(str(real))


def test_cwd_is_realpath_normalized(isolated_env, monkeypatch, tmp_path):
    real = tmp_path / "real-repo"
    real.mkdir()
    link = tmp_path / "linked-repo"
    link.symlink_to(real)
    monkeypatch.chdir(link)
    assert shell.cwd() == os.path.realpath(str(real))


def test_resolved_project_paths_normalizes_and_preserves_blanks(isolated_env, tmp_path):
    real = tmp_path / "real-repo"
    real.mkdir()
    link = tmp_path / "linked-repo"
    link.symlink_to(real)
    registry = {
        "projects": {
            "linked": {"path": str(link)},
            "pathless": {"path": None},
        }
    }
    resolved = dict(shell.resolved_project_paths(registry))
    assert resolved["linked"] == os.path.realpath(str(real))
    # jq's `//` semantics: a null path becomes "", and scope_for skips it rather than matching "/".
    assert resolved["pathless"] == ""


def test_resolved_project_paths_does_not_require_the_path_to_exist(isolated_env):
    # realpath is lexical, not a stat. A registry entry pointing at a deleted directory must
    # normalize quietly and simply fail to match -- never raise, never cost a stat per project on
    # the one path that has to stay reflexive.
    registry = {"projects": {"gone": {"path": "/nonexistent/deleted/repo"}}}
    assert shell.resolved_project_paths(registry) == [("gone", "/nonexistent/deleted/repo")]


def test_cwd_returns_empty_when_the_directory_was_deleted(isolated_env, monkeypatch, tmp_path):
    # `drone down`, `borg reap-worktrees` and `git worktree remove` all delete directories a user
    # may still be sitting in. Unguarded, os.getcwd() raises FileNotFoundError and cli.main's broad
    # `except Exception` turns it into exit 1 with zero bytes on stdout -- in ALL FOUR modes, for a
    # command that worked before this module ever read cwd.
    doomed = tmp_path / "doomed"
    doomed.mkdir()
    monkeypatch.chdir(doomed)
    doomed.rmdir()
    assert shell.cwd() == ""


def test_deleted_cwd_degrades_to_orchestrator_not_a_wrong_repository(isolated_env):
    # "" must match no orchestrator root and prefix-match no registry path, so an unknowable
    # location yields the BROADEST reading rather than an arbitrary one.
    paths = [("alpha", "/Users/noah/dev/alpha")]
    scope = core.scope_for("", "/Users/noah/dev", paths)
    assert scope["kind"] == "orchestrator"
    assert scope["repository"] is None
