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
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

import pytest

from borg_core import proc
from borg_core.link import cli, core
from borg_core.link import grid as link_grid

# ── fixtures ──────────────────────────────────────────────────────────────────────────────────────


# The neutralized fetch recording every case in this file replays unless it deliberately opts out.
# Named here rather than inlined so a test that asserts on the resulting warning can spell the same
# path the fixture wrote.
NEUTRAL_FETCH_FIXTURE = "no-fetch.json"


@pytest.fixture()
def isolated(tmp_path, monkeypatch):
    """A borg config home, an EMPTY adapter search path, a NEUTRALIZED fetch, and no inherited BORG_*.

    BORG_RECON_ADAPTER_PATH is neutralized to a real, existing, EMPTY DIRECTORY and not to "".
    recon.shell.adapter_search_path branches on `if override:`, so an exported-empty value is falsy
    and falls straight back to `<repo>/lib/recon/adapters` -- which on a developer's machine holds a
    working `recon-adapter-github`, so the "neutralized" suite would shell out to `gh`. Tests that
    want an adapter point this variable at a directory they populate themselves.

    BORG_LINK_FETCH_FIXTURE IS THE SECOND NETWORK SEAM AND NEEDS ITS OWN NEUTRALIZATION, because
    starving adapter discovery does nothing for it: AC3's targeted fetch is not adapter-mediated --
    borg_core execs `gh` itself. `_four_repository_registry` declares four refs, so before this line
    existed every `local=False` case in this file shelled out to the developer's real authenticated
    `gh` and asked GitHub about `testorg/alpha#11`. Measured: `fetch: 4 of 4 declared ref(s) did not
    resolve`, four aliases, one live round trip per test.

    A REAL FILE, NEVER "". start_fetch branches on `if fixture:` exactly as sweep does, so an
    exported-empty value is FALSY and falls straight through to the live fetch -- neutralization that
    silently does nothing, the same trap the BORG_RECON_ADAPTER_PATH paragraph above documents. Tests
    that want the real fetch delenv it and put their own `gh` on PATH.
    """
    borg_dir = tmp_path / "borg-dir"
    borg_dir.mkdir()
    empty_adapters = tmp_path / "no-adapters"
    empty_adapters.mkdir()
    neutral_fetch = tmp_path / NEUTRAL_FETCH_FIXTURE
    neutral_fetch.write_text(json.dumps({"nodes": {}}), encoding="utf-8")
    monkeypatch.setenv("BORG_DIR", str(borg_dir))
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", str(empty_adapters))
    monkeypatch.setenv("BORG_LINK_FETCH_FIXTURE", str(neutral_fetch))
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
        "BORG_LINK_FETCH_TIMEOUT",
    ):
        monkeypatch.delenv(name, raising=False)
    monkeypatch.setattr("borg_core.link.shell.live_windows", lambda: [])
    return tmp_path


def _replayed_fetch_warning(root: Path) -> str:
    """The exact warning `isolated`'s neutralized recording earns. A replay must say it was replayed."""
    return f"fetch: replayed from fixture {root / NEUTRAL_FETCH_FIXTURE} -- no gh ran"


@pytest.fixture()
def record_forks(monkeypatch):
    """Record the argv of every subprocess borg_core runs, then run it for real.

    borg_core.proc.run_background is THE one fork site -- it is the only place in the tree that
    constructs a `subprocess.Popen`, borg_core/proc.py's docstring is the standing ruling, and
    test_proc.py pins it mechanically. Wrapping it sees git, tmux, every adapter and AC3's targeted
    `gh` fetch without knowing what any of them are. Wrapping rather than stubbing is what makes the
    paired control meaningful: the same probe proves the sweep DOES fork without `--local`.

    IT WRAPS `run_background` AND NOT `run_capture`, and that is a correction rather than a
    preference. The fetch is start-now/collect-later and never passes through `run_capture`, so a
    probe on that name alone would be BLIND to it: the orchestrator leg of
    `test_local_forks_nothing_in_orchestrator_scope_and_only_the_slug_in_repository` asserts
    `record_forks == []`, and that would stay green with a fetch that ignored `--local`
    entirely. Wrapping BOTH would double-count instead, because `run_capture` is now literally
    `collect(run_background(argv), timeout)` and resolves that name as a module global at call time.
    """
    calls: list[list[str]] = []
    real = proc.run_background

    def spy(argv):
        calls.append(list(argv))
        return real(argv)

    monkeypatch.setattr(proc, "run_background", spy)
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


def _fake_gh(directory: Path, body: str) -> Path:
    """A REAL executable `gh` on PATH. The fetch resolves argv[0] by name, so this IS the whole seam."""
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / "gh"
    path.write_text(f"#!/usr/bin/env bash\n{body}\n", encoding="utf-8")
    path.chmod(0o755)
    return path


# CAPTURED FROM A LIVE `gh api graphql` BATCH, NOT IMAGINED. Recorded 2026-08-26 against
# stillpoint-labs/stillpoint plus one bogus repository and one bogus number: exit 1, `errors[]`
# carrying two NOT_FOUNDs, and every valid sibling fully resolved. Aliases renumbered onto
# _four_repository_registry's refs, which declared_refs sorts to
# [alpha#11, bravo#22, charlie#33, delta#44] = n0..n3.
#
# BOTH NULL SHAPES RIDE IN IT AND BOTH ARE ROUTINE. A dead ISSUE OR PR nulls only the inner field
# (`n1.issueOrPullRequest`); a repository that was renamed, deleted or made private nulls the WHOLE
# ALIAS (`"n2": null`). `data[alias]["issueOrPullRequest"]` raises TypeError on the second, out of a
# module whose header promises nothing in the grid path is ever fatal. A fixture hand-written from
# the spec's prose would carry only the first.
_B5_PAYLOAD = json.dumps(
    {
        "data": {
            "n0": {
                "issueOrPullRequest": {
                    "__typename": "PullRequest",
                    "number": 11,
                    "title": "alpha eleven",
                    "state": "MERGED",
                    "isDraft": False,
                    "updatedAt": "2026-08-26T00:00:00Z",
                }
            },
            "n1": {"issueOrPullRequest": None},
            "n2": None,
            "n3": {
                "issueOrPullRequest": {
                    "__typename": "Issue",
                    "number": 44,
                    "title": "delta forty-four",
                    "issueState": "OPEN",
                    "updatedAt": "2026-08-26T00:00:00Z",
                }
            },
        },
        "errors": [
            {
                "type": "NOT_FOUND",
                "path": ["n2"],
                "message": "Could not resolve to a Repository with the name 'testorg/charlie'.",
            },
            {
                "type": "NOT_FOUND",
                "path": ["n1", "issueOrPullRequest"],
                "message": "Could not resolve to an issue or pull request with the number of 22.",
            },
        ],
    }
)


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


def test_local_runs_neither_network_path_while_the_same_call_without_it_runs_both(isolated, monkeypatch, record_forks):
    """--local forks NEITHER the adapter NOR `gh`; WITHOUT it, the same call forks both.

    PAIRED ON PURPOSE. A bare "zero subprocesses under --local" assertion is green whenever the
    adapter search path happens to be empty -- which is the state every bats case now runs in -- so
    on its own it proves nothing about the flag. The control run is what gives it teeth: the same
    fixture, the same cwd, the same registry, one flag different, and both subprocesses must run.

    BOTH SEAMS, IN ONE CASE, BECAUSE THE FETCH'S GUARD IS A SEPARATE LINE. `--local` gates the sweep
    inside cli._grid's ternary, but the fetch has to START above that ternary for its round trip to
    overlap, so it carries its own `if local` and nothing about the sweep's guard protects it. That
    is the hardened spec's B1 in a new place: a half-wired `--local` fails OPEN, spawning `gh` for a
    caller that asked for no network. (The example used to be "borg.zsh's fzf preview re-executes
    `borg link --local` on every cursor move"; that preview was retired 2026-08-27. The failure mode
    does not need a hot loop -- `skills/borg-switch` runs `borg link --local --all` at the widest
    breadth there is, and B1's whole point is that the caller cannot tell the flag was ignored.)

    THE FETCH FIXTURE IS DELIBERATELY REMOVED HERE. `isolated` neutralizes it for the whole file, and
    under that neutralization "the fetch did not fork" is vacuously true -- it would pass with the
    guard deleted. A real, executable `gh` on PATH is what makes the assertion falsifiable.
    """
    dirs = _four_repository_registry(isolated)
    adapters = isolated / "adapters"
    adapter = _adapter(adapters, "probe", 'echo \'{"source":"probe","summary":"ok","items":[]}\'')
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", str(adapters))
    monkeypatch.delenv("BORG_LINK_FETCH_FIXTURE")
    fake_gh = _fake_gh(isolated / "fakebin", f"printf '%s' '{_B5_PAYLOAD}'; exit 1")
    monkeypatch.setenv("PATH", f"{fake_gh.parent}:{os.environ['PATH']}")
    monkeypatch.chdir(dirs["delta"])

    local_grid = cli._document("", False, "json", local=True)["grid"]
    forked_under_local = [argv for argv in record_forks if str(adapter) in argv[0] or argv[0] == "gh"]

    assert local_grid["swept"] is False
    assert local_grid["since"] == "", "a mark nobody swept against is a freshness claim that is not true"
    assert forked_under_local == []
    assert local_grid["fetch"] == {"attempted": False, "status": "skipped", "requested": 0, "resolved": 0}
    assert any("--local" in w for w in local_grid["warnings"]), "the opt-down must say why nothing was fetched"
    assert not any(w.startswith("fetch:") for w in local_grid["warnings"]), (
        "the sweep's warning already says nothing was fetched; a second line is noise on the mode "
        "fzf re-renders per keypress"
    )
    # Manifests are still read: --local opts down from the NETWORK, not from local truth.
    assert [m["id"] for m in local_grid["manifests"]] == ["cross-repository"]

    record_forks.clear()
    swept_grid = cli._document("", False, "json", local=False)["grid"]

    assert swept_grid["swept"] is True
    assert [argv[0] for argv in record_forks if str(adapter) in argv[0]] == [str(adapter)]
    assert [argv[:3] for argv in record_forks if argv[0] == "gh"] == [["gh", "api", "graphql"]], (
        "exactly one batched fetch per run -- never one per ref and never one per repository"
    )
    assert [s["source"] for s in swept_grid["sources"]] == ["probe"]


