"""PURE planner for the per-directory `.borg/state.json` -> per-project state-root migration. No I/O.

The shell layer (`project_shell.py`) observes each legacy file and its destination and hands this module
the observation; this module answers whether the precondition holds, what to do per file, and whether
the result is acceptable. Sibling of `core.py` (the config-dir migration); same contract.
"""

from __future__ import annotations

import json
from typing import NamedTuple

COPY = "copy"
KEEP_NEW = "keep-new"
SKIP = "skip"


class Project(NamedTuple):
    """One registry entry as the precondition sees it."""

    name: str
    repo: str | None
    git_backed: bool


class Entry(NamedTuple):
    """One observed legacy file: where it is, where it goes, and what exists.

    `tracked` is git's verdict on the legacy file; a tracked file is copied but never removed.
    """

    src: str
    dest: str
    legacy_present: bool
    new_present: bool
    tracked: bool = False


class Action(NamedTuple):
    """The decision for one entry. `remove_legacy` is False only for a tracked legacy file."""

    src: str
    dest: str
    op: str
    remove_legacy: bool


def precondition(projects: list[Project]) -> list[str]:
    """Names of git-backed entries with a null/empty `repo`. Non-empty means REFUSE: a key computed
    before `backfill-repo` would be `local-<path12>` and orphan the state once the repo is filled."""
    return sorted(p.name for p in projects if p.git_backed and not p.repo)


def op_for(entry: Entry) -> str:
    """Decide the operation: nothing to do, copy to the new path, or keep the newer new copy."""
    if not entry.legacy_present:
        return SKIP
    return KEEP_NEW if entry.new_present else COPY


def plan(entries: list[Entry]) -> list[Action]:
    """The full plan in stable order, one action per distinct destination. Idempotent: once the
    legacy file is gone every entry plans SKIP."""
    seen: set[str] = set()
    actions: list[Action] = []
    for entry in sorted(entries):
        if entry.dest in seen:
            continue
        seen.add(entry.dest)
        actions.append(Action(entry.src, entry.dest, op_for(entry), not entry.tracked))
    return actions


def expected_result(op: str, legacy: bytes, prev_new: bytes) -> bytes | None:
    """The bytes the new location must hold after `op`, or None for SKIP."""
    if op == COPY:
        return legacy
    if op == KEEP_NEW:
        return prev_new
    return None


def verify(op: str, legacy: bytes, prev_new: bytes, result: bytes) -> str | None:
    """None when acceptable, else the reason. Run BEFORE the legacy file goes."""
    want = expected_result(op, legacy, prev_new)
    if want is None or result != want:
        return "migrated bytes differ from the plan"
    try:
        json.loads(result)
    except ValueError as err:
        return f"result does not parse as JSON ({err})"
    return None
