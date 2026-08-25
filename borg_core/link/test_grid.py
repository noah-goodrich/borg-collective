"""Tests for S3's sweep fold: the `grid` key, the resolve ladder, and the opt-down.

Calling convention: in-process only (cli._document, grid.*), against real directories under
`tmp_path`, real `git` repositories, and REAL adapter executables written to a real adapter search
path. Never a mocked fan-out.

THE ONE RULE THIS FILE EXISTS TO OBEY, inherited verbatim from borg_core/manifest/test_shell.py: a
test that supplies the value production is supposed to DERIVE proves nothing. This repository has
shipped that bug three times (CLAUDE.md's "Learned": `borg recon` shipped completely dead, the
usage-watch sweep, the memory gate), and each time the suite was green. So:

  * the B6 regression BUILDS A REGISTRY and lets `discover_registered` derive the paths from it --
    handing `_document` a manifest list would move the derivation into the test and leave the
    registry-reading line production actually runs as the one line no test executes;
  * repository scope is derived from a REAL cwd inside a REAL git checkout with a REAL origin remote,
    never by writing `scope` into a document;
  * "no subprocess" is asserted by RECORDING what borg_core actually forks (`record_forks`), not by
    asserting that a mock was not called;
  * every no-sweep assertion is PAIRED with a control proving the sweep does happen without the
    opt-down. An un-paired "zero subprocesses" assertion passes just as well when the adapter search
    path is empty for an unrelated reason, which is exactly the state tests/test_helper/setup.bash
    now puts every bats case in.
"""

import json
import subprocess
import time
from pathlib import Path

import pytest

from borg_core import proc
from borg_core.link import cli, core
from borg_core.link import grid as link_grid

# ── fixtures ──────────────────────────────────────────────────────────────────────────────────────


@pytest.fixture()
def isolated(tmp_path, monkeypatch):
    """A borg config home, an EMPTY adapter search path, and no inherited BORG_* configuration.

    BORG_RECON_ADAPTER_PATH is neutralized to a real, existing, EMPTY DIRECTORY and not to "".
    recon.shell.adapter_search_path branches on `if override:`, so an exported-empty value is falsy
    and falls straight back to `<repo>/lib/recon/adapters` -- which on a developer's machine holds a
    working `recon-adapter-github`, so the "neutralized" suite would shell out to `gh`. Tests that
    want an adapter point this variable at a directory they populate themselves.
    """
    borg_dir = tmp_path / "borg-dir"
    borg_dir.mkdir()
    empty_adapters = tmp_path / "no-adapters"
    empty_adapters.mkdir()
    monkeypatch.setenv("BORG_DIR", str(borg_dir))
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", str(empty_adapters))
    for name in (
        "XDG_CONFIG_HOME",
        "BORG_REGISTRY",
        "BORG_REAP_STALE_HOURS",
        "BORG_NO_REAP",
        "BORG_CORTEX_WAKES",
        "BORG_CORTEX_STATE",
        "BORG_TMUX_SESSION",
        "BORG_MAX_ACTIVE",
        "BORG_ORCHESTRATOR_ROOT",
        "BORG_RECON_LIB_DIR",
        "BORG_RECON_MAX_TRACKS",
        "BORG_RECON_TRACK_TIMEOUT",
        "BORG_LINK_SWEEP_TIMEOUT",
        "BORG_LINK_SWEEP_WINDOW_DAYS",
        "BORG_LINK_SWEEP_FIXTURE",
        "BORG_LINK_FETCH_FIXTURE",
    ):
        monkeypatch.delenv(name, raising=False)
    monkeypatch.setattr("borg_core.link.shell.live_windows", lambda: [])
    return tmp_path


@pytest.fixture()
def record_forks(monkeypatch):
    """Record the argv of every subprocess borg_core runs, then run it for real.

    borg_core.proc.run_capture is THE one fork site (borg_core/proc.py's docstring is the standing
    ruling, and test_proc.py pins it mechanically), so wrapping it sees git, tmux and every adapter
    without knowing what any of them are. Wrapping rather than stubbing is what makes the paired
    control meaningful: the same probe proves the sweep DOES fork without `--local`.
    """
    calls: list[list[str]] = []
    real = proc.run_capture

    def spy(argv, timeout=None):
        calls.append(list(argv))
        return real(argv, timeout=timeout)

    monkeypatch.setattr(proc, "run_capture", spy)
    return calls


def _git_repository(directory: Path, slug: str) -> str:
    """A real git checkout with a real `origin` pointing at `slug`. repository_slug reads it for real."""
    directory.mkdir(parents=True, exist_ok=True)
    subprocess.run(["git", "init", "-q", str(directory)], check=True, capture_output=True)
    subprocess.run(
        ["git", "-C", str(directory), "remote", "add", "origin", f"https://github.com/{slug}.git"],
        check=True,
        capture_output=True,
    )
    return str(directory)


def _write_registry(root: Path, projects: dict) -> None:
    (root / "borg-dir" / "registry.json").write_text(json.dumps({"projects": projects}), encoding="utf-8")


def _write_manifest(repository_dir: str, name: str, manifest: dict) -> Path:
    directory = Path(repository_dir) / ".borg" / "programs"
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / f"{name}.json"
    path.write_text(json.dumps(manifest), encoding="utf-8")
    return path


def _adapter(directory: Path, source: str, body: str) -> Path:
    """A REAL executable adapter. Production discovers it, execs it, and reads its stdout."""
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / f"recon-adapter-{source}"
    path.write_text(f"#!/usr/bin/env bash\n{body}\n", encoding="utf-8")
    path.chmod(0o755)
    return path


def _four_repository_registry(root: Path) -> dict:
    """FOUR registered repositories where the ONLY manifest lives in the SECOND and declares rows in
    all four. The hardened spec's B6 fixture, and the shape S2's verify pass caught a false pass on.

    THE ORDERING IS THE TEST. The manifest host (`bravo`) is neither first in registry order nor
    first alphabetically, and the repository the document is built FROM (`delta`) is last on both
    keys. An implementation that globbed only the in-scope repository, only the first registered one,
    or only the alphabetically-first one selects nothing here -- where a two-repository fixture with
    the host sorting first passes all three of those wrong implementations.
    """
    slugs = {name: f"testorg/{name}" for name in ("alpha", "bravo", "charlie", "delta")}
    dirs = {name: _git_repository(root / "ws" / name, slug) for name, slug in slugs.items()}
    _write_manifest(
        dirs["bravo"],
        "cross-repository",
        {
            "program": "cross-repository",
            "rows": [
                {"order": "1", "ref": "testorg/alpha#11", "status": "merged", "why": "first"},
                {"order": "2", "ref": "testorg/bravo#22", "status": "merged", "why": "second"},
                {"order": "3", "ref": "testorg/charlie#33", "status": "open", "why": "third"},
                {"order": "4", "ref": "testorg/delta#44", "status": "stacked", "why": "fourth"},
            ],
        },
    )
    _write_registry(root, {name: {"path": path, "status": "idle"} for name, path in dirs.items()})
    return dirs


# ── B6: discovery is global, selection is scoped ──────────────────────────────────────────────────