def test_local_forks_nothing_in_orchestrator_scope_and_only_the_slug_in_repository(isolated, monkeypatch, record_forks):
    """The strongest form of the opt-down: not one fork of any kind -- and in repository scope, one.

    Repository scope still runs ONE `git remote get-url` to learn its own `owner/repo`, because
    manifest selection cannot happen without it -- `--local` opts down from the network, not from the
    filesystem. Orchestrator scope needs no slug, so the opted-down path there touches no subprocess
    whatsoever, which is what pins that nothing else crept into it.

    THE REPOSITORY LEG IS ASSERTED AND NOT MERELY NARRATED, which is a correction. Its sentence sat
    in this docstring with no assertion under it while CLAUDE.md cited the sentence as a gate --
    deleting `manifest.shell.repository_slug`'s fork left the case green, because `record_forks == []`
    only ever ran in orchestrator scope. The exact-argv assertion is the gate: it names the one
    subprocess the opted-down repository path is allowed, so deleting the fork goes red (the slug
    disappears) and adding a second one goes red too.

    NEITHER LEG SEES `tmux list-windows`, and that is the fixture rather than the flag: `isolated`
    stubs `shell.live_windows`, so the reap overlay's fork is out of frame in both scopes. In
    production it runs in both and `--local` does not touch it -- `BORG_NO_REAP` is what removes it.

    A REAL, EXECUTABLE ADAPTER IS ON THE SEARCH PATH THROUGHOUT. Without it this assertion is
    vacuously true -- verified by mutation: with `--local` ignored entirely, an empty search path
    still forks nothing and the test stayed green. An assertion that cannot fail is not a gate.
    """
    dirs = _four_repository_registry(isolated)
    adapters = isolated / "adapters"
    _adapter(adapters, "probe", 'echo \'{"source":"probe","summary":"ok","items":[]}\'')
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", str(adapters))
    workspace = isolated / "ws"
    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", str(workspace))
    monkeypatch.chdir(workspace)

    cli._document("", False, "json", local=True)

    assert record_forks == []

    record_forks.clear()
    monkeypatch.chdir(dirs["delta"])

    document = cli._document("", False, "json", local=True)

    assert record_forks == [["git", "-C", dirs["delta"], "remote", "get-url", "origin"]]
    assert [m["id"] for m in document["grid"]["manifests"]] == ["cross-repository"], (
        "the slug is what selects; a leg that selected nothing would pass the fork assertion for the wrong reason"
    )


# ── the resolve ladder ────────────────────────────────────────────────────────────────────────────


def test_a_declared_status_outside_the_three_state_tokens_resolves_to_unknown():
    """`stacked` is authoring vocabulary, not a PR state, and the live viz manifest carries it.

    Promoting it would put `stacked` in the same field a renderer reads `merged` from, and every
    downstream state glyph would need a branch for a word that describes a position in a stack. The
    honest answer is `unknown` when nobody has looked.

    `unknown` IS STILL REACHABLE AFTER AC3 AND MUST STAY SO. The fetch resolves refs, it does not
    abolish the rung: a `gh` that is missing, offline, unauthenticated or past its deadline leaves
    the map empty, and a node whose declared status is `stacked` then has no answer at all. A build
    that deleted the bottom rung would satisfy AC3's headline assertion by lying.
    """
    assert link_grid.resolve_state("o/r#1", "stacked", {}, {}) == ("unknown", "unknown")
    assert link_grid.resolve_state("o/r#1", "merged", {}, {}) == ("merged", "declared")
    assert link_grid.resolve_state("o/r#1", "MERGED", {}, {}) == ("merged", "declared")
    assert link_grid.resolve_state("o/r#1", "", {}, {}) == ("unknown", "unknown")
    assert link_grid.resolve_state("o/r#1", None, {}, {}) == ("unknown", "unknown")


def test_a_swept_state_beats_a_declared_one_and_is_taken_verbatim():
    """Swept > declared, and the swept token is NOT filtered against the three github states.

    A source adapter owns its own vocabulary: an injected Jira adapter emits its own tokens, and
    coercing those to `unknown` would discard the only real answer anyone has. A declared status is
    hand-typed in a schema-less field and is filtered. The asymmetry is the design.
    """
    items = {"o/r#1": {"ref": "o/r#1", "state": "merged"}, "o/r#2": {"ref": "o/r#2", "state": "in review"}}
    assert link_grid.resolve_state("o/r#1", "stacked", items, {}) == ("merged", "swept")
    assert link_grid.resolve_state("o/r#2", "merged", items, {}) == ("in review", "swept")


def test_the_fetched_rung_sits_between_swept_and_declared():
    """AC3's rung, trapped on BOTH sides -- which `any(. == "unknown")` cannot do on its own.

    ABOVE `declared`, because a hand-authored status can be months stale and a round trip cannot:
    `o/r#3` is declared `merged` and the wire says `open`, and `open`/`fetched` is the only outcome
    consistent with the rung being above.

    BELOW `swept`, because the sweep and the fetch are two round trips at two instants, and the
    sweep's answer is the one that also produced the item a renderer reads `title` and `changed`
    from. `o/r#1` has both, and `merged`/`swept` is the only outcome consistent with the rung being
    below. A `fetched` inserted in the wrong place fails exactly one of these two assertions.

    AND THE FETCHED TOKEN IS VERBATIM, like the swept one and unlike the declared one: `o/r#4` comes
    back `in review`, which is outside DECLARABLE_STATES, and filtering it would throw away the only
    answer anyone has for exactly the reason resolve_state's docstring gives for the swept rung.
    """
    items = {"o/r#1": {"ref": "o/r#1", "state": "merged"}}
    fetched = {
        "o/r#1": {"ref": "o/r#1", "state": "closed"},
        "o/r#2": {"ref": "o/r#2", "state": "merged"},
        "o/r#3": {"ref": "o/r#3", "state": "open"},
        "o/r#4": {"ref": "o/r#4", "state": "in review"},
    }
    assert link_grid.resolve_state("o/r#1", "open", items, fetched) == ("merged", "swept")
    assert link_grid.resolve_state("o/r#2", "stacked", items, fetched) == ("merged", "fetched")
    assert link_grid.resolve_state("o/r#3", "merged", items, fetched) == ("open", "fetched")
    assert link_grid.resolve_state("o/r#4", "merged", items, fetched) == ("in review", "fetched")
    # An entry the fetch could not answer for is absent from the map, not present-and-empty, so the
    # rung below still runs. Both shapes are covered because replayed_items drops stateless nodes
    # while a hand-edited map may not.
    assert link_grid.resolve_state("o/r#5", "merged", items, fetched) == ("merged", "declared")
    assert link_grid.resolve_state("o/r#6", "merged", items, {"o/r#6": {}}) == ("merged", "declared")
    assert link_grid.resolve_state("o/r#7", "stacked", items, {"o/r#7": "not a dict"}) == ("unknown", "unknown")


def test_refs_are_matched_exactly_with_no_normalization():
    """No case fold, no `.git` handling, no rewriting -- see manifest.core.parse_ref for the argument.

    A normalizing join never raises; it just produces a ref that matches no item, and the node renders
    `unknown` forever. That silence is why this is pinned rather than trusted, and it binds the
    FETCHED map exactly as it binds the swept one -- fetched_items keys on the ref the caller asked
    with rather than on a slug rebuilt from parse_ref's parts, for this reason.
    """
    items = {"Owner/Repo#1": {"state": "merged"}}
    assert link_grid.resolve_state("owner/repo#1", "stacked", items, {}) == ("unknown", "unknown")
    assert link_grid.resolve_state("Owner/Repo#1", "stacked", items, {}) == ("merged", "swept")
    fetched = {"Owner/Repo#2": {"state": "open"}}
    assert link_grid.resolve_state("owner/repo#2", "stacked", {}, fetched) == ("unknown", "unknown")
    assert link_grid.resolve_state("Owner/Repo#2", "stacked", {}, fetched) == ("open", "fetched")


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

    An exception on the sweep path costs the WHOLE document -- `_grid` completes before a byte is
    rendered -- so one dead adapter would take out `▸ IN FOCUS`, `▸ QUEUED` and `▸ SHIPPED` too. A
    named warning on a degraded grid keeps the other six sections. (The reason given here used to be
    "every consumer of `borg link` swallows failure (`cmd_watch`'s `|| true`, `drone status`'s
    `|| true`, fzf's preview pane)"; all three were retired 2026-08-27. See link/shell.py's header.)
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


