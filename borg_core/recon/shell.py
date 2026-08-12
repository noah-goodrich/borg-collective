"""I/O layer for the recon fan-out engine (ports lib/recon.sh's shell-out plumbing).

Every function here that touches the filesystem, subprocess, or the environment lives in this
module. Logic (parsing, validation, formatting) is delegated to core.py — this module never
reimplements it.
"""

from __future__ import annotations

import concurrent.futures
import json
import os
import subprocess
import time
from pathlib import Path

from borg_core.recon import core

DEFAULT_MAX_TRACKS = 8
DEFAULT_TRACK_TIMEOUT = 30
FALLBACK_WINDOW_SECONDS = 86400


def borg_dir() -> Path:
    """Resolve BORG_DIR, mirroring _recon_borg_dir (XDG-first)."""
    if os.environ.get("BORG_DIR"):
        return Path(os.environ["BORG_DIR"])
    xdg = os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config")
    return Path(xdg) / "borg"


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


def max_tracks() -> int:
    """Max concurrent recon tracks (bounded fan-out), mirroring _recon_max_tracks."""
    return int(os.environ.get("BORG_RECON_MAX_TRACKS", DEFAULT_MAX_TRACKS))


def track_timeout() -> int:
    """Per-adapter timeout in seconds, mirroring _recon_track_timeout."""
    return int(os.environ.get("BORG_RECON_TRACK_TIMEOUT", DEFAULT_TRACK_TIMEOUT))


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


def run_adapter(source: str, adapter_path: str, since: str, projects_file: str) -> dict:
    """Run one adapter as a subprocess under a timeout and normalize its output.

    Mirrors _recon_run_adapter: on any failure (non-zero exit, timeout, malformed output) returns
    a synthetic failed-track object so one bad source never aborts the sweep. Delegates all
    parsing/validation to core.process_adapter_output.
    """
    try:
        proc = subprocess.run(
            [adapter_path, "--since", since, "--projects", projects_file],
            capture_output=True,
            text=True,
            timeout=track_timeout(),
            check=False,
        )
        return core.process_adapter_output(source, proc.stdout, proc.returncode)
    except (subprocess.TimeoutExpired, OSError):
        return core.build_failed_track(source, -1)


def fanout(since: str, projects_file: str, adapters: list[tuple[str, str]]) -> list[dict]:
    """Fan out over adapters concurrently, bounded by max_tracks(). Mirrors _recon_fanout."""
    if not adapters:
        return []
    # JUSTIFICATION: stdlib ThreadPoolExecutor construction, not a layering violation.
    with concurrent.futures.ThreadPoolExecutor(  # pylint: disable=clean-arch-demeter
        max_workers=max_tracks()
    ) as pool:
        futures = [pool.submit(run_adapter, source, path, since, projects_file) for source, path in adapters]
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


def load_registry_projects(registry_path: str, projects_filter: list[str] | None) -> dict:
    """Read the registry's `.projects` object, optionally filtered to a subset of names."""
    with open(registry_path, encoding="utf-8") as f:
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
