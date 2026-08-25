"""I/O layer for the recon fan-out engine (ports lib/recon.sh's shell-out plumbing).

Every function here that touches the filesystem, subprocess, or the environment lives in this
module. Logic (parsing, validation, formatting) is delegated to core.py — this module never
reimplements it.
"""

from __future__ import annotations

import concurrent.futures
import json
import os
import time
from pathlib import Path

from borg_core import paths, proc
from borg_core.recon import core

DEFAULT_MAX_TRACKS = 8
DEFAULT_TRACK_TIMEOUT = 30
FALLBACK_WINDOW_SECONDS = 86400


# Re-exported, not redefined: borg_core/paths.py holds the single definition of both, so this
# package keeps its own `shell.borg_dir()` / `shell.registry_path()` surface (and its tests) without
# a second copy of the resolution rules. `registry_path` is new to recon -- cli.py used to read
# BORG_REGISTRY from the environment with no fallback, which made `borg recon` unrunnable on a
# normal machine, since borg.zsh assigns that variable without `export` and the python3 child
# inherited an empty value. Nothing caught it: every test reaching this path puts BORG_REGISTRY in
# the environment itself (tests/test_helper/setup.bash exports it, the pytest suites monkeypatch
# it), so the resolution path had never once executed under test -- the same shape as the
# usage-watch and memory-gate blind spots recorded in CLAUDE.md.
borg_dir = paths.borg_dir
registry_path = paths.registry_path


def lib_dir() -> Path:
    """Directory that holds the shipped reference adapters, mirroring _recon_lib_dir.

    Prefers BORG_RECON_LIB_DIR (set by the zsh shim / caller); falls back to this file's own
    lib/ directory (borg_core/recon/../.. == repo root, then lib/).
    """
    override = os.environ.get("BORG_RECON_LIB_DIR")
    if override:
        return Path(override)
    return Path(__file__).resolve().parent.parent.parent / "lib"


def adapter_search_path() -> str:
    """Colon-separated adapter search path, mirroring _recon_adapter_path."""
    override = os.environ.get("BORG_RECON_ADAPTER_PATH")
    if override:
        return override
    return f"{borg_dir() / 'recon' / 'adapters'}:{lib_dir() / 'recon' / 'adapters'}"


def _int_env(name: str, default: int) -> int:
    """An integer configuration variable, where unset OR EMPTY OR non-numeric all take the default.

    BOTH GUARDS ARE LOAD-BEARING AND NEITHER IS PADDING, and this function exists because the bare
    `int(os.environ.get(name, default))` it replaces became a KILL PATH for `borg link` the moment
    S3's sweep fold made `link` call `fanout`. `int("")` raises ValueError; that ValueError escapes
    `fanout` -> `sweep` -> `_grid` -> `_document` and lands in link/cli.py's broad boundary, which
    prints one line to stderr and exits 1 with ZERO BYTES ON STDOUT. Every consumer of `borg link`
    swallows failure (`cmd_watch`'s `|| true`, `drone status`'s `|| true`, fzf's preview pane), so
    the user sees a blank frame with no diagnosis anywhere -- and it takes only a user who once set
    `BORG_RECON_MAX_TRACKS` to tune recon and later cleared it. MEASURED before this guard:
    `BORG_RECON_MAX_TRACKS= borg link sierra` printed `▸ ERROR: invalid literal for int() with base
    10: ''` and rendered no rows at all.

    This is the exact shape CLAUDE.md's "Learned" records for `BORG_REAP_STALE_HOURS`, one layer
    over, and it is why the hardened spec forbids adding any `BORG_RECON_*` name to `_borg_py` --
    that wrapper passes unset variables through as the EMPTY STRING. With this guard the prohibition
    is no longer load-bearing for these two names, but it is left standing: a variable that is safe
    to export is not the same as a variable that should be.

    A NON-POSITIVE VALUE IS NOT CLAMPED. `BORG_RECON_TRACK_TIMEOUT=0` means "no patience at all" and
    borg_core/recon/test_shell.py already exercises it deliberately; silently promoting it to 30
    would make an explicit zero mean its opposite. Callers that cannot accept zero say so themselves.
    """
    raw = os.environ.get(name)
    if not raw:
        return default
    try:
        return int(raw)
    except ValueError:
        return default


def max_tracks() -> int:
    """Max concurrent recon tracks (bounded fan-out), mirroring _recon_max_tracks.

    Clamped to at least 1 AFTER _int_env, because this one value reaches
    `ThreadPoolExecutor(max_workers=...)`, which raises on anything below 1 -- and that raise is the
    same blank-frame kill path _int_env exists to close, just via a different exception.
    """
    return max(1, _int_env("BORG_RECON_MAX_TRACKS", DEFAULT_MAX_TRACKS))