def test_the_fetch_fixture_short_circuits_before_any_gh_and_reaches_the_nodes(isolated, monkeypatch, record_forks):
    """BORG_LINK_FETCH_FIXTURE stands in for the round trip: recorded states reach nodes, nothing forks.

    THIS REPLACES `test_the_fetch_fixture_name_is_reserved_and_deliberately_unimplemented`, and the
    replacement is not optional. That tripwire asserted
    `"BORG_LINK_FETCH_FIXTURE" not in link_shell.sweep.__code__.co_consts` -- it inspected `sweep`,
    on the premise that the fetch's reader would land there. B4 forces the fetch to START BEFORE the
    fan-out, so the reader lives in `start_fetch`, a DIFFERENT function, and the old assertion would
    have stayed TRUE and silently vacuous rather than flipping red. Deleting it without a successor
    would have removed the only mechanical check that the seam exists where its contract says.

    A REAL `gh` IS ON PATH THROUGHOUT and writes a sentinel if it executes. Without that, "no fork"
    is true because there was nothing to fork.
    """
    dirs = _four_repository_registry(isolated)
    sentinel = isolated / "gh-ran"
    fake_gh = _fake_gh(isolated / "fakebin", f'touch "{sentinel}"; printf \'{{"data":{{}}}}\'')
    monkeypatch.setenv("PATH", f"{fake_gh.parent}:{os.environ['PATH']}")

    fixture = isolated / "fetch.json"
    fixture.write_text(
        json.dumps(
            {
                "nodes": {
                    "testorg/alpha#11": {"state": "CLOSED", "title": "recorded alpha"},
                    "testorg/delta#44": {"state": "merged", "title": "recorded delta"},
                    "testorg/charlie#33": {"title": "no state, so no answer"},
                }
            }
        ),
        encoding="utf-8",
    )
    monkeypatch.setenv("BORG_LINK_FETCH_FIXTURE", str(fixture))
    monkeypatch.chdir(dirs["delta"])

    grid = cli._document("", False, "json", local=False)["grid"]
    nodes = grid["manifests"][0]["nodes"]

    assert not sentinel.exists(), "the fixture seam must short-circuit BEFORE any gh is exec'd"
    assert [argv for argv in record_forks if argv[0] == "gh"] == []
    # `stacked` is outside DECLARABLE_STATES, so before the rung existed this node rendered `unknown`.
    assert (nodes["testorg/delta#44"]["state"], nodes["testorg/delta#44"]["state_source"]) == ("merged", "fetched")
    assert nodes["testorg/delta#44"]["title"] == "recorded delta"
    # A recorded state overrides a STALE declared one, and is lowercased on the way in so a node the
    # fetch answered and a node the sweep answered carry the same token.
    assert (nodes["testorg/alpha#11"]["state"], nodes["testorg/alpha#11"]["state_source"]) == ("closed", "fetched")
    # A recorded entry with no usable state is dropped rather than half-merged, so the rung below
    # still runs; and a ref the recording omits entirely keeps its declaration too.
    assert nodes["testorg/charlie#33"]["state_source"] == "declared"
    assert nodes["testorg/bravo#22"]["state_source"] == "declared"
    # The recording answers 2 of the 4 declared refs (bravo has no entry at all; charlie's entry
    # carries no usable state) -- so this must report `degraded` against the REAL declared count,
    # not `ok` against however many answers happen to be in the recording. Before this fix,
    # `_read_fetch_fixture` measured itself against `len(items)`, which can never be less than
    # itself, so a holed recording was ALWAYS reported as a complete answer.
    assert grid["fetch"] == {"attempted": True, "status": "degraded", "requested": 4, "resolved": 2}
    assert any("replayed from fixture" in w for w in grid["warnings"]), "a replayed fetch must say it was replayed"
    assert any("2 of 4 declared ref(s) did not resolve" in w for w in grid["warnings"]), (
        "a replayed fetch with holes must say so, the same as a live one -- see"
        " test_gh_exiting_non_zero_with_usable_data_still_resolves_every_valid_sibling"
    )
    # THE SUCCESSOR TO THE DELETED TRIPWIRE: the seam is read where the contract says it is, in the
    # shell tier, in the function that starts the fetch -- not in `sweep`, and not in grid.py, which
    # pylint holds to the Domain purity rules.
    from borg_core.link import shell as link_shell  # noqa: PLC0415

    assert "BORG_LINK_FETCH_FIXTURE" in link_shell.start_fetch.__code__.co_consts
    assert "BORG_LINK_FETCH_FIXTURE" in link_shell.sweep.__doc__, "and sweep's docstring still points at it"


def test_an_unreadable_fetch_fixture_warns_instead_of_raising(isolated, monkeypatch):
    """Mirrors `test_an_unreadable_sweep_fixture_warns_instead_of_raising` exactly. A harness that
    mistypes the path must see WHY, not see a declared-only grid it mistakes for a correct one."""
    dirs = _four_repository_registry(isolated)
    monkeypatch.setenv("BORG_LINK_FETCH_FIXTURE", str(isolated / "does-not-exist.json"))
    monkeypatch.chdir(dirs["delta"])

    grid = cli._document("", False, "json", local=False)["grid"]

    assert grid["fetch"]["attempted"] is False
    assert any(w.startswith("fetch: fixture ") and "unreadable or invalid JSON" in w for w in grid["warnings"])
    assert [m["id"] for m in grid["manifests"]] == ["cross-repository"], "the grid still renders"


@pytest.mark.parametrize(
    "body,expected",
    [
        ('["a list, not an object"]', "is not an object"),
        ('{"nodes": "not an object"}', "replayed from fixture"),
    ],
    ids=["non-object-root", "nodes-of-the-wrong-type"],
)
def test_a_wrongly_shaped_fetch_fixture_degrades_without_raising(isolated, monkeypatch, body, expected):
    """The same three rungs `_read_sweep_fixture` has, in the same order, for the same reason.

    A `nodes` of the wrong type is coerced to empty but STILL reports itself replayed -- the truthful
    reading of a recording that carries no answers -- while a root that is not an object is a harness
    defect and says so.
    """
    dirs = _four_repository_registry(isolated)
    fixture = isolated / "fetch.json"
    fixture.write_text(body, encoding="utf-8")
    monkeypatch.setenv("BORG_LINK_FETCH_FIXTURE", str(fixture))
    monkeypatch.chdir(dirs["delta"])

    grid = cli._document("", False, "json", local=False)["grid"]

    assert any(expected in w for w in grid["warnings"])
    assert grid["fetch"]["resolved"] == 0
    assert [m["id"] for m in grid["manifests"]] == ["cross-repository"]


def test_the_fetch_budget_is_configurable_and_survives_an_empty_value(isolated, monkeypatch):
    """Same three-way guard as sweep_timeout, and it is not shared with it.

    Unset OR EMPTY OR non-numeric takes the default, because `_borg_py` passes its whole config
    surface through by name and an unset variable arrives as the EMPTY STRING -- `float("")` is the
    ValueError that makes recon's readers unsafe to add to that wrapper. The two budgets are separate
    variables because the sweep and the fetch are different round trips; moving one must not move the
    other.
    """
    from borg_core.link import shell as link_shell  # noqa: PLC0415

    assert link_shell.fetch_timeout() == link_shell.DEFAULT_FETCH_TIMEOUT_SECONDS
    monkeypatch.setenv("BORG_LINK_FETCH_TIMEOUT", "2.5")
    assert link_shell.fetch_timeout() == 2.5
    assert link_shell.sweep_timeout() == link_shell.DEFAULT_SWEEP_TIMEOUT_SECONDS, "one budget must not move the other"
    monkeypatch.setenv("BORG_LINK_FETCH_TIMEOUT", "")
    assert link_shell.fetch_timeout() == link_shell.DEFAULT_FETCH_TIMEOUT_SECONDS
    monkeypatch.setenv("BORG_LINK_FETCH_TIMEOUT", "shortly")
    assert link_shell.fetch_timeout() == link_shell.DEFAULT_FETCH_TIMEOUT_SECONDS
    assert isolated  # the fixture's env isolation is what makes the unset default meaningful


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
    # THE SWEEP CONTRIBUTED NO WARNING, stated exactly rather than as `== []`. The first entry is
    # the harness's OWN neutralized fetch replay (see `isolated`); the second is that same replay
    # now correctly measured against the real declared-ref count (4) rather than against the
    # recording's own item count (0) -- the neutral fixture answers none of the four, and after
    # the fix that degrade is named instead of silently reported `ok`. Spelling both out exactly is
    # what keeps this from being loosened to an `any()` that would stop noticing a sweep warning.
    assert grid["warnings"] == [
        _replayed_fetch_warning(isolated),
        "fetch: 4 of 4 declared ref(s) did not resolve (deleted, renamed, or not visible)"
        " -- they fall back to what the manifest declares",
    ]
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
    _adapter(
        adapters, "probe", f'printf "%s\\n" "$*" > "{seen}"; echo \'{{"source":"probe","summary":"x","items":[]}}\''
    )
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