def test_a_manifest_hosted_by_another_repository_is_selected_from_the_fourth(isolated, monkeypatch):
    """THE MANDATORY B6 REGRESSION. Four repositories, one manifest, hosted by the second.

    `stillpoint/.borg/programs/ingle-t1-cutover.json` declares rows across four repositories and
    lives under exactly one of them. Repository-scoped DISCOVERY renders an empty grid in the other
    three -- which the plan's own risk section says "reads as broken" -- and three of four is the
    modal case, not an edge case. This stands in the fourth repository and demands the second's
    manifest.
    """
    dirs = _four_repository_registry(isolated)
    monkeypatch.chdir(dirs["delta"])

    grid = cli._document("", False, "json", local=True)["grid"]

    assert grid["scope_kind"] == "repository"
    assert grid["slug"] == "testorg/delta", "the slug must come from the repository in hand, not the manifest's host"
    assert [m["id"] for m in grid["manifests"]] == ["cross-repository"]
    # The manifest's file really does live somewhere else -- if this ever points inside delta, the
    # fixture stopped testing B6 and started testing local discovery.
    assert grid["manifests"][0]["path"].startswith(dirs["bravo"])
    assert "testorg/delta#44" in grid["manifests"][0]["nodes"]


def test_selection_is_scoped_even_though_discovery_is_not(isolated, monkeypatch):
    """A repository declaring NO row in the manifest selects nothing, and says why.

    The other half of B6. Discovery is global, so the manifest is found from `echo` too; selection
    must then reject it rather than render another project's whole grid under this repository's
    header, which is the B3 wrong-answer class this front door exists to remove.
    """
    _four_repository_registry(isolated)
    outsider = _git_repository(isolated / "ws" / "echo", "testorg/echo")
    registry = json.loads((isolated / "borg-dir" / "registry.json").read_text())
    registry["projects"]["echo"] = {"path": outsider, "status": "idle"}
    (isolated / "borg-dir" / "registry.json").write_text(json.dumps(registry), encoding="utf-8")
    monkeypatch.chdir(outsider)

    grid = cli._document("", False, "json", local=True)["grid"]

    assert grid["slug"] == "testorg/echo"
    assert grid["manifests"] == []
    assert any("none declaring a row in testorg/echo" in w for w in grid["warnings"])


def test_orchestrator_scope_selects_every_discovered_manifest(isolated, monkeypatch):
    """Orchestrator scope does not narrow. There is no single repository to scope to, and B6's rule
    is that SELECTION is scoped -- when the scope is "everything", selection is the identity."""
    _four_repository_registry(isolated)
    workspace = isolated / "ws"
    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", str(workspace))
    monkeypatch.chdir(workspace)

    grid = cli._document("", False, "json", local=True)["grid"]

    assert grid["scope_kind"] == "orchestrator"
    assert grid["slug"] == "", "orchestrator scope has no one repository, so no slug and no git call"
    assert [m["id"] for m in grid["manifests"]] == ["cross-repository"]


# ── the opt-down ──────────────────────────────────────────────────────────────────────────────────


def test_local_runs_no_adapter_while_the_same_call_without_it_does(isolated, monkeypatch, record_forks):
    """--local yields swept=False and forks no adapter; WITHOUT it, the same call forks one.

    PAIRED ON PURPOSE. A bare "zero subprocesses under --local" assertion is green whenever the
    adapter search path happens to be empty -- which is the state every bats case now runs in -- so
    on its own it proves nothing about the flag. The control run is what gives it teeth: the same
    fixture, the same cwd, the same registry, one flag different, and the adapter must run.
    """
    dirs = _four_repository_registry(isolated)
    adapters = isolated / "adapters"
    adapter = _adapter(adapters, "probe", 'echo \'{"source":"probe","summary":"ok","items":[]}\'')
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", str(adapters))
    monkeypatch.chdir(dirs["delta"])

    local_grid = cli._document("", False, "json", local=True)["grid"]
    forked_under_local = [argv for argv in record_forks if str(adapter) in argv[0]]

    assert local_grid["swept"] is False
    assert local_grid["since"] == "", "a mark nobody swept against is a freshness claim that is not true"
    assert forked_under_local == []
    assert any("--local" in w for w in local_grid["warnings"]), "the opt-down must say why nothing was fetched"
    # Manifests are still read: --local opts down from the NETWORK, not from local truth.
    assert [m["id"] for m in local_grid["manifests"]] == ["cross-repository"]

    record_forks.clear()
    swept_grid = cli._document("", False, "json", local=False)["grid"]

    assert swept_grid["swept"] is True
    assert [argv[0] for argv in record_forks if str(adapter) in argv[0]] == [str(adapter)]
    assert [s["source"] for s in swept_grid["sources"]] == ["probe"]


def test_local_in_orchestrator_scope_forks_nothing_at_all(isolated, monkeypatch, record_forks):
    """The strongest form of the opt-down: not one fork of any kind.

    Repository scope still runs ONE `git remote get-url` to learn its own `owner/repo`, because
    manifest selection cannot happen without it -- `--local` opts down from the network, not from the
    filesystem. Orchestrator scope needs no slug, so the opted-down path there touches no subprocess
    whatsoever, which is what pins that nothing else crept into it.

    A REAL, EXECUTABLE ADAPTER IS ON THE SEARCH PATH THROUGHOUT. Without it this assertion is
    vacuously true -- verified by mutation: with `--local` ignored entirely, an empty search path
    still forks nothing and the test stayed green. An assertion that cannot fail is not a gate.
    """
    _four_repository_registry(isolated)
    adapters = isolated / "adapters"
    _adapter(adapters, "probe", 'echo \'{"source":"probe","summary":"ok","items":[]}\'')
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", str(adapters))
    workspace = isolated / "ws"
    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", str(workspace))
    monkeypatch.chdir(workspace)

    cli._document("", False, "json", local=True)

    assert record_forks == []


# ── the resolve ladder ────────────────────────────────────────────────────────────────────────────


def test_a_declared_status_outside_the_three_state_tokens_resolves_to_unknown():
    """`stacked` is authoring vocabulary, not a PR state, and the live viz manifest carries it.

    Promoting it would put `stacked` in the same field a renderer reads `merged` from, and every
    downstream state glyph would need a branch for a word that describes a position in a stack. The
    honest answer is `unknown` until AC3's targeted fetch resolves the ref. `unknown` appearing in
    S3's output is expected and correct -- AC3's own verification is specified to go red today.
    """
    assert link_grid.resolve_state("o/r#1", "stacked", {}) == ("unknown", "unknown")
    assert link_grid.resolve_state("o/r#1", "merged", {}) == ("merged", "declared")
    assert link_grid.resolve_state("o/r#1", "MERGED", {}) == ("merged", "declared")
    assert link_grid.resolve_state("o/r#1", "", {}) == ("unknown", "unknown")
    assert link_grid.resolve_state("o/r#1", None, {}) == ("unknown", "unknown")


def test_a_swept_state_beats_a_declared_one_and_is_taken_verbatim():
    """Swept > declared, and the swept token is NOT filtered against the three github states.

    A source adapter owns its own vocabulary: an injected Jira adapter emits its own tokens, and
    coercing those to `unknown` would discard the only real answer anyone has. A declared status is
    hand-typed in a schema-less field and is filtered. The asymmetry is the design.
    """
    items = {"o/r#1": {"ref": "o/r#1", "state": "merged"}, "o/r#2": {"ref": "o/r#2", "state": "in review"}}
    assert link_grid.resolve_state("o/r#1", "stacked", items) == ("merged", "swept")
    assert link_grid.resolve_state("o/r#2", "merged", items) == ("in review", "swept")


