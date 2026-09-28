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
    repo: str | None = None,
) -> dict:
    """Build the registry entry payload for `borg add`, mirroring cmd_add's `jq -n` object.

    `repo` IS THE ONE IDENTITY FIELD, and it is additive. Every other key here describes a
    directory; `repo` -- the absolute `--git-common-dir` from `shell.git_common_dir` -- says which
    git clone that directory belongs to. Without it `borg add` recorded no repo, no parent and no
    kind, so a git worktree was not a view of a project, it WAS one: its own checkpoint store, its
    own plan slot, its own state.json, invisible to its parent and vice versa.

    DEFAULTED, NOT REQUIRED, which is the expand phase of expand -> migrate -> contract. Entries
    written before this field existed keep working unchanged -- `link.core.repo_sources` resolves a
    missing or null `repo` to a group of one, which is exactly the pre-change behaviour -- so no
    existing registry entry is read by a rule it was not written to satisfy. `borg add` populates it
    from here on; `borg_core.registry.cli backfill-repo` is the migrate phase for what is already
    there. No contract phase is scheduled: a registered directory outside any git repository has no
    common dir, so null stays a legal value permanently rather than becoming one to eliminate.
    """
    return {
        "path": path,
        "source": source,
        "tmux_session": tmux_session,
        "tmux_window": tmux_window or None,
        "claude_session_id": session_id or None,
        "last_activity": last_activity or None,
        "summary": None,
        "repo": repo or None,
    }
