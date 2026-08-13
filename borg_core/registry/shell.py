"""I/O layer for registry CRUD (ports lib/registry.zsh's `add`/`rm` slice + the claude/tmux
lookups cmd_add depends on: lib/claude.zsh's session discovery, lib/tmux.zsh's window check).

Every function here that touches the filesystem, subprocess, or the environment lives in this
module. Logic (merging, sanitizing) is delegated to core.py -- this module never reimplements it.
"""

from __future__ import annotations

import json
import os
import subprocess
import time
from pathlib import Path

from borg_core import paths
from borg_core.registry import core

DEFAULT_TMUX_SESSION = "borg"


# Re-exported, not redefined: borg_core/paths.py holds the single definition of both, so this
# package keeps its own `shell.borg_dir()` / `shell.registry_path()` surface (and its tests) without
# a second copy of the resolution rules.
borg_dir = paths.borg_dir
registry_path = paths.registry_path


def read_registry() -> dict:
    """Read the registry, initializing it to {"projects": {}} if it doesn't exist yet.

    Mirrors borg_registry_read (which calls borg_registry_init first).
    """
    path = registry_path()
    if not path.is_file():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('{"projects":{}}', encoding="utf-8")
    text = path.read_text(encoding="utf-8")
    try:
        data: dict = json.loads(text)
    except json.JSONDecodeError as exc:
        # A corrupted registry.json (partial write, bad manual edit) fails with a clear, catchable
        # error rather than an unhandled traceback. Deliberately NOT degrading to an empty
        # registry here: a subsequent write would silently overwrite the corrupted-but-possibly-
        # recoverable file with a fresh empty one, which is worse than a loud failure.
        raise ValueError(f"registry.json is not valid JSON ({path}): {exc}") from exc
    return data


def write_registry(data: dict) -> None:
    """Atomically write the registry: sanitize, tmp file + rename.

    Mirrors _borg_registry_write's control-char stripping and tmp+mv atomicity. The zsh version
    also refuses an empty write, guarding against a `jq` crash piping zero bytes through; that
    failure mode doesn't exist here since `data` is an already-valid dict, not raw text from an
    external process, so `json.dumps` can never produce empty output for it.
    """
    text = core.strip_control_chars(json.dumps(data))
    path = registry_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.parent / f"{path.name}.tmp.{os.getpid()}"
    tmp.write_text(text, encoding="utf-8")
    os.replace(tmp, path)


def registry_has(name: str) -> bool:
    """Whether `name` is a key in the registry's .projects object."""
    return name in read_registry().get("projects", {})


def registry_merge(name: str, entry: dict) -> None:
    """Upsert `entry` into the registry under `name` (shallow-merge with any existing entry)."""
    registry = read_registry()
    projects = registry.setdefault("projects", {})
    projects[name] = core.merge_entry(projects.get(name), entry)
    write_registry(registry)


def registry_remove(name: str) -> None:
    """Delete `name` from the registry's .projects object, if present."""
    registry = read_registry()
    registry.get("projects", {}).pop(name, None)
    write_registry(registry)


def resolve_path(raw: str) -> str:
    """Resolve `raw` to a canonical absolute path, falling back to the raw string unchanged if it
    doesn't exist -- mirrors `realpath "$ppath" 2>/dev/null || echo "$ppath"`. BSD realpath (used
    by cmd_add on macOS) errors on a nonexistent path and the `||` fallback prints the raw,
    unresolved input; Python's os.path.realpath does not error on a nonexistent path, so the
    existence check here is what reproduces that fallback rather than silently normalizing it.
    """
    if not os.path.exists(raw):
        return raw
    return os.path.realpath(raw)


def claude_encode_path(path: str) -> str:
    """Convert /Users/noah/dev/troth -> -Users-noah-dev-troth, mirroring borg_claude_encode_path.

    Strips exactly one trailing slash (mirroring zsh's `${1%/}` suffix removal), not every
    trailing slash -- a doubled trailing slash leaves one behind, becoming an embedded dash.
    """
    if path.endswith("/"):
        path = path[:-1]
    return path.replace("/", "-")


def claude_project_dir(path: str) -> Path:
    """~/.claude/projects/<encoded-path>, mirroring borg_claude_project_dir."""
    return Path.home() / ".claude" / "projects" / claude_encode_path(path)


def claude_latest_session_id(path: str) -> str | None:
    """Most recently modified session's UUID for `path`, or None if none exist.

    Mirrors borg_claude_latest_session_id (zsh glob qualifiers (Nom[1]): nullglob, sort by mtime
    newest-first, take the first).
    """
    directory = claude_project_dir(path)
    if not directory.is_dir():
        return None
    # JUSTIFICATION: filesystem glob on a stdlib Path, not a cross-layer reach.
    jsonl_files = [p for p in directory.glob("*.jsonl") if p.is_file()]  # pylint: disable=clean-arch-demeter
    if not jsonl_files:
        return None
    # A file can vanish between the glob above and the stat below (e.g. Claude Code rotating an
    # old transcript concurrently) -- treat a since-deleted candidate as oldest rather than crash,
    # consistent with file_mtime_iso's own OSError handling a few lines below.
    newest = max(jsonl_files, key=_mtime_or_epoch)
    return newest.stem


def _mtime_or_epoch(path: Path) -> float:
    try:
        return path.stat().st_mtime
    except OSError:
        return 0.0


def claude_session_jsonl(path: str, session_id: str) -> Path:
    """Full path to a session's JSONL transcript, mirroring borg_claude_session_jsonl."""
    return claude_project_dir(path) / f"{session_id}.jsonl"


def file_mtime_iso(path: Path) -> str | None:
    """A file's mtime formatted like `stat -f "%Sm" -t "%Y-%m-%dT%H:%M:%SZ" "$jsonl"`, or None if
    the file doesn't exist.

    KNOWN BUG, preserved for parity: BSD stat's %Sm formats in LOCAL time -- the trailing 'Z' in
    the format string is a literal character, not a UTC conversion request. So the value this
    (and the original cmd_add) produces is local time mislabeled as UTC, not real UTC. Confirmed
    load-bearing: the sole downstream reader, lib/reaper.sh's _borg_should_reap, parses this same
    field with `date -j -u -f ...` (forcing UTC interpretation), so the write-side mislabel and the
    read-side mislabel cancel out into a correct staleness calculation. Computing genuine UTC here
    (e.g. via datetime.fromtimestamp(mtime, tz=timezone.utc)) would silently break that
    cancellation on any non-UTC machine. A future deliberate fix must change both sides together.
    """
    try:
        mtime = path.stat().st_mtime
    except OSError:
        return None
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.localtime(mtime))


def tmux_session_name() -> str:
    """The tmux session borg manages, mirroring lib/tmux.zsh's BORG_TMUX_SESSION default."""
    return os.environ.get("BORG_TMUX_SESSION", DEFAULT_TMUX_SESSION)


def tmux_window_exists(name: str) -> bool:
    """Whether a tmux window named `name` exists in borg's session.

    Mirrors borg_tmux_window_exists (which is borg_tmux_windows | grep -qx): if the session isn't
    alive, tmux's own commands fail and this returns False, same as the zsh short-circuit via
    borg_tmux_alive.
    """
    session = tmux_session_name()
    try:
        result = subprocess.run(
            ["tmux", "list-windows", "-t", session, "-F", "#W"],
            capture_output=True,
            text=True,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return False
    if result.returncode != 0:
        return False
    # JUSTIFICATION: splitting a subprocess's own captured stdout text, not a cross-layer reach.
    return name in result.stdout.splitlines()  # pylint: disable=clean-arch-demeter