def test_refs_are_matched_exactly_with_no_normalization():
    """No case fold, no `.git` handling, no rewriting -- see manifest.core.parse_ref for the argument.

    A normalizing join never raises; it just produces a ref that matches no item, and the node renders
    `unknown` forever. That silence is why this is pinned rather than trusted.
    """
    items = {"Owner/Repo#1": {"state": "merged"}}
    assert link_grid.resolve_state("owner/repo#1", "stacked", items) == ("unknown", "unknown")
    assert link_grid.resolve_state("Owner/Repo#1", "stacked", items) == ("merged", "swept")


def test_the_declared_status_of_a_live_manifest_row_lands_in_the_document(isolated, monkeypatch):
    """The ladder end to end, through a real registry and a real manifest, with no sweep.

    `testorg/delta#44` is declared `stacked` in the B6 fixture; nothing may turn that into a state.
    """
    dirs = _four_repository_registry(isolated)
    monkeypatch.chdir(dirs["delta"])

    nodes = cli._document("", False, "json", local=True)["grid"]["manifests"][0]["nodes"]

    assert nodes["testorg/delta#44"]["state"] == "unknown"
    assert nodes["testorg/delta#44"]["state_source"] == "unknown"
    assert nodes["testorg/alpha#11"]["state"] == "merged"
    assert nodes["testorg/alpha#11"]["state_source"] == "declared"


# ── the B7 fixture seam ───────────────────────────────────────────────────────────────────────────


def test_the_sweep_fixture_replaces_the_fanout_and_merges_into_nodes(isolated, monkeypatch, record_forks):
    """BORG_LINK_SWEEP_FIXTURE stands in for the fan-out: recorded states reach nodes, nothing forks.

    The fixture records the fan-out's OUTPUT, so everything downstream of the subprocess -- state
    extraction, the ladder, level assignment, the per-source summary -- is still production code
    under test. A fixture of the finished grid would assert that JSON round-trips.

    A REAL ADAPTER IS ON THE SEARCH PATH while this runs, and it writes a sentinel if it executes.
    Without that, "no fork" would be true because there was nothing to fork.
    """
    dirs = _four_repository_registry(isolated)
    adapters = isolated / "adapters"
    sentinel = isolated / "adapter-ran"
    adapter = _adapter(adapters, "probe", f'touch "{sentinel}"; echo \'{{"source":"probe","summary":"x","items":[]}}\'')
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", str(adapters))

    fixture = isolated / "sweep.json"
    fixture.write_text(
        json.dumps(
            {
                "since": "2026-08-20T00:00:00Z",
                "tracks": [
                    {
                        "source": "github",
                        "summary": "swept 4 github repo(s) — 2 PR item(s)",
                        "ok": True,
                        "items": [
                            {"ref": "testorg/delta#44", "state": "open", "title": "the fourth PR"},
                            {"ref": "testorg/charlie#33", "state": "merged", "title": "the third PR"},
                        ],
                    }
                ],
            }
        ),
        encoding="utf-8",
    )
    monkeypatch.setenv("BORG_LINK_SWEEP_FIXTURE", str(fixture))
    monkeypatch.chdir(dirs["delta"])

    grid = cli._document("", False, "json", local=False)["grid"]
    nodes = grid["manifests"][0]["nodes"]

    assert not sentinel.exists(), "the fixture seam must short-circuit BEFORE any adapter is exec'd"
    assert [argv for argv in record_forks if str(adapter) in argv[0]] == []
    assert grid["swept"] is True
    assert grid["since"] == "2026-08-20T00:00:00Z"
    assert grid["sources"] == [
        {
            "source": "github",
            "status": "ok",
            "summary": "swept 4 github repo(s) — 2 PR item(s)",
            "count": 2,
            "dropped": 0,
        }
    ]
    # The recorded state overrides the declared `stacked`, and the PR's own title arrives with it.
    assert nodes["testorg/delta#44"]["state"] == "open"
    assert nodes["testorg/delta#44"]["state_source"] == "swept"
    assert nodes["testorg/delta#44"]["title"] == "the fourth PR"
    # A row the fixture does not mention keeps its declared state, from the rung below.
    assert nodes["testorg/alpha#11"]["state_source"] == "declared"


def test_an_unreadable_sweep_fixture_warns_instead_of_raising(isolated, monkeypatch):
    """A mistyped fixture path must say so. An empty grid a harness mistakes for a correct one is the
    silent-blindness shape CLAUDE.md records three incidents of."""
    dirs = _four_repository_registry(isolated)
    monkeypatch.setenv("BORG_LINK_SWEEP_FIXTURE", str(isolated / "does-not-exist.json"))
    monkeypatch.chdir(dirs["delta"])

    grid = cli._document("", False, "json", local=False)["grid"]

    assert grid["swept"] is False
    assert any("unreadable or invalid JSON" in w for w in grid["warnings"])
    assert [m["id"] for m in grid["manifests"]] == ["cross-repository"], "the grid still renders"


# ── degradation: nothing in the grid path is ever fatal ───────────────────────────────────────────


@pytest.mark.parametrize(
    "body,expected",
    [
        ('["a list, not an object"]', "is not an object"),
        ('{"since": "x", "tracks": "not a list"}', "replayed from fixture"),
    ],
    ids=["non-object-root", "tracks-of-the-wrong-type"],
)
def test_a_wrongly_shaped_sweep_fixture_degrades_without_raising(isolated, monkeypatch, body, expected):
    """A fixture of the wrong SHAPE is a harness defect, and it must present as one.

    Valid JSON that is not a sweep document, and a `tracks` that is not a list, both arrive here from
    a hand-edited recording. Neither may raise out of a module whose header promises nothing is ever
    fatal, and neither may produce a confidently empty grid: the second case still reports itself as
    replayed, with zero tracks, which is the truthful reading of a recording that carries none.
    """
    dirs = _four_repository_registry(isolated)
    fixture = isolated / "sweep.json"
    fixture.write_text(body, encoding="utf-8")
    monkeypatch.setenv("BORG_LINK_SWEEP_FIXTURE", str(fixture))
    monkeypatch.chdir(dirs["delta"])

    grid = cli._document("", False, "json", local=False)["grid"]

    assert any(expected in w for w in grid["warnings"])
    assert grid["sources"] == []
    assert [m["id"] for m in grid["manifests"]] == ["cross-repository"]


def test_a_project_list_that_cannot_be_staged_warns_instead_of_raising(isolated, monkeypatch):
    """`write_projects_file` json.dumps the registry entries, and a registry is not schema-checked.

    A hand-edited entry holding a value json cannot serialize raises TypeError from inside the staging
    step -- before any adapter runs, and from a code path every `borg link` executes. Unguarded that
    is a traceback on `--json`'s stdout, which cli.main's broad catch turns into exit 1 and zero bytes
    for a consumer that swallows errors. It degrades to a named warning and a declared-only grid.
    """
    dirs = _four_repository_registry(isolated)
    adapters = isolated / "adapters"
    _adapter(adapters, "probe", 'echo \'{"source":"probe","summary":"ok","items":[]}\'')
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", str(adapters))
    monkeypatch.setattr(
        "borg_core.recon.shell.write_projects_file",
        lambda projects, path: (_ for _ in ()).throw(TypeError("Object of type set is not JSON serializable")),
    )
    monkeypatch.chdir(dirs["delta"])

    grid = cli._document("", False, "json", local=False)["grid"]

    assert grid["swept"] is False
    assert any("could not stage the project list" in w for w in grid["warnings"])
    assert [m["id"] for m in grid["manifests"]] == ["cross-repository"]