# ── AC3: B5, the payload that arrives with a non-zero exit ────────────────────────────────────────


def _gh_on_path(isolated, monkeypatch, body: str) -> Path:
    """A real `gh` on PATH with the fetch seam OPEN. Both halves are required.

    `isolated` neutralizes BORG_LINK_FETCH_FIXTURE for the whole file, so every case that means to
    exercise the real fetch has to delenv it -- otherwise it replays an empty recording and asserts
    nothing about the code path it names.
    """
    monkeypatch.delenv("BORG_LINK_FETCH_FIXTURE")
    fake = _fake_gh(isolated / "fakebin", body)
    monkeypatch.setenv("PATH", f"{fake.parent}:{os.environ['PATH']}")
    return fake


def test_gh_exiting_non_zero_with_usable_data_still_resolves_every_valid_sibling(isolated, monkeypatch):
    """B5. `gh api graphql` exits 1 whenever the response carries errors[], even when `data` is fully
    populated for every other alias.

    Code that reads `returncode != 0` as total failure discards a good fetch over one dead ref and
    renders exactly the `unknown` AC3 forbids. Measured live: a batch with one bogus repository and
    one bogus number exited 1, printed its `Could not resolve...` lines to STDERR (which proc.py
    already discards), and still carried both valid siblings in `data`.

    THE TWO DEAD ALIASES ARE PER-NODE CASUALTIES, NOT A PER-QUERY FAILURE: each falls to the rung
    below and neither touches its siblings. `errors[]` is never consulted for control flow.
    """
    dirs = _four_repository_registry(isolated)
    _gh_on_path(isolated, monkeypatch, f"printf '%s' '{_B5_PAYLOAD}'; exit 1")
    monkeypatch.chdir(dirs["delta"])

    grid = cli._document("", False, "json", local=False)["grid"]
    nodes = grid["manifests"][0]["nodes"]

    assert (nodes["testorg/alpha#11"]["state"], nodes["testorg/alpha#11"]["state_source"]) == ("merged", "fetched")
    # An ISSUE, whose state arrives under the `issueState:` alias the query is obliged to give it.
    # Without that alias GitHub rejects the whole DOCUMENT and every node here would be lost.
    assert (nodes["testorg/delta#44"]["state"], nodes["testorg/delta#44"]["state_source"]) == ("open", "fetched")
    # The title arrives with the state, exactly as it does on the swept rung -- a manifest row has no
    # title field at all, so this cannot have come from the declaration.
    assert nodes["testorg/delta#44"]["title"] == "delta forty-four"
    assert nodes["testorg/bravo#22"]["state_source"] == "declared", "a dead ref nulls its own inner field only"
    assert nodes["testorg/charlie#33"]["state_source"] == "declared", "a dead repository nulls the whole alias"
    assert grid["fetch"] == {"attempted": True, "status": "degraded", "requested": 4, "resolved": 2}
    assert any("2 of 4 declared ref(s) did not resolve" in w for w in grid["warnings"]), (
        "a fetch that came back with holes must say so; a quiet one is indistinguishable from a full answer"
    )
    assert grid["declared"] == 4 and grid["unresolved"] == 2


@pytest.mark.parametrize(
    "body",
    [
        "printf ''",
        "printf 'not json at all'",
        """printf '{"data":null,"errors":[{"type":"RATE_LIMITED"}]}'""",
        """printf '{"message":"Bad credentials","status":"401"}'""",
    ],
    ids=["empty-stdout", "unparseable", "null-data", "bad-credentials"],
)
def test_only_an_unusable_payload_is_a_total_fetch_failure(isolated, monkeypatch, body):
    """The other side of B5's rule, and `bad-credentials` is the one that ships silent.

    Measured: an unauthenticated `gh` exits 1 with stdout `{"message":"Bad credentials",...}`, which
    is VALID JSON with no `data` -- so "json.loads succeeded" is not success, and without the
    `has("data") and (.data != null)` test zero refs merge, zero warnings emit, and the grid looks
    exactly like a fetch that found nothing. Offline is the empty-stdout case, measured at 0.056s
    with the message on stderr. Each must degrade to the declared rung with a NAMED warning rather
    than to a confidently empty grid.
    """
    dirs = _four_repository_registry(isolated)
    _gh_on_path(isolated, monkeypatch, f"{body}; exit 1")
    monkeypatch.chdir(dirs["delta"])

    grid = cli._document("", False, "json", local=False)["grid"]

    assert grid["manifests"][0]["nodes"]["testorg/alpha#11"]["state_source"] == "declared"
    assert grid["fetch"] == {"attempted": True, "status": "failed", "requested": 4, "resolved": 0}
    assert any("no usable answer" in w for w in grid["warnings"]), grid["warnings"]
    assert [m["id"] for m in grid["manifests"]] == ["cross-repository"], "the grid still renders"


def test_a_missing_gh_is_a_named_warning_and_not_a_blank_grid(isolated, monkeypatch):
    """`gh` absent is the modal state on a fresh machine and on CI. proc.run_background returns None,
    which must read as "I could not look" rather than as "I looked and found nothing"."""
    dirs = _four_repository_registry(isolated)
    monkeypatch.delenv("BORG_LINK_FETCH_FIXTURE")
    # A PATH with `git` on it and `gh` off it. Emptying PATH outright would also remove `git`, and
    # then repository_slug returns "" and selection renders an EMPTY grid -- which passes the fetch
    # assertions below for entirely the wrong reason.
    no_gh_bin = isolated / "no-gh-bin"
    no_gh_bin.mkdir()
    (no_gh_bin / "git").symlink_to(shutil.which("git"))
    monkeypatch.setenv("PATH", str(no_gh_bin))
    monkeypatch.chdir(dirs["delta"])

    grid = cli._document("", False, "json", local=True)["grid"]

    assert grid["fetch"] == {"attempted": False, "status": "skipped", "requested": 0, "resolved": 0}
    assert [m["id"] for m in grid["manifests"]] == ["cross-repository"]
    # And with the network arm live, the same absence is NAMED rather than silent.
    grid = cli._document("", False, "json", local=False)["grid"]
    assert grid["fetch"] == {"attempted": False, "status": "skipped", "requested": 4, "resolved": 0}
    assert any("gh is not installed" in w for w in grid["warnings"]), grid["warnings"]


def test_a_manifest_declaring_no_ref_spawns_nothing_at_all(isolated, monkeypatch, record_forks):
    """NO REFS MEANS NO SUBPROCESS, and this rule is what keeps every fixture registry fork-free.

    A sandbox with no `.borg/programs` declares nothing, and a fetch that spawned `gh` anyway would
    put a network round trip on ~46 existing bats link cases and on every `borg link` run in a
    repository that has not adopted a manifest yet.
    """
    repository = _git_repository(isolated / "ws" / "juliet", "testorg/juliet")
    _write_registry(isolated, {"juliet": {"path": repository, "status": "idle"}})
    _gh_on_path(isolated, monkeypatch, "printf 'should never run'")
    monkeypatch.chdir(repository)

    grid = cli._document("", False, "json", local=False)["grid"]

    assert [argv for argv in record_forks if argv[0] == "gh"] == []
    assert grid["fetch"] == {"attempted": False, "status": "skipped", "requested": 0, "resolved": 0}
    assert not any(w.startswith("fetch:") for w in grid["warnings"]), "nothing to ask about is not a degradation"


# ── AC3: B4, the deadline is on the WORK and the process exits ────────────────────────────────────


def _cli_subprocess(cwd, env_overrides, timeout=60):
    """Run the REAL entrypoint in a REAL interpreter and time it TO EXIT. See the B4 case for why."""
    env = {k: v for k, v in os.environ.items() if not k.startswith("BORG_")}
    env["PYTHONPATH"] = str(Path(cli.__file__).resolve().parents[2])
    env.update(env_overrides)
    started = time.monotonic()
    done = subprocess.run(
        [sys.executable, "-m", "borg_core.link.cli", "--json"],
        cwd=str(cwd),
        env=env,
        capture_output=True,
        text=True,
        check=False,
        timeout=timeout,
    )
    return done, time.monotonic() - started


