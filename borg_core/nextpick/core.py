"""PURE `borg next` ranking, chooser log rows and the follow-rate gate.

NO I/O OF ANY KIND -- no filesystem, no subprocess, no network, no clock. Callers pass in the registry
projects dict (and timestamps) that someone else read. `test_core.py` pins the purity by AST import walk.

`rank` reproduces borg.zsh's `cmd_next` jq pipeline exactly, including the quirks of jq's `sort_by`:
it is STABLE, `to_entries` walks object keys in sorted (codepoint) order so equal (score, last_activity)
pairs fall back to name order, and a null `last_activity` is coerced to "" by `// ""` so it sorts BEFORE
any real timestamp among equal scores.
"""

from __future__ import annotations

from typing import Any


def _falsy(value: Any) -> bool:
    """jq's `//` treats null AND false as empty."""
    return value is None or value is False


def _or(value: Any, default: Any) -> Any:
    return default if _falsy(value) else value


def _score(entry: dict[str, Any]) -> int:
    status = entry.get("status")
    score = 0
    if entry.get("pinned") is True:
        score += 200
    if status == "waiting":
        score += 100
    elif status == "active":
        score += 50
    elif status == "idle":
        score += 10
    if entry.get("last_activity") is None:
        score -= 50
    tmux_window = entry.get("tmux_window")
    if tmux_window is not None and tmux_window != "":
        score += 5
    return score


def rank(projects: dict[str, dict[str, Any]]) -> list[dict[str, Any]]:
    """Return non-archived projects best-first, as cmd_next's jq orders them."""
    items = []
    for name in sorted(projects):
        entry = projects[name]
        if entry.get("status") == "archived":
            continue
        items.append(
            {
                "name": name,
                "score": _score(entry),
                "status": entry.get("status"),
                "summary": _or(entry.get("summary"), ""),
                "waiting_reason": _or(entry.get("waiting_reason"), ""),
                "last_activity": _or(entry.get("last_activity"), ""),
                "pinned": _or(entry.get("pinned"), False),
                "path": _or(entry.get("path"), "null"),
            }
        )
    items.sort(key=lambda item: (-item["score"], item["last_activity"]))
    return items


# JUSTIFICATION: the row is a flat record of eleven independent facts; keyword-only keeps call sites honest.
# pylint: disable-next=too-many-arguments
def log_row(
    *,
    ts: str,
    session: str,
    ranked: list[dict[str, Any]],
    rec: str | None,
    opened: str | None,
    opened_after_s: float | None,
    active: str | None,
    switch: bool,
    chooser: bool,
    scripted: bool,
    shown: bool = False,
) -> dict[str, Any]:
    """One chooser-log row. A non-chooser invocation never showed anything and recommended nothing."""
    top3 = [
        {"project": item["name"], "rank": index + 1, "score": item["score"], "status": item["status"]}
        for index, item in enumerate(ranked[:3])
    ]
    if not chooser:
        shown, rec, opened, opened_after_s = False, None, None, None
    return {
        "ts": ts,
        "session": session,
        "shown": shown,
        "top3": top3,
        "rec": rec,
        "opened": opened,
        "opened_after_s": opened_after_s,
        "active": active,
        "switch": switch,
        "chooser": chooser,
        "scripted": scripted,
    }


def gate(rows: list[dict[str, Any]], min_rows: int = 20, threshold: float = 0.60) -> bool:
    """True once enough interactive chooser rows exist and the user follows the recommendation often enough."""
    eligible = [row for row in rows if row.get("chooser") is True and row.get("scripted") is False]
    if len(eligible) < min_rows:
        return False
    followed = sum(1 for row in eligible if row.get("opened") == row.get("rec"))
    return followed / len(eligible) >= threshold