def test_a_failing_adapter_track_names_itself_and_the_grid_still_renders(isolated, monkeypatch):
    """A REAL adapter that exits non-zero with no output. One named warning, one full grid.

    Every consumer of `borg link` swallows failure (`cmd_watch`'s `|| true`, `drone status`'s
    `|| true`, fzf's preview pane), so an exception here is an invisible blank frame and a silent
    empty grid is worse than a loud degraded one.
    """
    dirs = _four_repository_registry(isolated)
    adapters = isolated / "adapters"
    _adapter(adapters, "boom", 'echo "exploded" >&2; exit 1')
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", str(adapters))
    monkeypatch.chdir(dirs["delta"])

    grid = cli._document("", False, "json", local=False)["grid"]

    assert grid["swept"] is True, "an adapter ran; that it failed is a separate fact"
    assert any("adapter 'boom' returned no usable answer" in w for w in grid["warnings"])
    assert [s["status"] for s in grid["sources"]] == ["failed"]
    assert [m["id"] for m in grid["manifests"]] == ["cross-repository"]
    assert grid["manifests"][0]["nodes"]["testorg/alpha#11"]["state"] == "merged"


def test_an_empty_adapter_search_path_is_a_named_warning_not_a_silent_empty_sweep(isolated, monkeypatch):
    """Zero adapters and zero warnings is indistinguishable from a correct empty sweep. That
    ambiguity is exactly how `borg recon` shipped dead and stayed dead for a fortnight."""
    dirs = _four_repository_registry(isolated)
    monkeypatch.chdir(dirs["delta"])

    grid = cli._document("", False, "json", local=False)["grid"]

    assert grid["swept"] is False
    assert any("no recon adapters found" in w for w in grid["warnings"])


def test_a_repository_with_no_git_origin_selects_nothing_and_says_so(isolated, monkeypatch):
    """No origin means no `owner/repo`, and no `owner/repo` means nothing can be scoped to it.

    The tempting degrade -- show every discovered manifest -- is the B3 wrong-answer class: another
    project's entire grid rendered under this repository's header.
    """
    dirs = _four_repository_registry(isolated)
    bare = isolated / "ws" / "foxtrot"
    bare.mkdir(parents=True)
    registry = json.loads((isolated / "borg-dir" / "registry.json").read_text())
    registry["projects"]["foxtrot"] = {"path": str(bare), "status": "idle"}
    (isolated / "borg-dir" / "registry.json").write_text(json.dumps(registry), encoding="utf-8")
    monkeypatch.chdir(bare)
    assert dirs["delta"]  # the fixture's other repositories are still registered and still discovered

    grid = cli._document("", False, "json", local=True)["grid"]

    assert grid["slug"] == ""
    assert grid["manifests"] == []
    assert any("no owner/repo resolved for 'foxtrot'" in w for w in grid["warnings"])


def test_a_malformed_manifest_warns_and_the_rest_of_the_grid_survives(isolated, monkeypatch):
    """One bad file must never blank the grid, and an unnamed skip is indistinguishable from a file
    that was never there. manifest/shell.py's header states the policy; this pins that link keeps it."""
    dirs = _four_repository_registry(isolated)
    broken = Path(dirs["delta"]) / ".borg" / "programs"
    broken.mkdir(parents=True, exist_ok=True)
    (broken / "broken.json").write_text("{ not json", encoding="utf-8")
    monkeypatch.chdir(dirs["delta"])

    grid = cli._document("", False, "json", local=True)["grid"]

    assert any("unreadable or invalid JSON" in w for w in grid["warnings"])
    assert [m["id"] for m in grid["manifests"]] == ["cross-repository"]


# ── B4: the deadline is on the work, and the process exits ────────────────────────────────────────


def test_a_hanging_adapter_is_killed_at_the_deadline_and_the_process_moves_on(isolated, monkeypatch):
    """B4's shape, measured rather than argued: a real adapter that sleeps 30s under a 1s budget.

    The hardened spec's B4 reported a ThreadPoolExecutor leaving a process alive for 12s after its
    output was complete. That failure needs a timeout on the FUTURE, which abandons a worker that is
    still running while `concurrent.futures.thread`'s atexit hook still joins it. recon.shell.fanout
    joins with NO timeout and bounds the WORK instead -- run_adapter hands the budget to
    subprocess.run, which SIGKILLs and reaps the child -- so the worker always exits. This asserts
    the whole `_document` call returns near the budget and not near the sleep.

    The ceiling is deliberately loose (12s against a 1s budget and a 30s sleep): what is being pinned
    is that the deadline is honoured AT ALL, and a tight bound would make this a flaky benchmark of
    the CI machine instead.
    """
    dirs = _four_repository_registry(isolated)
    adapters = isolated / "adapters"
    _adapter(adapters, "slow", 'sleep 30; echo \'{"source":"slow","summary":"never","items":[]}\'')
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", str(adapters))
    monkeypatch.setenv("BORG_LINK_SWEEP_TIMEOUT", "1")
    monkeypatch.chdir(dirs["delta"])

    started = time.monotonic()
    grid = cli._document("", False, "json", local=False)["grid"]
    elapsed = time.monotonic() - started

    assert elapsed < 12, f"the sweep outran its 1s budget by {elapsed:.1f}s -- the deadline is not reaching the child"
    assert any("adapter 'slow' returned no usable answer" in w for w in grid["warnings"])
    assert [m["id"] for m in grid["manifests"]] == ["cross-repository"]


def test_the_link_budget_reaches_the_adapter_and_recon_keeps_its_own(isolated, monkeypatch):
    """BORG_LINK_SWEEP_TIMEOUT is read here and passed down; recon's own default is untouched.

    Mutating os.environ to configure a child was the rejected alternative: it is a process-global,
    non-reentrant write that leaks into any later recon call in the same interpreter, and the
    hardened spec independently forbids adding any `BORG_RECON_*` name to the `_borg_py` wrapper.
    """
    from borg_core.link import shell as link_shell  # noqa: PLC0415  (local: asserts the module's own reader)
    from borg_core.recon import shell as recon_shell  # noqa: PLC0415

    assert link_shell.sweep_timeout() == link_shell.DEFAULT_SWEEP_TIMEOUT_SECONDS
    assert recon_shell.track_timeout() == recon_shell.DEFAULT_TRACK_TIMEOUT
    monkeypatch.setenv("BORG_LINK_SWEEP_TIMEOUT", "3")
    assert link_shell.sweep_timeout() == 3
    assert recon_shell.track_timeout() == recon_shell.DEFAULT_TRACK_TIMEOUT, "link's budget must not move recon's"
    # Empty and non-numeric take the default rather than raising: `_borg_py` passes unset variables
    # through as the EMPTY STRING, and `int("")` is the exact ValueError that makes recon's readers
    # unsafe to add to that wrapper.
    monkeypatch.setenv("BORG_LINK_SWEEP_TIMEOUT", "")
    assert link_shell.sweep_timeout() == link_shell.DEFAULT_SWEEP_TIMEOUT_SECONDS
    monkeypatch.setenv("BORG_LINK_SWEEP_TIMEOUT", "soon")
    assert link_shell.sweep_timeout() == link_shell.DEFAULT_SWEEP_TIMEOUT_SECONDS
    assert isolated  # the fixture's env isolation is what makes the unset defaults meaningful


# ── sweep breadth, and the cache AC1 forbids ──────────────────────────────────────────────────────


