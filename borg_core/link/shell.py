"""I/O layer for the `borg link` port: every filesystem, subprocess, environment and clock read.

Every function here that touches the filesystem, subprocess, the environment or the clock lives in
this module. Logic (parsing, merging, sorting, formatting) is delegated to core.py -- this module
never reimplements it.

Ports the I/O half of: borg_registry_with_state's state.json gathering, _borg_live_windows /
borg_tmux_windows, _borg_read_directives, _borg_read_assimilated, _borg_collect_all_directives,
_borg_collect_all_assimilated, _borg_cortex_pending, and the deep dive's PROJECT_PLAN.md and
checkpoint readers.

PHASE 1 SCOPE: leaves and the chokepoint. There is no cli.py and no document builder -- the `--json`
seam is Phase 2 and the render flip is Phase 3 (PROJECT_PLAN.md).

WHY THIS IMPORTS borg_core.recon.shell AND borg_core.manifest.shell (S3, the sweep fold): `link` is
now the CONSUMER of both engines, and those arrows point the right way -- `recon` retires as a
human-facing verb in S4, so a second fan-out here would be a copy of an engine that is on its way
out. `recon.shell.fanout` is imported whole rather than reimplemented: it already owns bounded
concurrency, the per-adapter deadline and the degrade-to-a-failed-track policy, and
borg_core/proc.py's module docstring is the standing ruling that the third copy of a
run/capture/degrade shape does not get written. Neither module is the Domain layer and both imported
names are public, so no layering rule is crossed.

NOTHING IN THE SWEEP PATH IS EVER FATAL, extending the policy borg_core/manifest/shell.py's header
states. A missing `gh`, an unauthenticated `gh`, an offline host, a rate limit, a failed adapter
track, an empty adapter search path, a repository with no origin, a malformed manifest, a
non-numeric `BORG_RECON_*` value -- every one of them is a NAMED warning on the grid and a degraded
grid, never an exception and never a blank grid with no explanation. Every consumer of `borg link`
swallows failure (`cmd_watch`'s `|| true`, `drone status`'s `|| true`, fzf's preview pane), so an
exception here is an invisible blank frame, and a silent empty grid is worse than a loud degraded
one.

THE FIRST FOUR OF THOSE WERE NOT ACTUALLY TRUE WHEN THIS PARAGRAPH WAS FIRST WRITTEN, which is the
reason for the two mechanisms that now make them true. An adapter that cannot reach its source exits
0 with a valid empty track, so `ok` alone could never see it: the adapter contract gained an explicit
`skipped: true` and grid.track_status turned two outcomes into three (see its docstring for the
end-to-end reproduction with an unauthenticated `gh`). And `borg_core/recon/shell.py`'s
`int(os.environ.get(...))` readers, newly on this path, were hardened to the same empty/non-numeric
guard the readers in this module use -- an exported-empty `BORG_RECON_MAX_TRACKS` took the whole
command down with zero bytes on stdout. A contract paragraph that the code does not keep is worse
than no paragraph, because the next reader cites it.

WHY THIS IMPORTS borg_core.registry.shell: `borg_registry_read` is not a pure read. It mkdir's
$BORG_DIR and creates registry.json containing {"projects":{}} when absent (lib/registry.zsh:18-23,
38-41), and registry.shell.read_registry already reproduces that side effect plus the corrupt-JSON
ValueError. Reimplementing it here would be a twelve-line duplicate and would trip pylint's
duplicate-code, the same way borg_dir/registry_path did before borg_core/paths.py existed. Both
imported names are public, and neither module is the Domain layer, so no layering rule is crossed.
"""

from __future__ import annotations

import json
import os
import tempfile
import time
from pathlib import Path

from borg_core import paths
from borg_core.link import core, grid
from borg_core.manifest import shell as manifest_shell
from borg_core.recon import shell as recon_shell
from borg_core.registry import shell as registry_shell

# Re-exported so this package has its own surface, with one definition in borg_core/paths.py.
borg_dir = paths.borg_dir
registry_path = paths.registry_path

# Both are public, side-effecting reads already implemented once; see the module docstring.
read_registry = registry_shell.read_registry
tmux_session_name = registry_shell.tmux_session_name


