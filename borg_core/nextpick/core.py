"""PURE `borg next` ranking, chooser log rows and the follow-rate gate.

NO I/O OF ANY KIND -- no filesystem, no subprocess, no network, no clock. Callers pass in the registry
projects dict (and timestamps) that someone else read. `test_core.py` pins the purity by AST import walk.

`rank` reproduces borg.zsh's `cmd_next` jq pipeline exactly, including the quirks of jq's `sort_by`:
it is STABLE, `to_entries` walks object keys in sorted (codepoint) order so equal (score, last_activity)
pairs fall back to name order, and a null `last_activity` is coerced to "" by `// ""` so it sorts BEFORE
any real timestamp among equal scores.
"""

from __future__ import annotations

import re
from typing import Any

from borg_core.link import core as link_core
from borg_core.link import grid, picture, render


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


_BLANK = {"item": "", "next_step": "", "owner": "", "ready": ""}


def _project_ready(path: str, manifests: list[dict[str, Any]]) -> dict[str, str]:
    """The first ready row of the manifests that live under `path`, routed exactly as `▸ NEXT` routes it.

    A manifest belongs to a project when its file sits inside the project directory. A manifest whose READY set
    is `unlooked` (nothing resolved, e.g. `--local`) contributes nothing, as `render._next_tally` skips it.
    Within a manifest `rows[].next` orders first, then ref, the same stable order `_next_tally` uses.
    """
    if not path or path == "null":
        return dict(_BLANK)
    prefix = path.rstrip("/") + "/"
    for manifest in manifests:
        if not str(manifest.get("path") or "").startswith(prefix):
            continue
        ready = manifest.get("ready") or {}
        if ready.get("state") == grid.STATE_READY_UNLOOKED:
            continue
        nodes = manifest.get("nodes") or {}
        refs = sorted((not (nodes.get(ref) or {}).get("next"), ref) for ref in ready.get("refs") or [])
        if not refs:
            continue
        ref = refs[0][1]
        gate_: dict[str, Any] = next((g for g in manifest.get("gates") or [] if g.get("ref") == ref), {})
        return {
            "item": ref,
            "next_step": gate_.get("blocked_by") or ref,
            "owner": render.route_kind(gate_.get("kind") or ""),
            "ready": picture.state_glyph(nodes.get(ref) or {}),
        }
    return dict(_BLANK)


_NEXT_HEADING = re.compile(r"^##\s*5\.?\s*next\s+session\b", re.IGNORECASE)
_ANY_H2 = re.compile(r"^##\s")
_LIST_MARKER = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s+")
NEXT_STEP_MAX = 80


def _truncate(text: str, limit: int = NEXT_STEP_MAX) -> str:
    return text if len(text) <= limit else text[: limit - 1].rstrip() + "…"


def checkpoint_next_step(text: str) -> str:
    """The first item of a checkpoint's `## 5. Next Session` section, or "" when there is none.

    The first block after the heading: a list item (marker or number stripped, wrapped continuation lines joined)
    or the first prose paragraph. Whitespace is collapsed and the result truncated to `NEXT_STEP_MAX` with an
    ellipsis. Text before the heading (a tl;dr preamble) is never inspected.
    """
    lines = text.splitlines()
    for index, line in enumerate(lines):
        if _NEXT_HEADING.match(line.strip()):
            body = lines[index + 1 :]
            break
    else:
        return ""
    block: list[str] = []
    for line in body:
        if _ANY_H2.match(line):
            break
        if not line.strip():
            if block:
                break
            continue
        if block and _LIST_MARKER.match(line):
            break
        block.append(_LIST_MARKER.sub("", line, count=1))
    return _truncate(" ".join(" ".join(block).split()))


def chooser_rows(
    ranked: list[dict[str, Any]],
    link_doc: dict[str, Any] | None,
    fallbacks: dict[str, str] | None = None,
    now_epoch: int = 0,
) -> list[dict[str, Any]]:
    """One row per ranked project, ranked order: `{n, project, item, next_step, owner, ready, status, age,
    waiting_reason}`.

    Cells come from the link document's grid manifests via `render.route_kind` (owner) and `picture.state_glyph`
    (ready glyph). A project with no manifest, or a None / degraded document, gets blank cells, never an error.
    `next_step` falls back to `fallbacks[project]` (the latest checkpoint's first next-session item) when no
    manifest supplied one. `age` is `link_core.relative_time`, the string `borg link` shows.
    """
    manifests = ((link_doc or {}).get("grid") or {}).get("manifests") or []
    rows = []
    for index, item in enumerate(ranked):
        cells = _project_ready(str(item.get("path") or ""), manifests)
        if not cells["next_step"]:
            cells["next_step"] = (fallbacks or {}).get(item["name"], "")
        rows.append(
            {
                "n": index + 1,
                "project": item["name"],
                **cells,
                "status": item.get("status") or "",
                "age": str(link_core.relative_time(item.get("last_activity") or None, now_epoch)),
                "waiting_reason": item.get("waiting_reason") or "",
            }
        )
    return rows


def split_quiet(rows: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], list[str]]:
    """Move idle rows with no next step and no waiting reason out of `rows`; return (kept, quiet names).

    Rank-relative order is preserved on both sides, and kept rows are renumbered so `n` stays 1..len(kept).
    """
    kept: list[dict[str, Any]] = []
    quiet: list[str] = []
    for row in rows:
        if row.get("status") == "idle" and not row.get("next_step") and not row.get("waiting_reason"):
            quiet.append(row["project"])
        else:
            kept.append({**row, "n": len(kept) + 1})
    return kept, quiet


def _fit(text: str, width: int) -> str:
    """Pad or truncate to exactly `width` visible characters, ending a truncation with an ellipsis."""
    if len(text) > width:
        return text[: width - 1] + "…"
    return text.ljust(width)


_LABEL_W = 24
_STEP_W = 19


def _line(n: str, label: str, step: str, owner: str, ready: str) -> str:
    return f"{n:>2} {_fit(label, _LABEL_W)} {_fit(step, _STEP_W)} {_fit(owner, 5)} {ready}".rstrip()


def render_chooser(rows: list[dict[str, Any]], *, suggestion: str | None, width: int = 59) -> list[str]:
    """Plain-text screen 2: header, rule, column header, one line per row, rule, optional suggestion, key hint."""
    rule = "─" * width
    lines = ["WHERE COULD YOUR FOCUS GO?", rule, _line("#", "project · item", "next step", "owner", "ready")]
    for row in rows:
        label = f"{row['project']} · {row['item']}" if row.get("item") else row["project"]
        lines.append(_line(str(row["n"]), label, row.get("next_step", ""), row.get("owner", ""), row.get("ready", "")))
    lines.append(rule)
    if suggestion is not None:
        lines.append(f"▸ suggested: {suggestion}")
    lines.append("⏎ top · 1-9 open · q quit")
    return [line if len(line) <= width else line[: width - 1] + "…" for line in lines]


def suggestion_for(rows: list[dict[str, Any]], log_rows: list[dict[str, Any]]) -> str | None:
    """The top row's label ("<n> <project>") only once the follow-rate `gate` has passed, else None."""
    if not rows or not gate(log_rows):
        return None
    return f"{rows[0]['n']} {rows[0]['project']}"