def track_timeout() -> int:
    """Per-adapter timeout in seconds, mirroring _recon_track_timeout."""
    return _int_env("BORG_RECON_TRACK_TIMEOUT", DEFAULT_TRACK_TIMEOUT)


def file_mtime(path: Path) -> int | None:
    """mtime (epoch seconds) of a file, or None if it doesn't exist."""
    try:
        return int(path.stat().st_mtime)
    except OSError:
        return None


def newest_checkpoint_epoch(project_dirs: list[str]) -> int | None:
    """Newest checkpoint mtime (epoch) across a list of project dirs, or None if none exist."""
    newest: int | None = None
    for project_dir in project_dirs:
        cdir = Path(project_dir) / ".borg" / "checkpoints"
        if not cdir.is_dir():
            continue
        for cp in cdir.glob("*.md"):
            if not cp.is_file():
                continue
            mtime = file_mtime(cp)
            if mtime is None:
                continue
            if newest is None or mtime > newest:
                newest = mtime
    return newest


def read_last_run_marker() -> str | None:
    """Read the last-run marker file, trimmed, or None if absent/empty."""
    marker = borg_dir() / "recon" / "last-run"
    if not marker.is_file():
        return None
    try:
        value = marker.read_text().splitlines()[0].strip() if marker.stat().st_size else ""
    except OSError:
        return None
    return value or None


def write_last_run_marker(iso_ts: str) -> None:
    """Persist the mark used by this sweep, mirroring _recon_write_last_run."""
    recon_dir = borg_dir() / "recon"
    try:
        recon_dir.mkdir(parents=True, exist_ok=True)
        (recon_dir / "last-run").write_text(iso_ts + "\n")
    except OSError:
        pass


def resolve_since(explicit_since: str, project_dirs: list[str]) -> str:
    """I/O-resolving wrapper around core.resolve_since: gathers the checkpoint epoch and marker,
    then delegates precedence resolution to core.py."""
    checkpoint_epoch = None if explicit_since else newest_checkpoint_epoch(project_dirs)
    marker_value = None if explicit_since or checkpoint_epoch is not None else read_last_run_marker()
    fallback_epoch = int(time.time()) - FALLBACK_WINDOW_SECONDS
    return core.resolve_since(explicit_since, checkpoint_epoch, marker_value, fallback_epoch)


def discover_adapters() -> list[tuple[str, str]]:
    """Discover available source adapters on the search path, deduped by source (first wins).

    An adapter is any executable file named `recon-adapter-<source>`. Mirrors
    _recon_discover_adapters end to end (I/O: filesystem scan + exec-bit check; logic: dedup
    delegated to core.dedup_adapters).
    """
    candidates: list[tuple[str, str]] = []
    for raw_dir in adapter_search_path().split(":"):
        if not raw_dir:
            continue
        directory = Path(raw_dir)
        if not directory.is_dir():
            continue
        for entry in sorted(directory.glob("recon-adapter-*")):
            if not entry.is_file() or not os.access(entry, os.X_OK):
                continue
            source = entry.name[len("recon-adapter-") :]
            candidates.append((source, str(entry.resolve())))
    return core.dedup_adapters(candidates)


def run_adapter(source: str, adapter_path: str, since: str, projects_file: str, timeout: float | None = None) -> dict:
    """Run one adapter as a subprocess under a timeout and normalize its output.

    Mirrors _recon_run_adapter: on any failure (non-zero exit, timeout, malformed output) returns
    a synthetic failed-track object so one bad source never aborts the sweep. Delegates all
    parsing/validation to core.process_adapter_output.

    A NON-ZERO EXIT IS STILL AN ANSWER and its stdout is still read -- core.process_adapter_output
    decides what the pair means. Only a process that could not run at all (missing binary, timeout)
    becomes the synthetic failed track here. The run/capture/degrade half lives in
    borg_core.proc.run_capture, which is where the same shape ended up for the third time.

    `timeout` EXISTS FOR borg_core.link, which reuses this engine on a reflexive front door. recon's
    own budget is 30s per adapter -- correct for a morning link-up a human is waiting on deliberately,
    absurd for a command that must answer in ~2.7s. `None` resolves to track_timeout(), so every
    existing recon call site (cli.py:67 passes three positionals, the suite four) is byte-identical.

    RESOLVED HERE, NEVER FORWARDED AS None. borg_core/proc.py documents `timeout=None` as *no
    timeout*; passing this parameter straight through would turn "use the default" into "run
    forever", and the caller that most needs a ceiling is the one that would lose it. And the test is
    `is None`, not truthiness: `timeout=0` must stay 0. A `timeout or track_timeout()` would promote
    an explicit zero to 30 -- and zero is exactly the value test_shell.py already exercises through
    BORG_RECON_TRACK_TIMEOUT.
    """
    captured = proc.run_capture(
        [adapter_path, "--since", since, "--projects", projects_file],
        timeout=track_timeout() if timeout is None else timeout,
    )
    if captured is None:
        return core.build_failed_track(source, -1)
    returncode, stdout = captured
    return core.process_adapter_output(source, stdout, returncode)