def now_epoch() -> int:
    """The current time in epoch seconds.

    The clock read belongs in the shell tier, not in a future cli.py. borg_core/recon/cli.py reads
    the wall clock in its CLI layer and that is a recorded layering smell inherited from the old
    shell; it is deliberately not repeated here.
    """
    return int(time.time())


# Re-exported: mirrors _borg_live_windows -> borg_tmux_windows (lib/registry.zsh:200-203,
# lib/tmux.zsh:11-14). Was its own byte-identical `tmux list-windows` fork; now the same definition
# borg_core.registry.shell.tmux_window_exists uses, see that module's list_tmux_windows docstring
# for the fork-collapsing rationale (borg_tmux_alive + tmux list-windows -> one fork).
live_windows = registry_shell.list_tmux_windows


def reap_threshold_hours() -> int | None:
    """BORG_REAP_STALE_HOURS as an int, or None when it is set to something non-numeric.

    Mirrors `${BORG_REAP_STALE_HOURS:-12}` read at call time (lib/reaper.sh:27). Unset OR EMPTY gives
    the default; only decimal integers are honored. None means "the shell's `[ ... -ge ]` would
    return 2", which core.should_reap reads as keep.
    """
    raw = os.environ.get("BORG_REAP_STALE_HOURS")
    if not raw:
        return core.DEFAULT_REAP_STALE_HOURS
    try:
        return int(raw)
    except ValueError:
        return None


def max_active() -> int:
    """BORG_MAX_ACTIVE as an int, defaulting to 3 (borg.zsh:43 `${BORG_MAX_ACTIVE:-3}`).

    Unset OR EMPTY gives the default -- _borg_py passes the variable through and an unset one
    arrives as the EMPTY STRING, so this must be truthiness-checked, not existence-checked.
    DEVIATION: a non-numeric value falls back to 3 here, where zsh's `(( x > BORG_MAX_ACTIVE ))`
    would raise a bad-math-expression error. Same class as reap_threshold_hours.
    """
    raw = os.environ.get("BORG_MAX_ACTIVE")
    if not raw:
        return core.DEFAULT_MAX_ACTIVE
    try:
        return int(raw)
    except ValueError:
        return core.DEFAULT_MAX_ACTIVE


def orchestrator_root() -> str:
    """BORG_ORCHESTRATOR_ROOT, realpath-normalized, defaulting to ~/dev (borg.zsh:23).

    Defaults HERE as well as in _borg_py, and that duplication is deliberate. `_borg_py` applies the
    default for every child it launches, but a module invoked directly (`python3 -m borg_core.link.cli`,
    which is exactly what the test suite and any debugging session do) has no wrapper at all. This is
    the same two-sided rule borg_core/paths.py follows, and its absence is precisely how `borg recon`
    shipped non-functional: borg.zsh:23 assigns BORG_ORCHESTRATOR_ROOT bare, with no `export`, so the
    Python child has never seen it. Unset OR EMPTY takes the default -- _borg_py passes variables
    through as the empty string, so this must be truthiness-checked, not existence-checked.
    """
    raw = os.environ.get("BORG_ORCHESTRATOR_ROOT")
    if not raw:
        raw = os.path.expanduser("~/dev")
    return os.path.realpath(raw)


def cwd() -> str:
    """The invoking directory realpath-normalized, or "" when it cannot be determined.

    Normalized here, in the shell tier, so core.scope_for stays pure: symlink resolution is a
    filesystem question, and /Users/noah/dev is itself commonly reached through one. Comparing an
    unresolved cwd against a resolved registry path silently makes every repository look like the
    orchestrator.

    THE GUARD IS NOT DEFENSIVE PADDING. os.getcwd() raises FileNotFoundError when the invoking
    directory has been deleted out from under a live shell -- routine here, because `drone down`,
    `borg reap-worktrees` and `git worktree remove` all delete directories a user may still be
    sitting in. Before this module read cwd at all, such an invocation succeeded; unguarded, it
    would now die in ALL FOUR modes via cli.main's broad `except Exception`, with exit 1 and zero
    bytes on stdout -- a clean, uninformative failure with no hint that the cwd is the cause, in a
    command whose callers (cmd_watch, drone status, the fzf preview) all swallow errors.
    "" degrades to orchestrator scope: it matches no orchestrator root and prefix-matches no
    registry path, so an unknowable location yields the broadest reading rather than a wrong one.
    """
    try:
        return os.path.realpath(os.getcwd())
    except OSError:
        return ""


