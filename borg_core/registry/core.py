"""Pure logic for registry CRUD (ports lib/registry.zsh's `add`/`rm` slice).

This module is UNCONDITIONALLY free of raw I/O: no subprocess, no file open(), no network, no
environment reads. Every function here takes already-gathered data as arguments and returns plain
data structures or strings. All I/O (filesystem reads/writes, subprocess calls, environment
lookups) lives in shell.py, which calls into this module for the actual logic.
"""

from __future__ import annotations

# tr -d '\000-\010\013\014\016-\037' keeps tab (0x09), LF (0x0A), CR (0x0D); strips other C0
# control chars. Mirrors _borg_registry_write's sanitization pass before an atomic write.
_KEPT_CONTROL_CHARS = {0x09, 0x0A, 0x0D}


def strip_control_chars(text: str) -> str:
    """Strip raw C0 control characters that break jq/JSON parsing, keeping tab/LF/CR."""
    return "".join(ch for ch in text if ch >= " " or ord(ch) in _KEPT_CONTROL_CHARS)


def merge_entry(existing: dict | None, data: dict) -> dict:
    """Shallow-merge a new entry's fields into an existing one, new fields winning.

    Mirrors borg_registry_merge's jq: `if .projects[$p] then .projects[$p] += $data else
    .projects[$p] = $data end` -- a top-level shallow merge either way (an absent existing entry
    is equivalent to merging onto `{}`).
    """
    return {**(existing or {}), **data}


# JUSTIFICATION: six flat fields mirror cmd_add's `jq -n` object 1:1; a dataclass here is ceremony.
def build_add_entry(  # pylint: disable=too-many-arguments,too-many-positional-arguments
    path: str,
    source: str,
    tmux_session: str,
    tmux_window: str | None,
    session_id: str | None,
    last_activity: str | None,
) -> dict:
    """Build the registry entry payload for `borg add`, mirroring cmd_add's `jq -n` object."""
    return {
        "path": path,
        "source": source,
        "tmux_session": tmux_session,
        "tmux_window": tmux_window or None,
        "claude_session_id": session_id or None,
        "last_activity": last_activity or None,
        "summary": None,
    }