def test_a_hanging_gh_does_not_hold_the_process_open_past_the_fetch_deadline(isolated):
    """B4, measured the ONLY way that can see it: total wall clock of a real interpreter, TO EXIT.

    AN IN-PROCESS ASSERTION AROUND cli._document CANNOT CATCH THIS BUG and must never be mistaken for
    a test of it. Reproduced on this machine: a ThreadPoolExecutor worker running `sleep 12` under
    `.result(timeout=2)` with `shutdown(wait=False)` printed at 2.01s and the PROCESS exited at
    12.085s. `concurrent.futures.thread`'s atexit hook joins the non-daemon worker at INTERPRETER
    SHUTDOWN -- which never happens inside a pytest process, so an in-process elapsed check reads
    2.01s and passes with the bug fully present. The deadline is therefore asserted on subprocess
    exit, which is the atexit hook's other side.

    30s of `gh` against a 1s budget: a correct build exits near 1s, an executor build near 30s. The
    12s ceiling is the hardened spec's own number and sits between them with room on both sides, so
    this is not a benchmark of the runner.

    THE ADAPTER PATH IS STARVED ON PURPOSE so the only thing being timed is the fetch. What the sweep
    does with a hung adapter is already pinned by
    `test_a_hanging_adapter_is_killed_at_the_deadline_and_the_process_moves_on`.
    """
    dirs = _four_repository_registry(isolated)
    fake_gh = _fake_gh(isolated / "fakebin", "sleep 30")

    env = {
        "PATH": f"{fake_gh.parent}:{os.environ['PATH']}",
        "BORG_DIR": str(isolated / "borg-dir"),
        "BORG_RECON_ADAPTER_PATH": str(isolated / "no-adapters"),
        "BORG_LINK_FETCH_TIMEOUT": "1",
    }
    done, elapsed = _cli_subprocess(dirs["delta"], env)

    assert elapsed < 12, (
        f"the interpreter took {elapsed:.1f}s to EXIT against a 1s fetch budget and a 30s gh -- "
        "the deadline is on the future rather than on the work (B4)"
    )
    assert done.returncode == 0, done.stderr
    grid = json.loads(done.stdout)["grid"]
    # DEGRADED DOWN THE LADDER, NOT BLANK: the declared rung still answers and the miss is NAMED. A
    # build that swallowed the deadline would produce an all-unknown grid with zero warnings, which
    # is the silent-blindness shape CLAUDE.md records three incidents of.
    assert grid["manifests"][0]["nodes"]["testorg/alpha#11"]["state_source"] == "declared"
    assert grid["fetch"]["status"] == "failed"
    assert any("did not answer within 1s" in w for w in grid["warnings"]), grid["warnings"]


def test_the_fetch_deadline_case_is_not_measuring_a_fetch_that_never_ran(isolated):
    """THE CONTROL FOR B4. Identical fixture, a `gh` that answers instantly.

    Without it the case above is green on a build where the fetch is never started at all -- same
    elapsed, same `declared` fallback -- and only the outcome distinguishes them.
    """
    dirs = _four_repository_registry(isolated)
    fake_gh = _fake_gh(isolated / "fakebin", f"printf '%s' '{_B5_PAYLOAD}'; exit 1")

    env = {
        "PATH": f"{fake_gh.parent}:{os.environ['PATH']}",
        "BORG_DIR": str(isolated / "borg-dir"),
        "BORG_RECON_ADAPTER_PATH": str(isolated / "no-adapters"),
        "BORG_LINK_FETCH_TIMEOUT": "1",
    }
    done, elapsed = _cli_subprocess(dirs["delta"], env)

    assert elapsed < 12
    assert done.returncode == 0, done.stderr
    grid = json.loads(done.stdout)["grid"]
    assert grid["manifests"][0]["nodes"]["testorg/alpha#11"]["state_source"] == "fetched"
    assert grid["fetch"]["resolved"] == 2


def test_the_fetch_budget_is_charged_from_the_start_and_not_from_the_collect(isolated, monkeypatch):
    """THE DEADLINE IS MONOTONIC AND SET AT THE SPAWN, so the fan-out's elapsed time is charged
    AGAINST the fetch's budget rather than added to it.

    A 2s adapter and a `gh` that never answers, under a 2s fetch budget. Charged from the start, the
    deadline expires 2s after the spawn and the whole call returns at ~2s. Handed a fixed
    `timeout=fetch_timeout()` at collect time instead -- which is the natural mistake, and which
    changes no output whatsoever -- the two budgets stack and it returns at ~4s. On the real command
    that is the difference between AC1's 2.7s and a front door that sits for the sweep's budget plus
    the fetch's, and every OTHER case in this file runs against a fast mock where the two are
    indistinguishable.

    MEASURED WITH THE MUTATION APPLIED, which is the only reason this ceiling is trustworthy:
    `remaining = pending["budget"]` produced 7.16s against a 3s fan-out and a 4s budget where the
    correct arithmetic gives ~4s. Nothing in the suite noticed until this case existed.

    IN-PROCESS IS SOUND HERE AND IS NOT FOR B4. What is being measured is arithmetic on the collect
    deadline, which is complete before the call returns. B4's hazard is a non-daemon thread joined at
    INTERPRETER SHUTDOWN, which never happens inside pytest -- that is why its case is a subprocess
    timed to exit and this one is not.
    """
    dirs = _four_repository_registry(isolated)
    adapters = isolated / "adapters"
    _adapter(adapters, "probe", 'sleep 2; echo \'{"source":"probe","summary":"ok","items":[]}\'')
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", str(adapters))
    _gh_on_path(isolated, monkeypatch, "sleep 30")
    monkeypatch.setenv("BORG_LINK_FETCH_TIMEOUT", "2")
    monkeypatch.chdir(dirs["delta"])

    started = time.monotonic()
    grid = cli._document("", False, "json", local=False)["grid"]
    elapsed = time.monotonic() - started

    assert [s["status"] for s in grid["sources"]] == ["ok"], "the adapter really did take its 2s"
    assert grid["fetch"]["status"] == "failed", "and the fetch really did hit its deadline"
    assert elapsed < 3.4, (
        f"took {elapsed:.2f}s for a 2s fan-out under a 2s fetch budget -- the budget is being started "
        "at the collect instead of at the spawn, so the two stack"
    )


def test_the_fetch_overlaps_the_fan_out_rather_than_adding_to_it(isolated, monkeypatch):
    """The whole reason the run is split into start/collect: the round trip is absorbed, not added.

    A `gh` that takes 1.5s and an adapter that takes 1.5s. Serialized that is >=3s; overlapped it is
    ~1.5s. The 2.6s ceiling sits between them with room on both sides, so this is a structural
    assertion rather than a benchmark -- and it is the one thing that would notice `start_fetch`
    being quietly moved below the fan-out, which changes no output at all.
    """
    dirs = _four_repository_registry(isolated)
    adapters = isolated / "adapters"
    _adapter(adapters, "probe", 'sleep 1.5; echo \'{"source":"probe","summary":"ok","items":[]}\'')
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", str(adapters))
    _gh_on_path(isolated, monkeypatch, f"sleep 1.5; printf '%s' '{_B5_PAYLOAD}'; exit 1")
    monkeypatch.chdir(dirs["delta"])

    started = time.monotonic()
    grid = cli._document("", False, "json", local=False)["grid"]
    elapsed = time.monotonic() - started

    assert grid["fetch"]["resolved"] == 2, "the fetch really did answer, so there was something to overlap"
    assert [s["status"] for s in grid["sources"]] == ["ok"], "and so did the adapter"
    assert elapsed < 2.6, f"took {elapsed:.2f}s for two 1.5s round trips -- the fetch is serialized behind the sweep"


# ── AC3: the query builder and the response parser, pure ─────────────────────────────────────────


def test_the_query_asks_issueOrPullRequest_and_aliases_the_issue_state():
    """Two properties of the document, each invisible until a manifest nobody has written yet.

    `issueOrPullRequest` AND NOT `pullRequest`: `apex.ref` is a tracker ISSUE, manifest.core allows
    one and declared_refs includes it. Both live manifests happen to have no apex, so a PR-only query
    is green on every current fixture and renders `unknown` forever the first time a tracker is
    declared.

    `issueState: state` IS SPEC-CORRECTNESS RATHER THAN NECESSITY, and this docstring says so because
    the opposite was asserted when the alias was specified. The claim was that GitHub rejects the
    whole document without it (two different enums under one response name, which the spec's
    SameResponseShape rule forbids). MEASURED LIVE against a batch carrying a real Issue and a real
    PullRequest: GitHub accepts BOTH forms. The alias is kept because the query is spec-valid with it
    and merely tolerated without it -- and fetched_items reads `state` first and `issueState` second,
    so the parser is correct either way. This assertion pins the form; the parser's own case pins the
    behaviour that would actually break.
    """
    query, aliases, warnings = link_grid.fetch_query(["o/r#1", "other/repo#12"])

    assert warnings == []
    assert aliases == {"n0": "o/r#1", "n1": "other/repo#12"}
    assert 'n0: repository(owner: "o", name: "r") { issueOrPullRequest(number: 1)' in query
    assert 'n1: repository(owner: "other", name: "repo") { issueOrPullRequest(number: 12)' in query
    assert "issueState: state" in query
    assert "pullRequests(first:" not in query, "that is the SWEEP's query; the two must stay distinguishable"
    assert query.startswith("query { ") and query.endswith(" }")
    # BYTE-IDENTICAL FOR THE SAME INPUT. declared_refs sorts, so a manifest with its rows reordered
    # produces the same document -- which is what makes a recorded fixture or a diffed log worth
    # anything, and what lets a mock `gh` map n0..nN back to refs deterministically.
    assert link_grid.fetch_query(["o/r#1", "other/repo#12"])[0] == query