def resolved_project_paths(registry: dict) -> list[tuple[str, str]]:
    """Every (name, path) pair from the registry with each non-empty path realpath-normalized.

    The shell-tier half of core.scope_for: resolving symlinks is filesystem work, and BOTH sides of
    the prefix comparison must be resolved identically or the match silently fails. Missing paths
    stay "" (core.project_paths already applies jq's `//` semantics) and scope_for skips them.

    os.path.realpath does NOT stat -- a registry entry pointing at a deleted directory normalizes
    lexically and simply fails to match a live cwd, which is the correct outcome. No existence check
    here: this runs on every invocation over the whole registry, and a stat per project would put
    filesystem latency on the one path that has to stay reflexive.
    """
    return [(name, os.path.realpath(path) if path else "") for name, path in core.project_paths(registry)]


def reap_disabled() -> bool:
    """Whether BORG_NO_REAP suppresses the overlay.

    ANY non-empty value disables it, mirroring `[[ -z "${BORG_NO_REAP:-}" ]]` (lib/registry.zsh:185).
    """
    return bool(os.environ.get("BORG_NO_REAP"))


def _read_text(path: Path) -> str:
    """A file's contents, or "" if it cannot be read.

    Reproduces the shell's pipelines, which redirect stderr and carry on: `head -1 <a directory>`
    fails to an empty title rather than aborting the listing.
    """
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def _usable_path(project_path: str | None) -> Path | None:
    """A project path that is worth touching, or None.

    The literal string "null" is rejected as well as None and "": jq renders a JSON null that way and
    the shell guards `[[ -z "$ppath" || "$ppath" == "null" ]]` at every reader.
    """
    if not project_path or project_path == "null":
        return None
    return Path(project_path)


def read_state(project_path: str | None) -> dict | None:
    """A project's .borg/state.json as a dict, or None when there is nothing usable to merge.

    None for: no path, the literal "null", a missing file, an empty file, invalid JSON, or a parsed
    value that is not an object. The caller then leaves that project's registry entry untouched.

    This used to be a divergence worth flagging. It no longer is: the shell's guard at
    lib/registry.zsh was `result=$(... | jq ...) || result="$result"`, a no-op that let ONE malformed
    state.json blank the entire registry for link/next/switch/init/reap/watch. That was fixed
    separately, and both implementations now skip the bad project and keep the registry.
    """
    directory = _usable_path(project_path)
    if directory is None:
        return None
    state_file = directory / ".borg" / "state.json"
    text = _read_text(state_file)
    if not text:
        return None
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        return None
    return parsed if isinstance(parsed, dict) else None


def collect_states(registry: dict) -> dict[str, dict]:
    """Every project's state.json, keyed by project name; projects without one are absent."""
    states: dict[str, dict] = {}
    for name, project_path in core.project_paths(registry):
        if not name:
            continue
        state = read_state(project_path)
        if state is not None:
            states[name] = state
    return states


def registry_with_state(apply_reap: bool = True, now: int | None = None) -> dict:
    """The registry with state.json overlaid and, unless suppressed, the reap overlay applied.

    Mirrors borg_registry_with_state (lib/registry.zsh:165-189). BORG_NO_REAP wins over `apply_reap`,
    matching the shell, where the environment is the only control.

    DELIBERATE DEVIATION, recorded: the shell runs this ENTIRE pipeline TWICE per `borg link` --
    once for the table (borg.zsh:284) and once inside _borg_active_count for the capacity warning
    (borg.zsh:407) -- so a state.json written by a hook between the two passes can make the table and
    the warning disagree today. This computes one snapshot and derives both from it. Unobservable
    until Phase 3 flips the renderer; recorded now so it is not discovered as a surprise then.

    `now` lets a caller (cli._document) thread ONE shared instant through the reap decision. It
    exists so a whole document is built from ONE instant; without it the reap decision,
    `generated_at`, the relative times and the cortex countdowns can straddle a second boundary.
    """
    registry = read_registry()
    merged = core.with_state(registry, collect_states(registry))
    moment = now_epoch() if now is None else now
    if apply_reap and not reap_disabled():
        return core.reap_overlay(merged, live_windows(), moment, reap_threshold_hours())
    return merged


