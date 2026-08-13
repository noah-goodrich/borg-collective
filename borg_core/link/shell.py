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
import subprocess
import time
from pathlib import Path

from borg_core import paths
from borg_core.link import core
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


def live_windows() -> list[str]:
    """Names of the live tmux windows in borg's session, or [] when there is no session.

    Mirrors _borg_live_windows -> borg_tmux_windows (lib/registry.zsh:200-203, lib/tmux.zsh:11-14).

    DELIBERATE DEVIATION: collapses the shell's `borg_tmux_alive` (a `tmux has-session`) plus
    `tmux list-windows` into ONE fork. Behavior-equivalent because tmux resolves a `-t` target the
    same way for both subcommands (exact, then prefix, then fnmatch), so any session has-session
    would find is the session list-windows finds. The inherited looseness comes along: with no
    session literally named "borg", a session named "borg-anything" satisfies both.
    """
    try:
        result = subprocess.run(
            ["tmux", "list-windows", "-t", tmux_session_name(), "-F", "#W"],
            capture_output=True,
            text=True,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return []
    if result.returncode != 0:
        return []
    # JUSTIFICATION: splitting a subprocess's own captured stdout text, not a cross-layer reach.
    return result.stdout.splitlines()  # pylint: disable=clean-arch-demeter


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


def registry_with_state(apply_reap: bool = True) -> dict:
    """The registry with state.json overlaid and, unless suppressed, the reap overlay applied.

    Mirrors borg_registry_with_state (lib/registry.zsh:165-189). BORG_NO_REAP wins over `apply_reap`,
    matching the shell, where the environment is the only control.

    DELIBERATE DEVIATION, recorded: the shell runs this ENTIRE pipeline TWICE per `borg link` --
    once for the table (borg.zsh:284) and once inside _borg_active_count for the capacity warning
    (borg.zsh:407) -- so a state.json written by a hook between the two passes can make the table and
    the warning disagree today. This computes one snapshot and derives both from it. Unobservable
    until Phase 3 flips the renderer; recorded now so it is not discovered as a surprise then.
    """
    registry = read_registry()
    merged = core.with_state(registry, collect_states(registry))
    if apply_reap and not reap_disabled():
        return core.reap_overlay(merged, live_windows(), now_epoch(), reap_threshold_hours())
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
    return [
        {
            "slug": core.slug_from_filename(e["filename"]),
            "title": core.heading_title(_read_text(Path(e["path"]))),
            "ship_date": core.ship_date(_read_text(Path(e["path"]))),
        }
        for e in chosen
    ]


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