def test_a_ref_that_cannot_go_into_the_query_is_excluded_and_named():
    """A zero-padded number KILLS THE WHOLE BATCH, and the naive degrade misdiagnoses it.

    Measured: `issueOrPullRequest(number: 0158)` returns
    `{"errors":[{"message":"Expected NAME, actual: INT (\\"158\\")"}]}` with NO `data` key at all -- so
    one padded ref anywhere in a selected manifest turns the fetch into total failure for every other
    ref, and the caller then reports "gh returned no usable answer", which is a wrong diagnosis
    rather than a missing one. `_REF_RE` accepts `#0158` and parse_ref returns the digits verbatim by
    design, so the exclusion has to happen here.

    A ref that is not `owner/repo#number` at all is the same class: parse_ref is the injection gate,
    and anything it rejects must never reach the query body.
    """
    query, aliases, warnings = link_grid.fetch_query(["o/r#0158", "PROJ-123", "o/r#7", "a/b/c#1", "o/r#0"])

    assert aliases == {"n0": "o/r#7", "n1": "o/r#0"}, "aliases are dense over the SURVIVORS, never sparse"
    assert "0158" not in query and "PROJ-123" not in query
    # `PROJ-123` IS EXCLUDED SILENTLY AND THE SILENCE IS ASSERTED. Since 2026-09-01 it is a valid
    # Jira row, not a malformed GitHub one, so its absence from a GITHUB query is correct rather than
    # a degradation -- warning would put a line in `▸ SIGNALS` on every render of every chain that
    # carries a ticket or a doc, which is how a reader learns to skip the section. The other two
    # still warn for opposite reasons: `o/r#0158` IS github-kind and would take the whole batch down,
    # and `a/b/c#1` matches no vocabulary at all, so it is a defect that should never have validated
    # and must not be hidden twice.
    assert sorted(warnings) == sorted(
        [
            "fetch: ref o/r#0158 is not a fetchable owner/repo#number -- excluded from the fetch",
            "fetch: ref a/b/c#1 is not a fetchable owner/repo#number -- excluded from the fetch",
        ]
    )
    assert not any("PROJ-123" in w for w in warnings), "a valid jira row is not a fetch problem"
    assert not any("notion" in w for w in link_grid.fetch_query(["https://notion.so/x"])[2])
    # Nothing fetchable means no query at all, so start_fetch has nothing to spawn.
    assert link_grid.fetch_query(["PROJ-123"])[0] == ""
    assert link_grid.fetch_query([]) == ("", {}, [])


def test_a_ref_number_past_the_int_parse_limit_is_excluded_not_fatal():
    """`int(number)` on a ref whose digit string exceeds Python's ~4300-digit integer-parse limit
    raises ValueError, which would escape `_fetchable` and take down the module's "nothing in the
    grid path is ever fatal" contract as a blank frame. It must take the same excluded-and-named
    path a zero-padded ref already takes.
    """
    absurd = "9" * 5000
    query, aliases, warnings = link_grid.fetch_query([f"o/r#{absurd}", "o/r#7"])

    assert aliases == {"n0": "o/r#7"}
    assert warnings == [f"fetch: ref o/r#{absurd} is not a fetchable owner/repo#number -- excluded from the fetch"]
    assert absurd not in query


def test_the_parser_survives_both_null_shapes_and_ignores_errors_for_control_flow():
    """`data[alias]["issueOrPullRequest"]` raises TypeError on a null ALIAS, and that is routine.

    A renamed, deleted or private repository nulls the whole alias; a dead issue or PR nulls only the
    inner field. Both arrive per-node beside fully-resolved siblings. An exception here escapes a
    module whose header promises nothing in the grid path is ever fatal, and cli.main's broad catch
    turns it into exit 1 with zero bytes on stdout for every consumer that swallows failure.
    """
    payload = json.loads(_B5_PAYLOAD)
    aliases = {"n0": "testorg/alpha#11", "n1": "testorg/bravo#22", "n2": "testorg/charlie#33", "n3": "testorg/delta#44"}

    items = link_grid.fetched_items(payload, aliases)

    assert sorted(items) == ["testorg/alpha#11", "testorg/delta#44"]
    assert items["testorg/alpha#11"] == {
        "ref": "testorg/alpha#11",
        "state": "merged",
        "title": "alpha eleven",
        "draft": False,
    }
    # AC4/A8, the live-parser half. `isDraft` was selected by _FETCH_NODE since AC3 and DISCARDED
    # here, which is why picture.GLYPH_DRAFT shipped dead-but-tested. MUTATION: drop the key from
    # fetched_items -> `draft` is absent and every draft PR is announced as ready.
    drafted = link_grid.fetched_items(
        {"data": {"n0": {"issueOrPullRequest": {"state": "OPEN", "isDraft": True, "title": "wip"}}}},
        {"n0": "o/r#9"},
    )
    assert drafted["o/r#9"]["draft"] is True
    assert items["testorg/delta#44"]["state"] == "open", "an Issue's state arrives under the issueState alias"
    # Exit status and errors[] are never consulted; a payload with no data at all is the only failure.
    assert link_grid.fetch_payload_is_usable(payload) is True
    assert link_grid.fetch_payload_is_usable({"data": {}}) is True
    assert link_grid.fetch_payload_is_usable({"data": None, "errors": [{"type": "RATE_LIMITED"}]}) is False
    assert link_grid.fetch_payload_is_usable({"message": "Bad credentials", "status": "401"}) is False
    assert link_grid.fetch_payload_is_usable("not a dict") is False
    assert link_grid.fetched_items({"data": "not an object"}, aliases) == {}
    assert (
        link_grid.fetched_items({"data": {"n0": {"issueOrPullRequest": {"title": "no state"}}}}, {"n0": "o/r#1"}) == {}
    )


def test_a_recording_with_unusable_entries_degrades_entry_by_entry():
    """A hand-edited recording is a harness artifact, and one bad entry must not cost the others.

    A blank key, a non-dict value and a value with no state each fall to the rung below rather than
    putting an empty token in a node's `state` -- which would render as a state glyph for a state
    nobody has.
    """
    assert link_grid.replayed_items(
        {
            "o/r#1": {"state": "OPEN", "title": "kept"},
            "  ": {"state": "open"},
            "o/r#2": "not a dict",
            "o/r#3": {"title": "no state"},
        }
    ) == {"o/r#1": {"ref": "o/r#1", "state": "open", "title": "kept", "draft": False}}
    assert link_grid.replayed_items("not an object") == {}
    assert link_grid.replayed_items(None) == {}

    # AC4/A8, the recording half. `isDraft` is carried, and ONLY a real boolean `true` sets it --
    # a recording is hand-edited, so the string "true" is the shape that actually shows up and it
    # must not light a glyph that claims live evidence. MUTATION: write `bool(node.get("isDraft"))`.
    drafts = link_grid.replayed_items(
        {
            "o/r#1": {"state": "open", "isDraft": True},
            "o/r#2": {"state": "open", "isDraft": "true"},
            "o/r#3": {"state": "open", "isDraft": False},
            "o/r#4": {"state": "open"},
        }
    )
    assert [drafts[f"o/r#{n}"]["draft"] for n in (1, 2, 3, 4)] == [True, False, False, False]


def test_a_ref_set_with_nothing_fetchable_spawns_nothing_and_says_why(isolated, monkeypatch, record_forks):
    """Every declared ref excluded means no query, and no query must mean no subprocess.

    A manifest whose only ref is zero-padded would otherwise spawn `gh` with an empty document. The
    exclusion is NAMED so the author can see which ref is unfetchable -- a silent drop looks exactly
    like a ref the fetch simply could not resolve, which is a different and much less actionable
    problem.
    """
    repository = _git_repository(isolated / "ws" / "kilo", "testorg/kilo")
    _write_manifest(
        repository,
        "padded",
        {"program": "padded", "rows": [{"order": "1", "ref": "testorg/kilo#007", "status": "stacked"}]},
    )
    _write_registry(isolated, {"kilo": {"path": repository, "status": "idle"}})
    _gh_on_path(isolated, monkeypatch, "printf 'should never run'")
    monkeypatch.chdir(repository)

    grid = cli._document("", False, "json", local=False)["grid"]

    assert [argv for argv in record_forks if argv[0] == "gh"] == []
    assert grid["fetch"] == {"attempted": False, "status": "skipped", "requested": 0, "resolved": 0}
    assert any("testorg/kilo#007 is not a fetchable" in w for w in grid["warnings"]), grid["warnings"]
    assert grid["manifests"][0]["nodes"]["testorg/kilo#007"]["state_source"] == "unknown"


def test_a_gh_that_never_answers_degrades_to_the_declared_rung_in_process(isolated, monkeypatch):
    """The deadline's IN-PROCESS half. Its subprocess sibling is what actually proves B4.

    `test_a_hanging_gh_does_not_hold_the_process_open_past_the_fetch_deadline` measures wall clock TO
    EXIT, which is the only way to see a leaked non-daemon join -- but it runs in a child
    interpreter, so nothing it executes is instrumented here. This case exists to put the degrade
    ITSELF under the same coverage floor as every other rung: the refs fall back, the miss is named,
    and the grid still renders.
    """
    dirs = _four_repository_registry(isolated)
    _gh_on_path(isolated, monkeypatch, "sleep 30")
    monkeypatch.setenv("BORG_LINK_FETCH_TIMEOUT", "0.4")
    monkeypatch.chdir(dirs["delta"])

    started = time.monotonic()
    grid = cli._document("", False, "json", local=False)["grid"]
    elapsed = time.monotonic() - started

    assert elapsed < 10, f"the 0.4s fetch budget did not reach the child ({elapsed:.1f}s)"
    assert grid["fetch"] == {"attempted": True, "status": "failed", "requested": 4, "resolved": 0}
    assert grid["manifests"][0]["nodes"]["testorg/alpha#11"]["state_source"] == "declared"
    assert any("did not answer within 0.4s" in w for w in grid["warnings"]), grid["warnings"]


