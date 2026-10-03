"""Pure logic for registry CRUD (ports lib/registry.zsh's `add`/`rm` slice).

This module is UNCONDITIONALLY free of raw I/O: no subprocess, no file open(), no network, no
environment reads. Every function here takes already-gathered data as arguments and returns plain
data structures or strings. All I/O (filesystem reads/writes, subprocess calls, environment
lookups) lives in shell.py, which calls into this module for the actual logic.
"""

from __future__ import annotations

import re

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


# ── short tmux window names ────────────────────────────────────────────────────────────────────
#
# The short name lives in the registry's existing `tmux_window` field. Everything here is PURE: the
# tmux session name and the registered projects are passed in, never read from the environment or
# the registry file, so the CLI boundary owns both lookups and these rules stay table-testable.

_SEPARATORS = "-_"
_SHORT_MAX = 6


def validate_window_name(candidate: str, project: str, session: str, projects: dict) -> str | None:
    """Why `candidate` cannot be `project`'s tmux window name, or None when it is valid.

    Rejected: empty; containing `.` or `:` (tmux target syntax); equal to the tmux session name
    (`session:window` would then be ambiguous); equal to any OTHER registered project's name or its
    `tmux_window`. `project` itself is excluded from the collision scan -- a project may keep its own
    name, and its current `tmux_window` is exactly what a re-set replaces.
    """
    if not candidate:
        return "window name must not be empty"
    if "." in candidate or ":" in candidate:
        return f"window name '{candidate}' must not contain '.' or ':' (tmux target syntax)"
    if candidate == session:
        return f"window name '{candidate}' equals the tmux session name"
    for other, entry in projects.items():
        if other == project:
            continue
        if candidate == other:
            return f"window name '{candidate}' is already the name of project '{other}'"
        if candidate == ((entry or {}).get("tmux_window") or None):
            return f"window name '{candidate}' is already the tmux window of project '{other}'"
    return None


def derive_window_name(project: str, session: str, projects: dict) -> str:
    """Deterministic short window name for `project`, falling back to longer forms on collision.

    Base form: name <= 6 chars -> the name; >= 3 segments on `-`/`_` -> their initials; otherwise the
    first 6 chars with trailing separators trimmed. If that is invalid, prefixes of length 7, 8, ...
    (trailing separators trimmed) are tried, and finally the full project name, returned even if it
    is itself invalid -- it is the project's identity and the last honest answer.
    """
    segments = [s for s in re.split(f"[{_SEPARATORS}]", project) if s]
    if len(project) <= _SHORT_MAX:
        base = project
    elif len(segments) >= 3:
        base = "".join(s[0] for s in segments)
    else:
        base = project[:_SHORT_MAX].rstrip(_SEPARATORS)

    candidates = [base]
    candidates += [project[:n].rstrip(_SEPARATORS) for n in range(_SHORT_MAX + 1, len(project))]
    for candidate in candidates:
        if validate_window_name(candidate, project, session, projects) is None:
            return candidate
    return project


def needs_derivation(entry: dict | None, project: str) -> bool:
    """True when `tmux_window` was never customized: absent, or still equal to the project name."""
    current = (entry or {}).get("tmux_window")
    return not current or current == project