def test_repository_scope_sweeps_one_repository_and_orchestrator_scope_sweeps_all(isolated, monkeypatch):
    """The scope narrows the SWEEP, which is the whole difference between AC1's 0.69s and its 2.30s.

    Asserted on the project list the adapter is actually handed, because that file is the only place
    the breadth becomes observable -- the adapter reads it and nothing else.
    """
    dirs = _four_repository_registry(isolated)
    adapters = isolated / "adapters"
    seen = isolated / "projects-seen.json"
    _adapter(
        adapters,
        "probe",
        f'cp "$4" "{seen}"; echo \'{{"source":"probe","summary":"ok","items":[]}}\'',
    )
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", str(adapters))

    monkeypatch.chdir(dirs["delta"])
    cli._document("", False, "json", local=False)
    assert sorted(json.loads(seen.read_text())) == ["delta"]

    workspace = isolated / "ws"
    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", str(workspace))
    monkeypatch.chdir(workspace)
    cli._document("", False, "json", local=False)
    assert sorted(json.loads(seen.read_text())) == ["alpha", "bravo", "charlie", "delta"]


def test_an_explicit_positional_narrows_the_sweep_the_way_it_narrows_the_scope(isolated, monkeypatch):
    """B3 all the way down. `borg link bravo` from inside delta must SWEEP bravo, not just label it.

    S1 made the positional dominate cwd for `scope`; if the sweep still derived its breadth from cwd,
    the document would carry bravo's header over delta's fetched state -- a wrong answer under a
    confident header, which is worse than the missing one it replaced.
    """
    dirs = _four_repository_registry(isolated)
    adapters = isolated / "adapters"
    seen = isolated / "projects-seen.json"
    _adapter(adapters, "probe", f'cp "$4" "{seen}"; echo \'{{"source":"probe","summary":"ok","items":[]}}\'')
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", str(adapters))
    monkeypatch.chdir(dirs["delta"])

    document = cli._document("bravo", False, "json", local=False)

    assert document["scope"]["repository"] == "bravo"
    assert document["grid"]["slug"] == "testorg/bravo"
    assert sorted(json.loads(seen.read_text())) == ["bravo"]


def test_two_consecutive_runs_write_no_cache_artifact(isolated, monkeypatch):
    """AC1: "No cache, ever -- a clean read every time." The one artifact at risk is recon's own mark.

    recon.shell.write_last_run_marker is the third rung of recon's since-ladder. A `borg link` that
    advanced it would silently move `borg recon`'s mark forward on every render, and recon would
    start missing everything that changed between link runs -- a data-loss bug in a different command,
    caused by a command that only reads.
    """
    dirs = _four_repository_registry(isolated)
    adapters = isolated / "adapters"
    _adapter(adapters, "probe", 'echo \'{"source":"probe","summary":"ok","items":[]}\'')
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", str(adapters))
    monkeypatch.chdir(dirs["delta"])

    cli._document("", False, "json", local=False)
    cli._document("", False, "json", local=False)

    marker = isolated / "borg-dir" / "recon" / "last-run"
    assert not marker.exists(), "borg link must never advance borg recon's since-mark"


# ── document shape ────────────────────────────────────────────────────────────────────────────────


def test_the_grid_is_additive_and_the_document_version_stays_two(isolated, monkeypatch):
    """The grid narrows the GRID and nothing else. `.order`/`.projects` still cover the whole registry.

    That is the entire argument for not bumping DOCUMENT_VERSION here, and `assemble`'s docstring now
    records that the earlier forecast (bump with the sweep fold) was wrong. Bumping would fire
    `/borg-link`'s version-skew warning on every invocation for a document it reads perfectly, and
    the four coupled SKILL.md edits a real bump requires would all have to land in the same commit.
    """
    dirs = _four_repository_registry(isolated)
    monkeypatch.chdir(dirs["delta"])

    document = cli._document("", False, "json", local=True)

    assert document["version"] == core.DOCUMENT_VERSION == 2
    assert sorted(document["order"]) == ["alpha", "bravo", "charlie", "delta"]
    assert len(document["projects"]) == 4
    assert document["grid"]["scope_kind"] == "repository"


def test_every_mode_carries_a_grid(isolated, monkeypatch):
    """Deliberately NOT mode-gated, unlike `directives`/`assimilated`/`focus`.

    Those are display sections a renderer either prints or does not. The grid is the DERIVED FACT the
    front door exists to serve, and gating it by mode reconstitutes what B1's rejected alternative was
    rejected for: two modes of one command answering the same question with different data.
    """
    dirs = _four_repository_registry(isolated)
    monkeypatch.chdir(dirs["delta"])

    for mode in ("json", "porcelain", "deep", "overview"):
        project = "delta" if mode == "deep" else ""
        grid = cli._document(project, False, mode, local=True)["grid"]
        assert grid["manifests"], f"{mode} lost the grid"


def test_levels_and_the_node_level_agree(isolated, monkeypatch):
    """`level` on a node is an index into `levels`, and the redundancy is deliberate: a consumer
    reading one node must not have to invert a list of lists to learn where it sits."""
    dirs = _four_repository_registry(isolated)
    monkeypatch.chdir(dirs["delta"])

    manifest = cli._document("", False, "json", local=True)["grid"]["manifests"][0]

    for index, level in enumerate(manifest["levels"]):
        for ref in level:
            assert manifest["nodes"][ref]["level"] == index
    assert manifest["levels"] == [
        ["testorg/alpha#11"],
        ["testorg/bravo#22"],
        ["testorg/charlie#33"],
        ["testorg/delta#44"],
    ]


def test_a_declared_ref_that_is_not_a_row_still_gets_a_node(isolated, monkeypatch):
    """The node set is declared_refs, NOT row_refs, and this is AC3's whole subject.

    A row's `after` entry, its `gate.blocked_by_ref`, and the manifest's `apex.ref` may all name work
    no row declares -- frequently in another repository and outside the sweep window. Those are
    exactly the refs AC3's targeted fetch exists to resolve, and if nodes covered rows only, the fetch
    would have nowhere to put its answer and `ready_set` could never learn a fork parent's state, so
    every forked row would be permanently not-ready.

    Pinned because the B6 fixture cannot discriminate it: its manifest has no apex, no `after` and no
    `blocked_by_ref`, so declared_refs and row_refs are the same list there -- verified by mutation,
    where swapping one for the other left every other test in this file green.
    """
    slug = "testorg/hotel"
    repository = _git_repository(isolated / "ws" / "hotel", slug)
    _write_manifest(
        repository,
        "forked",
        {
            "program": "forked",
            "apex": {"ref": "testorg/hotel#1", "title": "tracker"},
            "rows": [
                {"order": "1", "ref": "testorg/hotel#2", "status": "merged", "why": "the trunk"},
                {
                    "order": "2",
                    "ref": "testorg/hotel#3",
                    "status": "open",
                    "why": "a fork",
                    "after": ["testorg/elsewhere#9"],
                    "gate": {
                        "kind": "verification",
                        "blocked_by": "the elsewhere prerequisite",
                        "blocked_by_ref": "testorg/elsewhere#8",
                        "resolved_by": "that PR merging",
                    },
                },
            ],
        },
    )
    _write_registry(isolated, {"hotel": {"path": repository, "status": "idle"}})
    monkeypatch.chdir(repository)

    manifest = cli._document("", False, "json", local=True)["grid"]["manifests"][0]

    for ref in ("testorg/hotel#1", "testorg/elsewhere#8", "testorg/elsewhere#9"):
        assert ref in manifest["nodes"], f"{ref} is declared but not a row -- it still needs a node"
        assert manifest["nodes"][ref]["state"] == "unknown", "nothing declares a status for a non-row ref"
        assert manifest["nodes"][ref]["state_source"] == "unknown"