def _markdown_files(directory: Path) -> list[Path]:
    """*.md under `directory`, name-ascending, or [] if it is not a directory.

    No is_file() filter: zsh's `*.md(N)` matches directories too, and _read_text returning "" on the
    resulting OSError reproduces `head -1 <dir>` failing to an empty title.
    """
    if not directory.is_dir():
        return []
    # JUSTIFICATION: a filesystem glob on a stdlib Path, not a cross-layer reach.
    return sorted(directory.glob("*.md"), key=lambda p: p.name)  # pylint: disable=clean-arch-demeter


def read_directives(project_path: str | None) -> list[dict]:
    """A project's own pending directives, mirroring _borg_read_directives (borg.zsh:125-137).

    The shell emits a leading COUNT line on every path, including the failures ("0"); that is a TSV
    transport artifact, not a contract. Here the count is len().
    """
    directory = _usable_path(project_path)
    if directory is None:
        return []
    return [
        {"slug": core.slug_from_filename(f.name), "title": core.heading_title(_read_text(f))}
        for f in _markdown_files(directory / "docs" / "plans" / "directives")
    ]


def read_assimilated(project_path: str | None, max_items: int = 3) -> list[dict]:
    """A project's most recently shipped plans, newest first.

    DELIBERATE DEVIATION, the one PROJECT_PLAN.md mandates. The shell globs `(NOm)` (borg.zsh:147):
    `om` sorts newest-first by mtime and `O` REVERSES it, so `borg link <project>` lists the three
    OLDEST assimilated plans under "Recently assimilated". The in-source comment "# newest first by
    mtime" is wrong, and the section disagrees with the overview's aggregate, which sorts by filename
    DESC. This sorts by FILENAME descending -- the same key the aggregate already uses -- which gives
    the JSON contract ONE ordering instead of two and survives a fresh `git clone`, where every file
    shares the checkout mtime and any mtime ordering is meaningless.
    """
    directory = _usable_path(project_path)
    if directory is None:
        return []
    files = _markdown_files(directory / "docs" / "plans" / "assimilated")
    entries = [{"filename": f.name, "path": str(f), "project": ""} for f in files]
    chosen = core.sort_assimilated(entries)[:max_items]
    result = []
    for e in chosen:
        text = _read_text(Path(e["path"]))
        result.append(
            {
                "slug": core.slug_from_filename(e["filename"]),
                "title": core.heading_title(text),
                "ship_date": core.ship_date(text),
            }
        )
    return result


def collect_all_directives(registry: dict) -> list[dict]:
    """Directives across every reachable project, mirroring _borg_collect_all_directives.

    Iterates the RAW registry (borg.zsh:163 uses borg_registry_read, NOT the state-overlaid read), in
    JSON insertion order, which json.loads preserves and the rendered order depends on.
    """
    collected: list[dict] = []
    for name, project_path in core.project_paths(registry):
        if not name or not project_path or project_path == "null":
            continue
        for item in read_directives(project_path):
            collected.append({**item, "project": name})
    return collected


def collect_all_assimilated(registry: dict, max_items: int = 3) -> list[dict]:
    """The newest shipped plans across every reachable project, mirroring
    _borg_collect_all_assimilated (borg.zsh:190-214).

    TWO-PHASE and must stay so: gather every candidate across ALL projects first, sort globally, then
    read titles and ship dates for the survivors only. It cannot delegate to read_assimilated,
    because that sorts within one project and this sort is global -- and it is keyed on the filename
    WITH its ".md" suffix, because the shell sorts basenames, not slugs.
    """
    candidates: list[dict] = []
    for name, project_path in core.project_paths(registry):
        directory = _usable_path(project_path)
        if not name or directory is None:
            continue
        for f in _markdown_files(directory / "docs" / "plans" / "assimilated"):
            candidates.append({"filename": f.name, "path": str(f), "project": name})

    result: list[dict] = []
    for entry in core.sort_assimilated(candidates)[:max_items]:
        text = _read_text(Path(entry["path"]))
        result.append(
            {
                "slug": core.slug_from_filename(entry["filename"]),
                "title": core.heading_title(text),
                "ship_date": core.ship_date(text),
                "project": entry["project"],
            }
        )
    return result