def test_the_fetch_input_is_every_declared_ref_of_every_selected_manifest():
    """declared_refs, not row_refs, unioned across SELECTED manifests, deduplicated and sorted.

    An `after` entry and a `gate.blocked_by_ref` name work in another repository, which is precisely
    what falls outside the sweep window -- narrowing the fetch to rows would leave exactly the refs
    AC3 exists for unresolved. Sorting is what makes the alias numbering reproducible.
    """
    manifests = [
        {
            "rows": [
                {"order": "2", "ref": "o/r#2", "after": ["o/r#1"]},
                {"order": "1", "ref": "o/r#1", "gate": {"blocked_by_ref": "other/repo#9"}},
            ],
            "apex": {"ref": "o/r#100"},
        },
        {"rows": [{"order": "1", "ref": "o/r#2"}]},
    ]
    assert link_grid.selected_refs(manifests) == ["o/r#1", "o/r#100", "o/r#2", "other/repo#9"]
    assert link_grid.selected_refs([]) == []


def test_the_grid_carries_ready_but_still_no_duplicate_gate_list(isolated, monkeypatch):
    """`ready` ARRIVED IN AC4; `unmapped_gates` is still deliberately absent.

    This case used to assert `"ready" not in manifest`, pinning the deferral while AC3's `fetched`
    rung did not exist. The rung exists, `ready_refs` builds its state map from resolved nodes only,
    and the deferral is discharged -- so the assertion INVERTS rather than being deleted, which is
    what keeps it a record of why the key was withheld for two ACs.

    `unmapped_gates` stays off: it is a pure projection of `gates` minus one key, and emitting both
    puts a near-byte-for-byte second copy of every gate on the wire for a consumer that does not
    exist. (The old clause "on a wire `drone status` serializes once per tmux window" is dropped --
    that command was retired -- and the duplication argument never depended on it.)

    MUTATION: drop the `"ready"` key from grid_manifest -> the first assertion; add `unmapped_gates`
    -> the third. Asserted under `--local`, which is the case that matters: nothing resolves there,
    so `ready` must be present AND report `unlooked` rather than an empty list.
    """
    dirs = _four_repository_registry(isolated)
    monkeypatch.chdir(dirs["delta"])

    manifest = cli._document("", False, "json", local=True)["grid"]["manifests"][0]

    assert "ready" in manifest
    assert manifest["ready"]["state"] == link_grid.STATE_READY_UNLOOKED
    assert manifest["ready"]["refs"] == []
    assert "unmapped_gates" not in manifest
    assert "gates" in manifest


# ── AC4/S1: READY, and whether it is knowable ─────────────────────────────────────────────────────


def _chain_manifest() -> dict:
    """Parent `o/r#1`, child `o/r#2`, plus an independent draft `o/r#3`. The minimum shape that can
    tell the three READY decisions apart."""
    return {
        "program": "chain",
        "rows": [
            {"ref": "o/r#1", "order": "1", "lane": "L", "status": "merged"},
            {"ref": "o/r#2", "order": "2", "lane": "L", "after": ["o/r#1"], "status": "open"},
            {"ref": "o/r#3", "order": "3", "lane": "M", "status": "open"},
        ],
    }


def test_a_declared_merged_parent_does_not_make_its_child_ready():
    """A1, and the whole reason AC4 had a precondition.

    MUTATION: build `ready_refs`' state map from every node instead of the resolved ones. The child
    then enters READY on the strength of a hand-typed `"status": "merged"` that no sweep and no fetch
    ever saw, and `state_glyph` renders `●` -- "start this now" -- off it. Measured on the live
    ingle-t1-cutover manifest, that is 12 of 14 nodes.
    """
    declared_only = link_grid.grid_manifest(_chain_manifest(), {}, {})
    assert declared_only["nodes"]["o/r#1"]["state_source"] == link_grid.STATE_SOURCE_DECLARED
    assert declared_only["ready"]["state"] == link_grid.STATE_READY_UNLOOKED
    assert declared_only["ready"]["refs"] == []
    assert declared_only["nodes"]["o/r#2"]["ready"] is False

    # The SAME topology and the SAME states, resolved: now the child really is ready.
    swept = {"o/r#1": {"state": "merged"}, "o/r#2": {"state": "open"}, "o/r#3": {"state": "open"}}
    resolved = link_grid.grid_manifest(_chain_manifest(), swept, {})
    assert resolved["ready"]["state"] == link_grid.STATE_READY_KNOWN
    assert "o/r#2" in resolved["ready"]["refs"]
    assert resolved["nodes"]["o/r#2"]["ready"] is True


def test_nothing_ready_on_a_resolved_render_is_not_the_same_as_nobody_looking():
    """A3 + A2. The two non-populated states are DIFFERENT SENTENCES.

    MUTATION: return a bare list from `ready_refs`. Both cases below then read as `[]`, and a
    `--local` reader is told their board is clear when the truth is that nothing on the page was
    resolved -- the same trap SKILL.md records for `order: []` vs `total_projects`, and a direct
    contradiction of the `N of N declared refs unresolved — nobody looked` line SIGNALS already
    prints on that exact render.
    """
    # Resolved, and genuinely nothing is startable: every row has already merged, so nothing is open.
    done = {"o/r#1": {"state": "merged"}, "o/r#2": {"state": "merged"}, "o/r#3": {"state": "merged"}}
    known_empty = link_grid.grid_manifest(_chain_manifest(), done, {})
    assert known_empty["ready"]["state"] == link_grid.STATE_READY_KNOWN
    assert known_empty["ready"]["refs"] == []

    # Resolved, and the CHILD is held back by a parent that has not merged -- while the two rows with
    # no parent are ready. (An earlier draft of this case asserted only `o/r#3` here and was simply
    # wrong: `o/r#1` is parentless and open, so it is ready by definition. Kept as an assertion
    # rather than a comment so the distinction is executable.)
    blocked = {"o/r#1": {"state": "open"}, "o/r#2": {"state": "open"}, "o/r#3": {"state": "open"}}
    partial = link_grid.grid_manifest(_chain_manifest(), blocked, {})
    assert partial["ready"]["refs"] == ["o/r#1", "o/r#3"]
    assert partial["nodes"]["o/r#2"]["ready"] is False, "a child under an unmerged parent is not ready"

    unlooked = link_grid.grid_manifest(_chain_manifest(), {}, {})
    assert unlooked["ready"]["state"] == link_grid.STATE_READY_UNLOOKED
    assert unlooked["ready"]["refs"] == []
    # THE POINT OF THE CASE: these two carry an identical `refs`, and they are not the same fact.
    assert known_empty["ready"]["refs"] == unlooked["ready"]["refs"] == []
    assert known_empty["ready"]["state"] != unlooked["ready"]["state"]


def test_a_draft_pull_request_is_never_ready():
    """A8, the derivation half. MUTATION: drop the `draft` filter in `ready_refs`.

    `ready_set` compares against STATE_OPEN and a draft PR IS open in every vocabulary the adapters
    emit, so without the filter a draft is announced as startable. The filter lives in `ready_refs`
    rather than in `ready_set` because draft-ness is not part of the state vocabulary that function
    is written against -- its own docstring says a caller wanting to exclude drafts must do so on its
    own signal.
    """
    fetched = {"o/r#3": {"state": "open", "draft": True}}
    swept = {"o/r#1": {"state": "merged"}, "o/r#2": {"state": "open"}}
    block = link_grid.grid_manifest(_chain_manifest(), swept, fetched)

    assert block["nodes"]["o/r#3"]["draft"] is True
    assert block["nodes"]["o/r#3"]["state"] == "open", "draft-ness is orthogonal to the state token"
    assert "o/r#3" not in block["ready"]["refs"]
    assert block["nodes"]["o/r#3"]["ready"] is False
    assert "o/r#2" in block["ready"]["refs"], "the non-draft sibling is unaffected"


# ── AC2/S1: the topology keys the renderer reads ──────────────────────────────────────────────────
#
# THESE FOUR ARE THE WIRE CONTRACT FOR A RENDERER THAT DOES NOT EXIST YET, and that is deliberate
# sequencing rather than speculative generality. AC2's picture is a pure function of `parents`,
# `children` and `seq`; landing them first means the column algorithm can be written and tested
# against an oracle that predates the renderer, and means the commit that regenerates every golden
# adds no new derivation of its own. Each case names the mutation that turns it red, because the
# carried-forward finding from 2026-08-26 is that a check pointed at the wrong thing reads as a pass.