# ── pure helpers ──────────────────────────────────────────────────────────────────────────────────


def test_track_warnings_treats_an_absent_ok_as_success_and_a_false_one_as_failure():
    """recon.core stamps `ok` on every track it builds, so an ABSENT key only ever means a
    hand-recorded fixture. Defaulting that to failure would make every fixture emit spurious
    warnings; treating `False` as success is the jq `//` trap that makes a failed track invisible."""
    assert link_grid.track_warnings([{"source": "a", "summary": "fine"}]) == []
    assert link_grid.track_warnings([{"source": "a", "summary": "fine", "ok": True}]) == []
    assert link_grid.track_warnings([{"source": "a", "summary": "died", "ok": False}]) == [
        "sweep: adapter 'a' returned no usable answer -- died"
    ]
    assert link_grid.track_warnings(["not a dict"]) == []


def test_swept_items_is_first_writer_wins_across_adapters():
    """Deterministic, because fanout preserves adapter order and discover_adapters is sorted and
    deduped first-on-path-wins -- so a config-dir adapter shadowing the shipped one wins here too.
    Last-wins would make the answer depend on which adapter finished first, i.e. on thread order."""
    tracks = [
        {"source": "a", "items": [{"ref": "o/r#1", "state": "open"}]},
        {"source": "b", "items": [{"ref": "o/r#1", "state": "merged"}]},
    ]
    assert link_grid.swept_items(tracks)["o/r#1"]["state"] == "open"
    assert link_grid.swept_items([{"source": "a", "items": [{"state": "open"}]}]) == {}
    assert link_grid.swept_items([{"source": "a", "items": ["junk"]}, "junk"]) == {}


def test_no_sweep_never_invents_a_since():
    assert link_grid.no_sweep() == {"swept": False, "since": "", "tracks": [], "warnings": []}
    assert link_grid.no_sweep(["because"])["warnings"] == ["because"]


def test_scoped_projects_never_widens_a_narrowed_sweep():
    """A repository named in the scope but absent from the registry yields {}, not everything.

    Silently widening is how a reflexive command becomes a 2.3s one with nothing on screen to say why.
    """
    registry = {"projects": {"a": {"path": "/a"}, "b": {"path": "/b"}}}
    assert link_grid.scoped_projects(registry, {"kind": "repository", "repository": "b"}) == {"b": {"path": "/b"}}
    assert link_grid.scoped_projects(registry, {"kind": "repository", "repository": "zz"}) == {}
    assert sorted(link_grid.scoped_projects(registry, {"kind": "orchestrator"})) == ["a", "b"]


def test_repository_dir_rejects_jqs_null_sentinel():
    """`jq` renders a JSON null as the four characters `null`, and every zsh reader in the tree guards
    it. Passing it through would make manifest discovery read `null/.borg/programs` relative to
    whatever directory the process is sitting in."""
    registry = {"projects": {"a": {"path": "null"}, "b": {"path": "/b"}, "c": {}, "d": None}}
    assert link_grid.repository_dir(registry, {"kind": "repository", "repository": "a"}) == ""
    assert link_grid.repository_dir(registry, {"kind": "repository", "repository": "b"}) == "/b"
    assert link_grid.repository_dir(registry, {"kind": "repository", "repository": "c"}) == ""
    # A null entry is a plausible partial-write artifact and reaches core.py as None; `.get("path")`
    # on it is the AttributeError cli.main's broad catch turns into a bare exit 1.
    assert link_grid.repository_dir(registry, {"kind": "repository", "repository": "d"}) == ""
    assert link_grid.repository_dir(registry, {"kind": "repository", "repository": "gone"}) == ""
    assert link_grid.repository_dir(registry, {"kind": "orchestrator", "repository": None}) == ""


def test_the_fetch_fixture_name_is_reserved_and_deliberately_unimplemented():
    """BORG_LINK_FETCH_FIXTURE is AC3's seam and must not exist yet.

    Shipping an unused reader would be dead code carried on a 90% coverage floor. The name is
    reserved in shell.sweep's docstring so AC3 mirrors this seam instead of inventing a second,
    differently-shaped one -- and this asserts the contract is written down, since a reserved name
    nobody can find is not reserved.

    IT POINTS AT `sweep`, WHICH IS WHERE THE SIBLING SEAM IS ACTUALLY READ (`os.environ.get` at the
    top of that function), so when AC3 mirrors it exactly as the docstring directs, this goes red and
    marks the transition. The first version of this test pointed at `_read_sweep_fixture` -- where
    neither env-var name has ever appeared, so it could not have failed -- and paired it with
    `assert <anything> or True`, which is unconditionally green. A gate against
    `reference_test_supplies_derived_value`, itself unable to fail, in the file whose header docstring
    is about exactly that.
    """
    from borg_core.link import shell as link_shell  # noqa: PLC0415

    assert "BORG_LINK_FETCH_FIXTURE" in link_shell.sweep.__doc__
    assert "BORG_LINK_SWEEP_FIXTURE" in link_shell.sweep.__code__.co_consts, (
        "the control: sweep IS where seams are read"
    )
    assert "BORG_LINK_FETCH_FIXTURE" not in link_shell.sweep.__code__.co_consts, "the reader must not exist yet"


# ── the production path, end to end: a real adapter's item reaching a node ────────────────────────


def _valid_item(ref: str, state: str, title: str) -> str:
    """One schema-VALID recon Item as a JSON fragment, all ten v0 fields present and correctly typed.

    Hand-built rather than borrowed from a helper because the whole point of the two cases below is
    that the item traverses recon's REAL validator (`validate_item`): `action_needed` is a JSON bool
    and not the string "false", `owner` is one of you/agent/unknown, `urgency` is one of
    now/this_week/fyi. Get any of them wrong and the engine drops the item and the test proves the
    opposite of what it claims.
    """
    return json.dumps(
        {
            "project": "delta",
            "source": "probe",
            "ref": ref,
            "title": title,
            "state": state,
            "changed": "updated 2026-08-25T00:00:00Z",
            "owner": "you",
            "action_needed": False,
            "urgency": "fyi",
            "one_line": f"{ref} {title}",
        }
    )