def read_checkpoints(project_path: str | None, limit: int = 3) -> list[str]:
    """The newest checkpoint filenames, newest first, capped at `limit`.

    Mirrors borg.zsh:466's `find ... -maxdepth 1 -name '*.md' | sort -r | head -3`: a NAME sort, not
    an mtime sort. Returns filenames, not paths -- the renderer prints `${_cp##*/}`.
    """
    directory = _usable_path(project_path)
    if directory is None:
        return []
    checkpoints = directory / ".borg" / "checkpoints"
    if not checkpoints.is_dir():
        return []
    # JUSTIFICATION: a filesystem glob on a stdlib Path, not a cross-layer reach.
    names = [p.name for p in checkpoints.glob("*.md")]  # pylint: disable=clean-arch-demeter
    return core.sort_checkpoints(names, limit)


def read_latest_checkpoint_head(project_path: str | None, lines: int = 20) -> str:
    """The first `lines` lines of the newest checkpoint, mirroring `head -20 "${cp_files[1]}"`.

    "" when there is no checkpoint. The trailing newline behavior follows `head`: the joined lines
    carry no trailing newline of their own.
    """
    directory = _usable_path(project_path)
    if directory is None:
        return ""
    newest = read_checkpoints(project_path, limit=1)
    if not newest:
        return ""
    text = _read_text(directory / ".borg" / "checkpoints" / newest[0])
    return "\n".join(text.split("\n")[:lines])


def read_plan(project_path: str | None) -> dict | None:
    """The deep dive's Active Plan block, or None when there is no PROJECT_PLAN.md.

    Mirrors borg.zsh:451-461. Returns {"objective": str, "met": int, "total": int}; see
    core.plan_progress for the two-line `Progress:` rendering this deliberately does not reproduce.
    """
    directory = _usable_path(project_path)
    if directory is None:
        return None
    plan = directory / "PROJECT_PLAN.md"
    if not plan.is_file():
        return None
    text = _read_text(plan)
    met, total = core.plan_progress(text)
    return {"objective": core.plan_objective(text), "met": met, "total": total}


# Re-exported so cli.py has ONE I/O module to talk to. `discover_registered` derives the repository
# paths from the registry itself and must keep doing so -- see its docstring for why accepting a path
# list here would move the derivation into a caller that a test would then supply.
discover_manifests = manifest_shell.discover_registered
repository_slug = manifest_shell.repository_slug

# Seconds one adapter gets before it is SIGKILLed, when `link` is the caller. recon's own default is
# 30 -- correct for a morning link-up a human deliberately waits on, absurd for the front door AC1
# budgets at 2.7s. 10 is chosen against measurement, not taste: the batched-GraphQL adapter sweeps
# one repository in 0.69s and all 14 in 2.30s, so 10 is >4x the slowest observed real sweep and still
# well inside the point where a user concludes the command is hung.
DEFAULT_SWEEP_TIMEOUT_SECONDS = 10


def sweep_timeout() -> float:
    """BORG_LINK_SWEEP_TIMEOUT as a number of seconds, defaulting to DEFAULT_SWEEP_TIMEOUT_SECONDS.

    Unset OR EMPTY OR non-numeric takes the default, and none of those three is defensive padding.
    `_borg_py` passes its whole config surface through by name, and an unset variable arrives as the
    EMPTY STRING; `int("")` raises ValueError, which is exactly why the hardened spec forbids adding
    any `BORG_RECON_*` name to that wrapper (`max_tracks`/`track_timeout` use a bare
    `int(os.environ.get(...))` and would take down the whole invocation). This variable is written to
    survive the wrapper, so it may be added to it without repeating that bug.
    """
    raw = os.environ.get("BORG_LINK_SWEEP_TIMEOUT")
    if not raw:
        return DEFAULT_SWEEP_TIMEOUT_SECONDS
    try:
        return float(raw)
    except ValueError:
        return DEFAULT_SWEEP_TIMEOUT_SECONDS


def sweep_window_days() -> int:
    """BORG_LINK_SWEEP_WINDOW_DAYS as an int, defaulting to grid.DEFAULT_SWEEP_WINDOW_DAYS.

    Same three-way guard as sweep_timeout, for the same reason: unset OR EMPTY OR non-numeric takes
    the default, because `_borg_py` passes its whole config surface through by name and an unset
    variable arrives as the EMPTY STRING. See grid.DEFAULT_SWEEP_WINDOW_DAYS for why link resolves
    its own mark instead of reusing recon's since-ladder.
    """
    raw = os.environ.get("BORG_LINK_SWEEP_WINDOW_DAYS")
    if not raw:
        return grid.DEFAULT_SWEEP_WINDOW_DAYS
    try:
        return int(raw)
    except ValueError:
        return grid.DEFAULT_SWEEP_WINDOW_DAYS


