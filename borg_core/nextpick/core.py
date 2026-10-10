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
from borg_core import timefmt
from borg_core.link import grid, picture, render
from borg_core.planstate import core as planstate


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
                "repo": _or(entry.get("repo"), ""),
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


_LABEL_W = 22
_STEP_W = 18


def _line(n: str, label: str, step: str, owner: str, ready: str) -> str:
    return f"{n:>2} {_fit(label, _LABEL_W)} {_fit(step, _STEP_W)} {_fit(owner, 5)} {ready}".rstrip()


def _quiet_line(quiet: list[str], width: int) -> str:
    text = f"+{len(quiet)} quiet: {', '.join(quiet)}"
    return text if len(text) <= width else text[: width - 1] + "…"


def render_chooser(
    rows: list[dict[str, Any]],
    *,
    suggestion: str | None,
    width: int = 59,
    quiet: list[str] | None = None,
    hidden: dict[str, int] | None = None,
) -> list[str]:
    """Plain-text screen 2: header, rule, column header, one line per item row, optional `+N quiet` line, rule,
    optional suggestion, key hint. Every line is at most `width` visible columns, cut with an ellipsis."""
    rule = "─" * width
    lines = ["WHERE COULD YOUR FOCUS GO?", rule, _line("#", "project · item", "next step", "owner", "ready")]
    for row in rows:
        label = f"{row['project']} · {row['item']}" if row.get("item") else row["project"]
        lines.append(_line(str(row["n"]), label, row.get("next_step", ""), row.get("owner", ""), row.get("ready", "")))
    lines.extend(hidden_lines(hidden or {}))
    if quiet:
        lines.append(_quiet_line(quiet, width))
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


_CC_PREFIX = re.compile(r"^\s*[a-z]+(?:\([^)]*\))?!?:\s+", re.IGNORECASE)
ITEM_MAX = 18
STEP_MAX = 22
_PR_NUMBER = re.compile(r"#(\d+)\s*$")
_AC_HEAD = re.compile(r"^\**\s*(AC\d+)\s*[—–:-]*\s*(.*)$")


def short_title(title: str, limit: int = ITEM_MAX) -> str:
    """A PR title without its conventional-commit prefix, cut to `limit` characters with an ellipsis."""
    text = _CC_PREFIX.sub("", title or "", count=1).strip()
    return text if len(text) <= limit else text[: limit - 1].rstrip() + "…"


def _criterion_name(text: str) -> str:
    """ "**AC5 — The sweep sees every open PR.** ..." -> "AC5 The sweep sees every…"."""
    found = _AC_HEAD.findall(text.strip())
    if not found:
        return _truncate(text.replace("*", "").strip(), STEP_MAX)
    ident, rest = found[0]
    title = rest.split("**", 1)[0].strip().rstrip(".")
    return _truncate(f"{ident} {title}".strip(), STEP_MAX)


def _pr_number(item: dict[str, Any]) -> int:
    found = _PR_NUMBER.findall(str(item.get("ref") or ""))
    return int(found[0]) if found else 0


def _pr_row(item: dict[str, Any]) -> dict[str, Any]:
    """The one row an OPEN PR earns; the first matching rule wins. Owner never reads the PR author."""
    number = _pr_number(item)
    if item.get("draft"):
        step, owner, ready = f"finish #{number}", "AGENT", "◌"
    elif item.get("mergeable") == "CONFLICTING":
        step, owner, ready = f"resolve conflicts #{number}", "AGENT", "✗"
    elif item.get("checks") == "fail":
        step, owner, ready = f"fix #{number} CI", "AGENT", "✗"
    elif item.get("checks") == "pending":
        step, owner, ready = f"#{number} CI", "AGENT", "… run"
    elif item.get("review_decision") == "CHANGES_REQUESTED":
        step, owner, ready = f"address review #{number}", "AGENT", "○"
    else:
        step, owner, ready = f"merge #{number}", "YOU", "✔ now"
    return {
        "item": short_title(str(item.get("title") or "")),
        "next_step": step,
        "owner": owner,
        "ready": ready,
        "ref": item.get("ref"),
        "draft": bool(item.get("draft")),
        "changed": str(item.get("changed") or ""),
    }


def _plan_rows(plan: dict[str, Any] | None) -> list[dict[str, Any]]:
    """The active plan's first unchecked criterion as a row, or nothing."""
    if not plan:
        return []
    unchecked = [c for c in planstate.parse_criteria(str(plan.get("text") or "")) if not c["checked"]]
    if not unchecked:
        return []
    return [
        {
            "item": _truncate(str(plan.get("name") or ""), ITEM_MAX),
            "next_step": _criterion_name(unchecked[0]["text"]),
            "owner": "AGENT",
            "ready": "○",
            "ref": None,
        }
    ]