def test_a_real_adapters_item_reaches_a_node_through_the_real_fanout(isolated, monkeypatch):
    """THE MISSING END-TO-END CASE. A real executable adapter emits a schema-valid Item; that Item's
    state and title must arrive on the node, having passed through fanout, process_adapter_output,
    normalize_track and validate_item.

    Every other adapter in this file emits `"items": []`, and the only non-empty items in the suite
    entered through BORG_LINK_SWEEP_FIXTURE -- which short-circuits BEFORE the fan-out, so those
    items never touched the validator at all, and their recorded shape (`{ref, state, title}`) is not
    the shape production produces. Nothing anywhere asserted that a swept state could reach
    `.grid.manifests[].nodes[].state` through the production path.

    MUTATION-VERIFIED, and this is the failure that motivated it: setting `since = ""` in
    link/shell.py's sweep left all 33 pytest cases and all 7 bats cases green, while in production
    the shipped adapter hits `[ -n "$SINCE" ] || emit_skip` and returns an item-less track -- so
    `swept` stayed true, `sources` showed one track, `warnings` stayed empty, and every node in every
    grid silently fell back to what the manifest declared. Identical in shape to `borg recon`
    shipping completely dead with a green suite.
    """
    dirs = _four_repository_registry(isolated)
    adapters = isolated / "adapters"
    _adapter(
        adapters,
        "probe",
        "echo '"
        + json.dumps(
            {
                "source": "probe",
                "summary": "one real item",
                "items": [json.loads(_valid_item("testorg/delta#44", "merged", "the fourth PR"))],
            }
        )
        + "'",
    )
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", str(adapters))
    monkeypatch.chdir(dirs["delta"])

    grid = cli._document("", False, "json", local=False)["grid"]
    node = grid["manifests"][0]["nodes"]["testorg/delta#44"]

    assert grid["sources"] == [
        {"source": "probe", "status": "ok", "summary": "one real item", "count": 1, "dropped": 0}
    ], "the item survived the Item validator, so nothing was dropped and the track is clean"
    assert node["state"] == "merged", "the state came off the wire, not out of the manifest"
    assert node["state_source"] == "swept"
    assert node["title"] == "the fourth PR", "a title exists only on the swept rung; a manifest row has no title"
    assert grid["warnings"] == []
    # The declared `stacked` on this row is what it would have fallen back to. Its neighbour, which
    # the adapter said nothing about, still does -- that is the rung below, still working.
    assert grid["manifests"][0]["nodes"]["testorg/alpha#11"]["state_source"] == "declared"
    assert grid["declared"] == 4 and grid["unresolved"] == 3


def test_the_adapter_receives_a_since_mark_and_it_is_the_one_link_resolved(isolated, monkeypatch):
    """The `--since` argv is asserted, because nothing else in the suite could see it.

    The shipped adapter treats the mark as a hard filter and skips entirely without one
    (`[ -n "$SINCE" ] || emit_skip "no --since provided"`), so an empty mark is a silently dead sweep
    with a green suite. This records the argv the adapter actually received and checks it against the
    mark production computes from the same window.
    """
    dirs = _four_repository_registry(isolated)
    adapters = isolated / "adapters"
    seen = isolated / "argv-seen.txt"
    _adapter(adapters, "probe", f'printf "%s\\n" "$*" > "{seen}"; echo \'{{"source":"probe","summary":"x","items":[]}}\'')
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", str(adapters))
    monkeypatch.chdir(dirs["delta"])

    grid = cli._document("", False, "json", local=False)["grid"]

    argv = seen.read_text().split()
    assert "--since" in argv
    since = argv[argv.index("--since") + 1]
    assert since, "an empty mark makes the shipped adapter skip its whole sweep"
    assert since == grid["since"], "the document must report the mark the adapter was actually given"
    # And it is link's own window, not recon's ladder: exactly DEFAULT_SWEEP_WINDOW_DAYS back from an
    # instant no further in the past than this test's own start.
    expected = link_grid.sweep_since(int(time.time()), link_grid.DEFAULT_SWEEP_WINDOW_DAYS)
    assert since[:10] == expected[:10]


def test_the_sweep_mark_does_not_move_with_scope_or_with_checkpoint_mtimes(isolated, monkeypatch):
    """THE BLOCKER REGRESSION. One ref must not resolve to two confident states by scope.

    The first pass reused `recon.shell.resolve_since`, whose top rung is the newest
    `.borg/checkpoints/*.md` mtime across the SCOPED projects. Two consequences, both reproduced
    against real checkouts and a real filtering adapter: repository scope and orchestrator scope
    handed the adapter DIFFERENT marks (the wider breadth taking the newer checkpoint, hence the
    NARROWER window), and a freshly-checkpointed repository collapsed its own window to today. The
    grid then reported a merged PR as open, with `swept: true` and no warning.

    So: a stale checkpoint in one repository, a checkpoint written RIGHT NOW in another, and the mark
    must be identical from both scopes and unmoved by either file.
    """
    dirs = _four_repository_registry(isolated)
    for name, when in (("alpha", 1_700_000_000), ("bravo", None)):
        checkpoints = Path(dirs[name]) / ".borg" / "checkpoints"
        checkpoints.mkdir(parents=True)
        stamp = checkpoints / "2026-08-25-0000.md"
        stamp.write_text("# checkpoint\n", encoding="utf-8")
        if when is not None:
            os_utime = __import__("os").utime
            os_utime(stamp, (when, when))

    adapters = isolated / "adapters"
    _adapter(adapters, "probe", 'echo \'{"source":"probe","summary":"x","items":[]}\'')
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", str(adapters))

    monkeypatch.chdir(dirs["alpha"])
    repository_mark = cli._document("", False, "json", local=False)["grid"]["since"]

    workspace = isolated / "ws"
    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", str(workspace))
    monkeypatch.chdir(workspace)
    orchestrator_mark = cli._document("", False, "json", local=False)["grid"]["since"]

    assert repository_mark[:10] == orchestrator_mark[:10], (
        "the mark moved with scope -- the same ref will resolve to two different confident states"
    )
    # And it is genuinely WIDE, not "since the last checkpoint": far enough back that a PR merged
    # last week is inside it. The whole point is that the grid wants current state, not a delta.
    assert repository_mark < link_grid.sweep_since(int(time.time()), 30)


def test_the_sweep_window_is_configurable_and_survives_an_empty_value(isolated, monkeypatch):
    """Same three-way guard as sweep_timeout: unset OR EMPTY OR non-numeric takes the default."""
    from borg_core.link import shell as link_shell  # noqa: PLC0415

    assert link_shell.sweep_window_days() == link_grid.DEFAULT_SWEEP_WINDOW_DAYS
    monkeypatch.setenv("BORG_LINK_SWEEP_WINDOW_DAYS", "7")
    assert link_shell.sweep_window_days() == 7
    monkeypatch.setenv("BORG_LINK_SWEEP_WINDOW_DAYS", "")
    assert link_shell.sweep_window_days() == link_grid.DEFAULT_SWEEP_WINDOW_DAYS
    monkeypatch.setenv("BORG_LINK_SWEEP_WINDOW_DAYS", "a fortnight")
    assert link_shell.sweep_window_days() == link_grid.DEFAULT_SWEEP_WINDOW_DAYS
    # A zero or negative window would ask an adapter about the future; clamped to one day.
    assert link_grid.sweep_since(1_000_000, 0) == link_grid.sweep_since(1_000_000, 1)
    assert isolated


# ── the degraded rung: a source that exits 0 without ever reaching its source ─────────────────────


def test_an_adapter_that_exits_zero_without_reaching_its_source_is_degraded_not_ok(isolated, monkeypatch):
    """THE OTHER BLOCKER. `ok` is set False only on a non-zero exit, a timeout, or unparseable
    output -- and the shipped github adapter does NONE of those for its own unavailability.

    A missing `gh`, an unauthenticated `gh`, an offline host, a rate limit and "no github repository
    in scope" ALL route through `emit_skip`, which prints a valid track and exits 0. So the five most
    likely real-world sweep failures used to arrive as `status: "ok"`, `count: 0`, `warnings: []` --
    byte-identical to a healthy sweep that found nothing, while every state in the grid came from a
    hand-authored manifest field under a document claiming `swept: true`. Reproduced end to end with
    a `gh` that exits 1.

    The adapter contract now carries `skipped: true` for exactly this, and this case stands up a real
    adapter that sets it.
    """
    dirs = _four_repository_registry(isolated)
    adapters = isolated / "adapters"
    _adapter(
        adapters,
        "probe",
        'echo \'{"source":"probe","summary":"gh graphql sweep failed (unauthenticated) — skipped",'
        '"items":[],"skipped":true}\'',
    )
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", str(adapters))
    monkeypatch.chdir(dirs["delta"])

    grid = cli._document("", False, "json", local=False)["grid"]

    assert grid["swept"] is True, "an adapter ran; that it could not reach its source is a separate fact"
    assert [s["status"] for s in grid["sources"]] == ["degraded"]
    assert any("could not reach its source" in w for w in grid["warnings"]), (
        "an unreachable source with an empty warnings list is indistinguishable from a clean empty sweep"
    )
    assert grid["manifests"][0]["nodes"]["testorg/alpha#11"]["state_source"] == "declared"