def _read_sweep_fixture(path: str) -> dict:
    """A recorded sweep read off disk in place of running one. The B7 seam; see `sweep`.

    Shaped `{"since": str, "tracks": [<track>, ...]}` -- `tracks` being EXACTLY what
    recon.shell.fanout returns, one object per adapter with `source`, `summary`, `items` and `ok`.
    Recording the fan-out's OUTPUT rather than the finished grid is the whole point: everything
    downstream of the subprocess -- state extraction, the resolve ladder, level assignment, the
    per-source summary -- still runs on production code. A fixture of the finished grid would test
    that JSON round-trips.

    An unreadable or malformed fixture degrades to a not-swept grid with a NAMED warning rather than
    raising: a test harness that mistypes the path must see why, not see an empty grid it mistakes
    for a correct one.
    """
    try:
        with open(path, encoding="utf-8") as handle:
            doc = json.load(handle)
    except (OSError, ValueError) as exc:
        return grid.no_sweep([f"sweep: fixture {path} unreadable or invalid JSON ({exc})"])
    if not isinstance(doc, dict):
        return grid.no_sweep([f"sweep: fixture {path} is not an object -- ignored"])
    tracks = doc.get("tracks")
    return {
        "swept": True,
        "since": str(doc.get("since") or ""),
        "tracks": tracks if isinstance(tracks, list) else [],
        "warnings": [f"sweep: replayed from fixture {path} -- no adapter ran"],
    }


def sweep(projects: dict, now: int | None = None) -> dict:
    """Run the recon fan-out over `projects` and return `{swept, since, tracks, warnings}`.

    `projects` is the registry's `.projects` object ALREADY NARROWED TO THE SCOPED BREADTH by the
    caller: one entry in repository scope, all of them in orchestrator scope. That narrowing is what
    makes AC1's two latency figures different numbers rather than one, and it is the caller's job
    because only the caller knows the scope.

    THE MARK IS `link`'s OWN, NOT recon's, and that is the one thing about this function that must
    not be "simplified" back. `recon.shell.resolve_since` resolves "what changed since I last
    looked" -- newest checkpoint mtime, then the last-run marker, then 24h -- and BOTH of its top two
    rungs vary with which projects are in scope and with how recently someone checkpointed. Reusing
    it made the same ref resolve to two contradictory confident states depending on whether you asked
    from inside a repository or from the workspace root, and made the WIDEST breadth get the
    NARROWEST freshness window. grid.DEFAULT_SWEEP_WINDOW_DAYS carries the measurement and the
    argument. `now` threads cli._document's single shared epoch in; None reads the clock, for a
    caller that has no document.

    TWO ENVIRONMENT SEAMS, one shipped and one reserved. Both are read HERE, in the shell tier, and
    nowhere else -- core.py is pure and pylint enforces it.

      BORG_LINK_SWEEP_FIXTURE -- path to a recorded `{"since": str, "tracks": [...]}` document.
          When set, this function reads it INSTEAD of fanning out: zero subprocesses, no adapter
          discovery, no `since` resolution, no `recon/last-run` write. It exists because
          `_assert_link_golden` byte-diffs `borg link`'s output with `2>&1`, and a sweep folded into
          the document makes every golden a snapshot of whatever GitHub returned that minute --
          non-reproducible on the second run, and `BORG_UPDATE_GOLDEN=1` would freeze one machine's
          network state as the oracle (the hardened spec's B7).

      BORG_LINK_FETCH_FIXTURE -- RESERVED for AC3's targeted fetch and deliberately unimplemented
          here. AC3 resolves refs a manifest declares but the sweep window missed; its fixture must
          mirror this one exactly: a path to a recorded JSON document, read in this module, short-
          circuiting BEFORE any subprocess, degrading to a named warning on a bad path. Shipping an
          unused reader for it now would be dead code carried on a 90% coverage floor. The name is
          recorded here so AC3 mirrors the seam instead of inventing a second, differently-shaped one.

    `swept` MEANS AN ADAPTER ACTUALLY RAN (or a fixture stood in for one), not merely "--local was
    absent". Zero discovered adapters returns swept=False with a warning naming the empty search
    path, because a grid whose every state came from the manifest must not claim to have looked.
    `since` is "" whenever `swept` is False, so the pair can never say "swept as of <a mark nobody
    used>".

    IT NEVER CALLS recon.shell.write_last_run_marker, and that omission is load-bearing. That marker
    is the third rung of recon's own since-ladder; a `borg link` that advanced it would silently move
    `borg recon`'s mark forward on every render, and recon would start missing everything that
    changed between link runs. It is also a cache artifact, which AC1 forbids outright ("no cache,
    ever -- a clean read every time").
    """
    fixture = os.environ.get("BORG_LINK_SWEEP_FIXTURE")
    if fixture:
        return _read_sweep_fixture(fixture)

    adapters = recon_shell.discover_adapters()
    if not adapters:
        return grid.no_sweep(
            [
                "sweep: no recon adapters found on "
                f"{recon_shell.adapter_search_path()} -- every state falls back to what the manifest declares"
            ]
        )

    since = grid.sweep_since(now_epoch() if now is None else now, sweep_window_days())
    with tempfile.TemporaryDirectory(prefix="borg-link.") as workdir:
        projects_file = os.path.join(workdir, "projects.json")
        try:
            recon_shell.write_projects_file(projects, projects_file)
        except (OSError, TypeError, ValueError) as exc:
            return grid.no_sweep([f"sweep: could not stage the project list ({exc}) -- no adapter ran"])
        tracks = recon_shell.fanout(since, projects_file, adapters, timeout=sweep_timeout())
    return {"swept": True, "since": since, "tracks": tracks, "warnings": grid.track_warnings(tracks)}