def fanout(since: str, projects_file: str, adapters: list[tuple[str, str]], timeout: float | None = None) -> list[dict]:
    """Fan out over adapters concurrently, bounded by max_tracks(). Mirrors _recon_fanout.

    Worst-case wall clock is `ceil(len(adapters) / max_tracks()) * timeout`: one batch at the default
    width of 8, so 30s for recon and `timeout` for link. A machine with a ninth injected adapter
    silently doubles that with no code change here -- which is the argument for passing a budget in
    rather than letting the caller assume one batch.

    THE FUTURE IS JOINED WITH NO TIMEOUT, AND THAT IS THE SAFETY PROPERTY, not an oversight. B4's
    hazard is a worker abandoned mid-run: a timeout on `f.result()` returns while the worker is still
    executing, and `concurrent.futures.thread`'s interpreter atexit hook then joins it anyway, so the
    process prints its answer and sits. Here the bound is on the WORK -- run_adapter hands `timeout`
    down to borg_core.proc.run_capture, which waits on the direct child's EXIT (not on pipe EOF) and,
    on expiry, SIGKILLs the child's whole SESSION and reaps it. The worker therefore always exits,
    the `with` block's shutdown(wait=True) always completes, and the atexit hook has nothing to join.
    Do NOT add `timeout=` to `f.result()`; a shorter budget belongs in run_adapter and nowhere else.

    THE TWO CLAIMS THIS PARAGRAPH USED TO MAKE WERE BOTH TOO STRONG, and the review that caught them
    measured the gap rather than arguing it. It said `subprocess.run` "SIGKILLs and reaps the child",
    which is true of exactly ONE pid -- the shipped github adapter runs `gh` in a command
    substitution, so the network work is a grandchild that survived the deadline and was reparented
    to init (six orphans measured across three invocations). And the re-measurement that pronounced
    B4 absent used a `sleep 30` adapter that produces NO OUTPUT, which is not B4's shape at all;
    B4's shape is output COMPLETE and the process still holding the pipe, which reproduces as a
    full-budget stall AND a spurious failed track. Both are now fixed in borg_core/proc.py -- see its
    module docstring for the measurements -- and neither was fixable from this function.
    """
    if not adapters:
        return []
    # JUSTIFICATION: stdlib ThreadPoolExecutor construction, not a layering violation.
    with concurrent.futures.ThreadPoolExecutor(  # pylint: disable=clean-arch-demeter
        max_workers=max_tracks()
    ) as pool:
        futures = [pool.submit(run_adapter, source, path, since, projects_file, timeout) for source, path in adapters]
        return [f.result() for f in futures]


def read_checkpoint_blockers(project_dir: str) -> str:
    """Read the newest checkpoint's raw text and extract its Blockers section.

    Mirrors _recon_checkpoint_blockers (I/O: find + read newest checkpoint; logic: delegated to
    core.extract_checkpoint_blockers).
    """
    cdir = Path(project_dir) / ".borg" / "checkpoints"
    if not cdir.is_dir():
        return ""
    checkpoints = sorted(p for p in cdir.glob("*.md") if p.is_file())
    if not checkpoints:
        return ""
    newest = checkpoints[-1]
    try:
        text = newest.read_text()
    except OSError:
        return ""
    return core.extract_checkpoint_blockers(text)


def load_registry_projects(registry_file: str, projects_filter: list[str] | None) -> dict:
    """Read the registry's `.projects` object, optionally filtered to a subset of names.

    The parameter is `registry_file`, not `registry_path`: this module now re-exports a
    module-level `registry_path` (see the top of the file) and the old parameter name shadowed it.
    """
    with open(registry_file, encoding="utf-8") as f:
        registry = json.load(f)
    projects: dict = registry.get("projects", {})
    if projects_filter:
        keep = set(projects_filter)
        projects = {k: v for k, v in projects.items() if k in keep}
    return projects


def write_projects_file(projects: dict, path: str) -> None:
    """Write the registry's projects object to a scratch file for adapters to read."""
    with open(path, "w", encoding="utf-8") as f:
        json.dump(projects, f)