def work_items(
    ranked: list[dict[str, Any]],
    recon_items_by_project: dict[str, list[dict[str, Any]]],
    plans_by_project: dict[str, dict[str, Any]],
    checkpoint_steps: dict[str, str],
    now_epoch: int = 0,
) -> tuple[list[dict[str, Any]], list[str]]:
    """One row per actionable item, in ranked project order, plus the `quiet` project names.

    Row: `{project, item, next_step, owner, ready, ref, age}` (a waiting-session row also carries
    `waiting_reason`). Within a project: waiting session; open PRs (YOU merges first, then AGENT rows by PR
    number); the active plan's first unchecked criterion when no PR row exists; else the checkpoint next step.
    `plans_by_project[p]` is `{"name": str, "text": <PROJECT_PLAN.md text>}`, parsed by planstate.parse_criteria.
    """
    rows: list[dict[str, Any]] = []
    quiet: list[str] = []
    for entry in ranked:
        project = entry["name"]
        age = str(link_core.relative_time(entry.get("last_activity") or None, now_epoch))
        mine: list[dict[str, Any]] = []
        if entry.get("status") == "waiting":
            mine.append(
                {
                    "item": "session",
                    "next_step": "reply to session",
                    "owner": "YOU",
                    "ready": f"✔ {age}",
                    "ref": None,
                    "waiting_reason": entry.get("waiting_reason") or "",
                }
            )
        prs = [it for it in recon_items_by_project.get(project) or [] if it.get("state") == "open"]
        pr_rows = sorted(
            (_pr_row(it) for it in prs), key=lambda r: (r["owner"] != "YOU", _pr_number({"ref": r["ref"]}))
        )
        mine.extend(pr_rows)
        if not pr_rows:
            mine.extend(_plan_rows(plans_by_project.get(project)))
        step = checkpoint_steps.get(project, "")
        if not mine and step:
            mine.append({"item": "", "next_step": step, "owner": "—", "ready": "", "ref": None})
        if not mine:
            quiet.append(project)
        rows.extend({"project": project, **row, "age": age} for row in mine)
    return _dedupe_repo_groups(rows, ranked, now_epoch), quiet


STALE_DRAFT_DAYS = 30
SHOWN_MAX = 5


def _dedupe_repo_groups(
    rows: list[dict[str, Any]], ranked: list[dict[str, Any]], now_epoch: int
) -> list[dict[str, Any]]:
    """Drop rows a repo-sharing sibling project already carries, and flag stale drafts.

    Projects whose registry `repo` (the git common dir) is equal are views of ONE repo, so the same PR, plan or
    checkpoint step shows up under each. The best-ranked project keeps it. Session rows are never merged (each
    project has its own session), and a null / missing `repo` is a group of one. A draft PR whose last activity
    is older than `STALE_DRAFT_DAYS` days gets `stale: True`; with `now_epoch` 0 (no clock) nothing is stale.
    """
    repo_of = {entry["name"]: str(entry.get("repo") or "") for entry in ranked}
    cutoff = timefmt.epoch_to_iso(now_epoch - STALE_DRAFT_DAYS * 86400)[:19] if now_epoch else ""
    seen: set[tuple[str, ...]] = set()
    kept: list[dict[str, Any]] = []
    for row in rows:
        repo = repo_of.get(row["project"], "")
        if repo and row.get("item") != "session":
            identity = row.get("ref") or (row.get("item"), row.get("next_step"))
            key = (repo, str(identity))
            if key in seen:
                continue
            seen.add(key)
        changed = timefmt.iso_in_prose_to_utc(str(row.get("changed") or ""))[:19]
        stale = bool(cutoff and row.get("draft") and changed and changed < cutoff)
        kept.append({**row, "stale": stale})
    return kept


def cap_rows(
    work: list[dict[str, Any]], show_all: bool = False, limit: int = SHOWN_MAX
) -> tuple[list[dict[str, Any]], dict[str, int]]:
    """`(shown, hidden)`: at most `limit` YOU rows in existing order; everything else is only counted.

    `hidden` is `{agent, stale, overflow}`: stale drafts first (whoever owns them), then every other non-YOU row
    as `agent`, then YOU rows beyond `limit` as `overflow`. `show_all` returns every row and zero counts.
    """
    if show_all:
        return list(work), {"agent": 0, "stale": 0, "overflow": 0}
    hidden = {"agent": 0, "stale": 0, "overflow": 0}
    shown: list[dict[str, Any]] = []
    for row in work:
        if row.get("stale"):
            hidden["stale"] += 1
        elif row.get("owner") != "YOU":
            hidden["agent"] += 1
        elif len(shown) < limit:
            shown.append(row)
        else:
            hidden["overflow"] += 1
    return shown, hidden


def hidden_lines(hidden: dict[str, int]) -> list[str]:
    """The summary lines for the counts `cap_rows` hid, in a fixed order, omitting zeros."""
    labels = (("overflow", "more decisions"), ("agent", "agent tasks"), ("stale", "stale drafts"))
    return [f"+{hidden[key]} {text}" for key, text in labels if hidden.get(key)]


def numbered_rows(work: list[dict[str, Any]], ranked: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """`work_items` rows as the wire rows: `n` 1..len, the project's `status`, and a `waiting_reason` always set."""
    status = {entry["name"]: entry.get("status") or "" for entry in ranked}
    return [
        {
            "n": index + 1,
            "project": row["project"],
            "item": row.get("item", ""),
            "next_step": row.get("next_step", ""),
            "owner": row.get("owner", ""),
            "ready": row.get("ready", ""),
            "ref": row.get("ref"),
            "age": row.get("age", ""),
            "status": status.get(row["project"], ""),
            "waiting_reason": row.get("waiting_reason", ""),
        }
        for index, row in enumerate(work)
    ]
