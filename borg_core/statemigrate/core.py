"""PURE planner for the config -> state-root migration. No I/O of any kind.

The shell layer (`shell.py`) observes which MOVED files exist at the old and new locations and hands
this module that observation; this module answers what to do and whether the result is acceptable.
The MOVED list mirrors `docs/state-census.md` ("Where each file under the config dir lives"). STAYS
files are absent from it on purpose: a file that is not named here can never be planned.
"""

from __future__ import annotations

import json
from typing import NamedTuple

# Exact relative names (to the config dir) that moved.
MOVED_FILES: tuple[str, ...] = (
    "cortex-wakes.json",
    "memory-gate-state.json",
    "memory-gate-verdict.json",
    "usage-guardian.json",
    "pr-watch-snapshot.json",
    "pr-watch-delta.md",
    "pr-watch.log",
    "recon/last-run",
    "plan-promote-debug.log",
    "memory-hits.log",
    "agents.jsonl",
    "prefer-tool.jsonl",
)
# Subdirectory + suffix families, discovered by the shell layer: (directory, glob).
MOVED_GLOBS: tuple[tuple[str, str], ...] = (
    ("devcontainer-hashes", "*.hash"),
    (".", "briefing-*-stderr.log"),  # matches briefing-stderr.log and briefing-<stage>-stderr.log
)

# Genuinely append-only histories: when both copies exist the old history goes first.
APPEND_ONLY: frozenset[str] = frozenset(
    {"pr-watch.log", "plan-promote-debug.log", "memory-hits.log", "agents.jsonl", "prefer-tool.jsonl"}
)

MOVE = "move"
APPEND = "append"
KEEP_NEW = "keep-new"
SKIP = "skip"


class Entry(NamedTuple):
    """One observed file: its path relative to the config dir and where it exists."""

    rel: str
    old_present: bool
    new_present: bool


class Action(NamedTuple):
    """The decision for one entry."""

    rel: str
    op: str


def op_for(entry: Entry) -> str:
    """Decide the operation for one observed file."""
    if not entry.old_present:
        return SKIP
    if not entry.new_present:
        return MOVE
    return APPEND if entry.rel in APPEND_ONLY else KEEP_NEW


def plan(entries: list[Entry]) -> list[Action]:
    """The full plan, in a stable order. Idempotent by construction: once the old copy is gone,
    every entry plans SKIP. A path that is not MOVED is dropped, never planned."""
    return [Action(e.rel, op_for(e)) for e in sorted(entries) if is_moved(e.rel)]


def is_moved(rel: str) -> bool:
    """True when `rel` names a MOVED file (exact or by family)."""
    if rel in MOVED_FILES:
        return True
    head, _, tail = rel.rpartition("/")
    if head == "devcontainer-hashes" and tail.endswith(".hash") and tail != ".hash":
        return True
    return not head and (
        tail == "briefing-stderr.log" or (tail.startswith("briefing-") and tail.endswith("-stderr.log"))
    )


def expected_result(op: str, old: bytes, prev_new: bytes) -> bytes | None:
    """The bytes the new location must hold after `op`, or None for SKIP."""
    if op == MOVE:
        return old
    if op == APPEND:
        return old + _newline_if_needed(old, prev_new) + prev_new
    if op == KEEP_NEW:
        return prev_new
    return None


def _newline_if_needed(old: bytes, prev_new: bytes) -> bytes:
    """Never glue the last old line to the first new one."""
    return b"\n" if old and prev_new and not old.endswith(b"\n") else b""


def verify(rel: str, op: str, old: bytes, prev_new: bytes, result: bytes) -> str | None:
    """None when the migrated bytes are acceptable, else the reason. Run BEFORE the old copy goes."""
    want = expected_result(op, old, prev_new)
    if want is None or result != want:
        return f"{rel}: migrated bytes differ from the plan ({len(result)} vs {len(want or b'')})"
    if rel.endswith(".json"):
        try:
            json.loads(result)
        except ValueError as err:
            return f"{rel}: result does not parse as JSON ({err})"
    return None