def _fork_manifest() -> dict:
    """One fork whose DECLARATION order and REF order disagree at every branch point.

    Built to discriminate, not to be realistic. `zzz#1` forks to `mmm#2` then `aaa#3`, which join at
    `r#4`; declaration order is zzz, mmm, aaa, r while ascending-ref order is aaa, mmm, r, zzz. So
    both `children` (of zzz#1) and `parents` (of r#4) come out in a DIFFERENT order under the two
    rules, which is what makes G4's mutation observable. A fixture whose two orders agree -- which
    both live manifests happen to be, one ref prefix at a time -- would pass either implementation.

    Every child declares `after`, so `_stacked_edges` contributes nothing (each consecutive child is
    in `declared_children`) and the edge set is exactly the four declared parents.
    """
    return {
        "program": "fork",
        "desc": "a fork whose declaration order and ref order disagree",
        "rows": [
            {"order": "1", "ref": "o/zzz#1", "lane": "L", "status": "merged"},
            {"order": "2", "ref": "o/mmm#2", "lane": "L", "after": ["o/zzz#1"], "status": "open"},
            {"order": "3", "ref": "o/aaa#3", "lane": "L", "after": ["o/zzz#1"], "status": "open"},
            {"order": "4", "ref": "o/r#4", "lane": "L", "after": ["o/mmm#2", "o/aaa#3"], "status": "open"},
        ],
    }


def test_every_node_carries_its_parents_children_and_seq(isolated, monkeypatch):
    """G1. Through cli._document, not grid_manifest -- the production assembly path.

    MUTATION: delete any one of the three keys from `_grid_nodes`' node dict.

    Asserted over EVERY node rather than a sampled one, and `seq` is checked with `isinstance(..., int)`
    rather than truthiness: the head of the declaration order carries `seq == 0`, so a truthiness test
    would go green on a missing key for exactly the node a renderer places first.
    """
    dirs = _four_repository_registry(isolated)
    monkeypatch.chdir(dirs["delta"])

    manifest = cli._document("", False, "json", local=True)["grid"]["manifests"][0]
    nodes = manifest["nodes"]
    assert nodes, "the B6 fixture's manifest must have been selected"

    for ref, node in nodes.items():
        assert isinstance(node["seq"], int), ref
        assert isinstance(node["parents"], list), ref
        assert isinstance(node["children"], list), ref

    # The fixture is a linear four-row chain in declared order, so seq IS file order and the edges
    # are consecutive. Pinned as VALUES, not just as types -- a node carrying `parents: []` for every
    # ref would satisfy the shape assertions above and render a grid with no connectors at all.
    assert [nodes[ref]["seq"] for ref in sorted(nodes)] == [0, 1, 2, 3]
    assert nodes["testorg/bravo#22"]["parents"] == ["testorg/alpha#11"]
    assert nodes["testorg/bravo#22"]["children"] == ["testorg/charlie#33"]
    assert nodes["testorg/alpha#11"]["parents"] == []
    assert nodes["testorg/delta#44"]["children"] == []


def test_parents_and_children_carry_ordering_edges_only():
    """G2. `stacked` and `blocks` link; `apex` does NOT.

    MUTATION: drop the `ORDERING_EDGE_KINDS` filter in `_ordering_adjacency` and admit every kind.

    An apex edge points from the tracker at EVERY row (manifest_core._apex_edges), so admitting it
    makes the tracker the parent of the whole manifest -- one node whose connectors fan across every
    column. `levels()` already refuses apex for the matching reason, and the two filters drifting is
    a picture that draws an edge the ranking never counted.

    THE `blocks` HALF IS ASSERTED TOO, and it is what stops the INVERSE mutation from passing: an
    implementation narrowed to `stacked` alone renders a declared blocker as no connector at all,
    which is a missing dependency rather than an invented one, and every apex assertion here would
    still be green.

    THE GATE MUST BLOCK ON A NON-ADJACENT ROW, and the first version of this fixture got that wrong.
    It gated row 2 on row 1, which are consecutive in the same lane -- so `_stacked_edges` emitted the
    SAME `(o/r#1, o/r#2)` pair the `blocks` channel did, deduplication collapsed them, and narrowing
    ORDERING_EDGE_KINDS to `("stacked",)` left every assertion green. The docstring claimed a mutation
    the fixture could not catch, which is the "a check pointed at the wrong thing reads as a pass"
    failure this suite exists to avoid. Row 3 gating on row 1 SKIPS row 2, so the blocks edge is a
    pair no lane adjacency can supply.
    """
    manifest = {
        "program": "gated",
        "rows": [
            {"order": "1", "ref": "o/r#1"},
            {"order": "2", "ref": "o/r#2"},
            {
                "order": "3",
                "ref": "o/r#3",
                "gate": {"kind": "decision", "blocked_by": "prose", "blocked_by_ref": "o/r#1", "resolved_by": "x"},
            },
        ],
        "apex": {"ref": "o/tracker#9"},
    }
    nodes = grid_manifest_nodes(manifest)

    assert nodes["o/tracker#9"]["children"] == []
    assert nodes["o/r#1"]["parents"] == []
    assert "o/tracker#9" not in nodes["o/r#1"]["parents"]
    assert "o/tracker#9" not in nodes["o/r#3"]["parents"]
    # The lane supplies r#2 -> r#3; ONLY the blocks channel can supply r#1 -> r#3. Narrowing
    # ORDERING_EDGE_KINDS to ("stacked",) drops the second and turns this line red.
    assert nodes["o/r#3"]["parents"] == ["o/r#1", "o/r#2"]
    assert nodes["o/r#1"]["children"] == ["o/r#2", "o/r#3"]


def test_a_manifest_block_carries_its_desc_and_repo_slugs():
    """G3. MUTATION: drop `desc` or `repos` from `grid_manifest`'s dict.

    `repos` is over row_refs, NOT declared_refs, and the apex here is what proves it: `o/tracker#9`
    lives in `o/tracker`, a repository this project does not span. Listing it would tell a reader the
    project reaches a repository it merely files its tracker in -- under a heading that already claims
    the project. Sorted and deduplicated, so two rows in one repository contribute one entry.
    """
    manifest = {
        "program": "spanning",
        "desc": "one sentence about the work",
        "rows": [
            {"order": "1", "ref": "beta/two#1"},
            {"order": "2", "ref": "alpha/one#2"},
            {"order": "3", "ref": "alpha/one#3"},
        ],
        "apex": {"ref": "o/tracker#9"},
    }
    block = link_grid.grid_manifest(manifest, {}, {})

    assert block["desc"] == "one sentence about the work"
    assert block["repos"] == ["alpha/one", "beta/two"]
    assert "o/tracker" not in block["repos"]

    # A manifest with no `desc` carries the key with an empty value rather than omitting it -- a
    # renderer that has to test `in` before every read grows a branch per optional key.
    assert link_grid.grid_manifest({"rows": [{"order": "1", "ref": "a/b#1"}]}, {}, {})["desc"] == ""


def test_parents_and_children_are_sorted_by_seq_then_ref():
    """G4. MUTATION: sort either adjacency list by `ref` alone (or leave it in edge order).

    `levels()` publishes within-level order as ASCENDING REF, which is deterministic but carries no
    meaning. Measured on the live stillpoint/.borg/programs/ingle-t1-cutover.json: the `contract` lane
    holds seq 0-5 and `cutover` seq 6-13, but ascending ref interleaves them at four of eight levels.
    A renderer placing nodes by ref order therefore crosses two lanes four times with no edge crossing
    anything, which is why declaration order is the tie-break and why it is pinned here.
    """
    nodes = grid_manifest_nodes(_fork_manifest())

    assert [nodes[ref]["seq"] for ref in ("o/zzz#1", "o/mmm#2", "o/aaa#3", "o/r#4")] == [0, 1, 2, 3]
    # Declaration order: mmm before aaa. Ascending ref would give aaa before mmm.
    assert nodes["o/zzz#1"]["children"] == ["o/mmm#2", "o/aaa#3"]
    assert nodes["o/r#4"]["parents"] == ["o/mmm#2", "o/aaa#3"]


def test_a_declared_ref_that_is_not_a_row_sorts_after_every_row():
    """The `seq` fallback, which no other case reaches. MUTATION: default the fallback to 0.

    An `after` target outside the manifest gets a node (declared_refs, not row_refs) but has no
    declared position here. Seating it at 0 would put a foreign ref at the head of the declaration
    order and drag the column of whatever chain it parents. `len(rows)` puts it past every real row;
    two such refs tie there and break on ref, which is deterministic.
    """
    manifest = {
        "program": "outside",
        "rows": [
            {"order": "1", "ref": "o/r#1"},
            {"order": "2", "ref": "o/r#2", "after": ["far/away#7", "far/away#3"]},
        ],
    }
    nodes = grid_manifest_nodes(manifest)

    assert nodes["o/r#1"]["seq"] == 0
    assert nodes["o/r#2"]["seq"] == 1
    assert nodes["far/away#3"]["seq"] == 2
    assert nodes["far/away#7"]["seq"] == 2
    # Both foreign parents tie on seq, so the ref breaks it -- ascending, and stably.
    assert nodes["o/r#2"]["parents"] == ["far/away#3", "far/away#7"]


def grid_manifest_nodes(manifest: dict) -> dict:
    """`grid_manifest(...)["nodes"]` with no sweep and no fetch -- the declared-only projection.

    Defined at the bottom rather than beside the fixtures because it is a one-line reader, not a
    fixture: it supplies nothing, derives nothing, and exists so four cases do not each repeat the
    two empty maps that say "nobody looked".
    """
    nodes: dict = link_grid.grid_manifest(manifest, {}, {})["nodes"]
    return nodes