def cortex_wakes_path() -> Path:
    """Where pending Cortex wakes live.

    borg.zsh:48 is `BORG_CORTEX_WAKES="${BORG_CORTEX_STATE:-$BORG_DIR/cortex-wakes.json}"`, so both
    names are honored: BORG_CORTEX_WAKES is what Phase 2's dispatch wrapper passes, BORG_CORTEX_STATE
    is what a user's config.zsh may set.
    """
    for env_name in ("BORG_CORTEX_WAKES", "BORG_CORTEX_STATE"):
        value = os.environ.get(env_name)
        if value:
            return Path(value)
    return borg_dir() / "cortex-wakes.json"


def cortex_pending(now: int | None = None) -> list[dict]:
    """Pending Cortex wakes with their countdowns, mirroring _borg_cortex_pending (borg.zsh:2397).

    A missing or unreadable file, invalid JSON, a non-object root, an absent `.wakes`, or a non-list
    `.wakes` all yield [] -- jq's `.wakes[]?` swallows every one of those. Non-object array elements
    are SKIPPED (jq would error mid-stream and lose the rest; skipping is the sane reading, recorded
    as a deviation). A wake whose `.project` is JSON null renders the literal string "null" and is
    therefore NOT skipped, matching the shell's `\\(.project)` interpolation.

    DELIBERATE DEVIATION, not reproduced: the shell re-declares `local cd` INSIDE its loop, and zsh's
    `local` prints an already-declared parameter, so N pending wakes emit N-1 spurious
    `cd='<previous countdown>'` lines interleaved with the real rows. Harmless only because the sole
    consumer is an awk `$1 == p` filter (borg.zsh:374). _borg_cortex_pending is deleted by A5 and has
    no surviving zsh twin, so this fix is unobservable -- recorded rather than left to vanish.
    """
    moment = now_epoch() if now is None else now
    text = _read_text(cortex_wakes_path())
    if not text:
        return []
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        return []
    if not isinstance(parsed, dict):
        return []
    wakes = parsed.get("wakes")
    if not isinstance(wakes, list):
        return []

    pending: list[dict] = []
    for wake in wakes:
        if not isinstance(wake, dict):
            continue
        project = core.jq_interp(wake.get("project"))
        if not project:
            continue
        reset_at = core.jq_interp(wake.get("reset_at"))
        pending.append({"project": project, "reset_at": reset_at, "countdown": core.countdown(reset_at, moment)})
    return pending