def test_items_the_schema_rejects_are_counted_and_warned_about(isolated, monkeypatch):
    """A track that reached its source, got a full answer, and threw all of it away.

    recon's `normalize_track` filters every item through `validate_item`, records the casualties in
    `dropped`, and STILL stamps `ok: True`. The receipt used to project `dropped` away, so a sweep
    reporting `summary: "1 PR item(s)"` sat next to `count: 0`, `status: "ok"` and no warning at all.
    `action_needed` as the string "false" rather than a bool is the whole defect here -- a plausible
    jq typo, and exactly the shape an injected adapter gets wrong first.
    """
    dirs = _four_repository_registry(isolated)
    adapters = isolated / "adapters"
    bad = json.loads(_valid_item("testorg/delta#44", "merged", "the fourth PR"))
    bad["action_needed"] = "false"
    _adapter(
        adapters,
        "probe",
        "echo '" + json.dumps({"source": "probe", "summary": "1 PR item(s)", "items": [bad]}) + "'",
    )
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", str(adapters))
    monkeypatch.chdir(dirs["delta"])

    grid = cli._document("", False, "json", local=False)["grid"]

    assert grid["sources"] == [
        {"source": "probe", "status": "degraded", "summary": "1 PR item(s)", "count": 0, "dropped": 1}
    ]
    assert any("the Item schema rejected" in w for w in grid["warnings"])
    assert grid["manifests"][0]["nodes"]["testorg/delta#44"]["state_source"] == "unknown"


def test_the_shipped_github_adapter_marks_its_own_unavailability(isolated, monkeypatch, record_forks):
    """The contract change asserted against the REAL shipped adapter, not a stand-in.

    A `gh` on PATH that exits non-zero is what unauthenticated, offline and rate-limited all look
    like from here. The adapter must still exit 0 with a valid track -- one bad source never aborts a
    fan-out -- and must say it could not look.
    """
    dirs = _four_repository_registry(isolated)
    fake_bin = isolated / "bin"
    fake_bin.mkdir()
    (fake_bin / "gh").write_text("#!/usr/bin/env bash\necho 'not authenticated' >&2\nexit 1\n", encoding="utf-8")
    (fake_bin / "gh").chmod(0o755)
    monkeypatch.setenv("PATH", f"{fake_bin}:{__import__('os').environ['PATH']}")
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", str(Path(__file__).resolve().parents[2] / "lib/recon/adapters"))
    monkeypatch.chdir(dirs["delta"])

    grid = cli._document("", False, "json", local=False)["grid"]

    assert any("recon-adapter-github" in argv[0] for argv in record_forks), "the real shipped adapter must have run"
    assert [s["status"] for s in grid["sources"]] == ["degraded"]
    assert any("could not reach its source" in w for w in grid["warnings"])


def test_an_empty_borg_recon_max_tracks_does_not_take_the_front_door_down(isolated, monkeypatch):
    """`int("")` raises, and that ValueError used to escape fanout -> sweep -> _grid -> _document.

    cli.main's broad boundary then printed one stderr line and exited 1 with ZERO BYTES on stdout --
    and every consumer of `borg link` swallows failure, so the user got a blank frame with no
    diagnosis. Same shape CLAUDE.md's "Learned" records for BORG_REAP_STALE_HOURS, one layer over,
    and newly reachable because S3 put `borg link` on recon's config readers for the first time.
    """
    dirs = _four_repository_registry(isolated)
    adapters = isolated / "adapters"
    _adapter(adapters, "probe", 'echo \'{"source":"probe","summary":"ok","items":[]}\'')
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", str(adapters))
    monkeypatch.chdir(dirs["delta"])

    for value in ("", "   ", "eight", "0", "-4"):
        monkeypatch.setenv("BORG_RECON_MAX_TRACKS", value)
        monkeypatch.setenv("BORG_RECON_TRACK_TIMEOUT", value)
        grid = cli._document("", False, "json", local=False)["grid"]
        assert grid["swept"] is True, f"BORG_RECON_MAX_TRACKS={value!r} took the whole document down"
        assert [m["id"] for m in grid["manifests"]] == ["cross-repository"]


# ── the ref-coercion mismatch ─────────────────────────────────────────────────────────────────────


def test_a_hand_authored_ref_with_stray_whitespace_still_reaches_its_node(isolated, monkeypatch):
    """One trailing space in a hand-authored `ref` used to erase that row's whole declaration.

    `declared_refs`, every edge builder and `ready_set` key on manifest.core's `_text`
    (`str(x or "").strip()`); `_grid_nodes` keyed its row lookup on the RAW string. Validation does
    not catch it -- `_row_ref_error` strips before calling `parse_ref`, so the padded ref validates
    clean -- so the lookup simply missed, the row became `{}`, and the node reported `unknown` with
    no lane, no order, no why and no `next`. No warning anywhere, because nothing failed.
    """
    repository = _git_repository(isolated / "ws" / "india", "testorg/india")
    _write_manifest(
        repository,
        "padded",
        {
            "program": "padded",
            "rows": [
                {"order": "1", "ref": "testorg/india#11 ", "status": "merged", "lane": "main", "why": "the trunk"},
                {"order": "2", "ref": "testorg/india#12", "status": "open", "lane": "main", "why": "the next one"},
            ],
        },
    )
    _write_registry(isolated, {"india": {"path": repository, "status": "idle"}})
    monkeypatch.chdir(repository)

    nodes = cli._document("", False, "json", local=True)["grid"]["manifests"][0]["nodes"]

    assert "testorg/india#11" in nodes, "the graph keys on the stripped ref, so the node must too"
    assert nodes["testorg/india#11"]["state"] == "merged"
    assert nodes["testorg/india#11"]["state_source"] == "declared"
    assert nodes["testorg/india#11"]["lane"] == "main"
    assert nodes["testorg/india#11"]["why"] == "the trunk"


def test_the_grid_carries_no_ready_set_and_no_duplicate_gate_list(isolated, monkeypatch):
    """Two keys deliberately NOT on the wire; see grid_manifest's docstring for both arguments.

    `ready` is AC4's routing signal and cannot be computed honestly until AC3's `fetched` rung exists
    -- from resolved states it announces hand-authored `merged` parents as satisfied, and from swept
    states only it is permanently empty on the modal cross-repository manifest. `unmapped_gates` is a
    pure projection of `gates`. Pinned so neither returns without the rung or the consumer that would
    justify it.
    """
    dirs = _four_repository_registry(isolated)
    monkeypatch.chdir(dirs["delta"])

    manifest = cli._document("", False, "json", local=True)["grid"]["manifests"][0]

    assert "ready" not in manifest
    assert "unmapped_gates" not in manifest
    assert "gates" in manifest
