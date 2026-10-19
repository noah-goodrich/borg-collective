"""PURE `borg next` ranking, chooser log rows and the follow-rate gate.

NO I/O OF ANY KIND -- no filesystem, no subprocess, no network, no clock. Callers pass in the registry
repositories dict (and timestamps) that someone else read. `test_core.py` pins the purity by AST import walk.

`rank` reproduces borg.zsh's `cmd_next` jq pipeline exactly, including the quirks of jq's `sort_by`:
it is STABLE, `to_entries` walks object keys in sorted (codepoint) order so equal (score, last_activity)
pairs fall back to name order, and a null `last_activity` is coerced to "" by `// ""` so it sorts BEFORE
any real timestamp among equal scores.
"""

from __future__ import annotations

import re
from typing import Any

from borg_core.compass import core as compass_core
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


def rank(repositories: dict[str, dict[str, Any]], compass: dict[str, Any] | None = None) -> list[dict[str, Any]]:
    """Return non-archived repositories best-first, as cmd_next's jq orders them.

    With a `compass` block (`found` true) the compass decides FIRST, by `compass_core.leg_priority`: repositories on
    today's leg, then by nearest due date, then undated active, then frozen, done and unmapped. The score and
    last-activity tie-breaks above are untouched and decide inside each bucket. With no compass, or one that found no
    map, every repository carries the same prefix and the order is exactly what it was.
    """
    items = []
    for name in sorted(repositories):
        entry = repositories[name]
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
    items.sort(
        key=lambda item: (*compass_core.leg_priority(compass, item["name"]), -item["score"], item["last_activity"])
    )
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


def _repository_ready(path: str, manifests: list[dict[str, Any]]) -> dict[str, str]:
    """The first ready row of the manifests that live under `path`, routed exactly as `▸ NEXT` routes it.

    A manifest belongs to a repository when its file sits inside the repository directory. A manifest whose READY set
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
    """One row per ranked repository, ranked order: `{n, project, item, next_step, owner, ready, status, age,
    waiting_reason}`.

    Cells come from the link document's grid manifests via `render.route_kind` (owner) and `picture.state_glyph`
    (ready glyph). A repository with no manifest, or a None / degraded document, gets blank cells, never an error.
    `next_step` falls back to `fallbacks[repository]` (the latest checkpoint's first next-session item) when no
    manifest supplied one. `age` is `link_core.relative_time`, the string `borg link` shows.
    """
    manifests = ((link_doc or {}).get("grid") or {}).get("manifests") or []
    rows = []
    for index, item in enumerate(ranked):
        cells = _repository_ready(str(item.get("path") or ""), manifests)
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
    lines = ["WHERE COULD YOUR FOCUS GO?", rule, _line("#", "repository · item", "next step", "owner", "ready")]
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
    """The top row's label ("<n> <repository>") only once the follow-rate `gate` has passed, else None."""
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


def _repo_of(item: dict[str, Any]) -> str:
    return str(item.get("ref") or "").rsplit("#", 1)[0]


def _parent_numbers(prs: list[dict[str, Any]]) -> dict[str, int]:
    """Map each stacked PR's ref to the number of the OPEN PR it is stacked on.

    A PR is stacked when its `base_ref` is the `head_ref` of another open PR in the same repository. Derived here
    from the raw items so no caller can supply a parent the adapter never emitted. An item without `base_ref`
    (older cached data) is never stacked. With several candidate parents the lowest number wins.
    """
    parents: dict[str, int] = {}
    for child in prs:
        base = str(child.get("base_ref") or "")
        if not base:
            continue
        candidates = [
            _pr_number(other)
            for other in prs
            if other is not child
            and str(other.get("head_ref") or "") == base
            and _repo_of(other) == _repo_of(child)
            and _pr_number(other)
        ]
        if candidates:
            parents[str(child.get("ref") or "")] = min(candidates)
    return parents


def _pr_row(item: dict[str, Any], parent: int | None = None) -> dict[str, Any]:
    """The one row an OPEN PR earns; the first matching rule wins. Owner never reads the PR author.

    `parent` is the open PR this one is stacked on (see `_parent_numbers`); merging it now would land in a
    feature branch, so it waits below the rules that are still its own work (draft, conflicts, CI, review changes).
    """
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
    elif parent is not None:
        step, owner, ready = f"await #{parent}", "—", "… wait"
    elif item.get("review_decision") == "REVIEW_REQUIRED":
        # GitHub blocks the merge until a reviewer approves, so it is not a decision the owner can act on.
        step, owner, ready = f"await review #{number}", "—", "… wait"
    else:
        step, owner, ready = f"merge #{number}", "YOU", "✔ now"
    return {
        "item": short_title(str(item.get("title") or "")),
        "next_step": step,
        "owner": owner,
        "ready": ready,
        "ref": item.get("ref"),
        "url": str(item.get("url") or ""),
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
    plans_by_repository: dict[str, dict[str, Any]],
    checkpoint_steps: dict[str, str],
    now_epoch: int = 0,
) -> tuple[list[dict[str, Any]], list[str]]:
    """One row per actionable item, in ranked repository order, plus the `quiet` repository names.

    Row: `{project, item, next_step, owner, ready, ref, age}` (a waiting-session row also carries
    `waiting_reason`). Within a repository: waiting session; open PRs (YOU merges first, then AGENT rows by PR
    number); the active plan's first unchecked criterion when no PR row exists; else the checkpoint next step.
    `plans_by_repository[p]` is `{"name": str, "text": <PROJECT_PLAN.md text>}`, parsed by planstate.parse_criteria.
    """
    rows: list[dict[str, Any]] = []
    quiet: list[str] = []
    for entry in ranked:
        repository = entry["name"]
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
        prs = [it for it in recon_items_by_project.get(repository) or [] if it.get("state") == "open"]
        parents = _parent_numbers(prs)
        pr_rows = sorted(
            (_pr_row(it, parents.get(str(it.get("ref") or ""))) for it in prs),
            key=lambda r: (r["owner"] != "YOU", _pr_number({"ref": r["ref"]})),
        )
        mine.extend(pr_rows)
        if not pr_rows:
            mine.extend(_plan_rows(plans_by_repository.get(repository)))
        step = checkpoint_steps.get(repository, "")
        if not mine and step:
            mine.append({"item": "", "next_step": step, "owner": "—", "ready": "", "ref": None})
        if not mine:
            quiet.append(repository)
        rows.extend({"project": repository, **row, "age": age} for row in mine)
    return _dedupe_repo_groups(rows, ranked, now_epoch), quiet


STALE_DRAFT_DAYS = 30
SHOWN_MAX = 5


def _dedupe_repo_groups(
    rows: list[dict[str, Any]], ranked: list[dict[str, Any]], now_epoch: int
) -> list[dict[str, Any]]:
    """Drop rows a repo-sharing sibling repository already carries, and flag stale drafts.

    Repositories whose registry `repo` (the git common dir) is equal are views of ONE repo, so the same PR, plan or
    checkpoint step shows up under each. The best-ranked repository keeps it. Session rows are never merged (each
    repository has its own session), and a null / missing `repo` is a group of one. A draft PR whose last activity
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
    """`work_items` rows as the wire rows: `n` 1..len, the repository's `status`, and a `waiting_reason` always set."""
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
            "url": row.get("url", ""),
            "age": row.get("age", ""),
            "status": status.get(row["project"], ""),
            "waiting_reason": row.get("waiting_reason", ""),
        }
        for index, row in enumerate(work)
    ]


CARD_WIDTH = 42
CARD_LINES = 6


def _cut(text: str, width: int) -> str:
    """`text` as one line of at most `width` columns, a cut ending in an ellipsis."""
    text = " ".join(text.split())
    return text if len(text) <= width else text[: width - 1] + "…"


def _wrap(text: str, width: int, max_lines: int, indent: str = "") -> list[str]:
    """Greedy word wrap into at most `max_lines` lines of `width`; the last line ends in an ellipsis when text is lost.

    A word wider than a line goes on a line of its own, uncut: that is how the command keeps its repository name.
    """
    if max_lines < 1:
        return []
    lines: list[str] = []
    current = ""
    for word in text.split():
        trial = f"{current} {word}" if current else word
        if len(trial) <= width or not current:
            current = trial
        else:
            lines.append(current)
            current = indent + word
    if current:
        lines.append(current)
    if len(lines) > max_lines:
        lines = [*lines[: max_lines - 1], _cut(" ".join(lines[max_lines - 1 :]), width)]
    return lines


def chooser_card(row: dict[str, Any], *, shown: bool = False) -> list[str]:
    """The preview card `/borg-next` shows beside a row's option: at most `CARD_LINES` lines of `CARD_WIDTH` columns.

    The last line is the exact command choosing the row runs. The command and the ref are never cut. When the command
    is wider than the card it wraps at word boundaries onto indented lines, and the label lines give way to it first:
    the waiting reason goes, then the meta line, then the next step shrinks, and the label is always kept.
    `shown` adds `--shown`, because the skill logs it iff a suggestion was displayed.

    PURE: the text is copied from checkpoints and session state, so the skill shows it as data.
    """
    command = f"borg next --open {row['project']} --chosen" + (" --shown" if shown else "")
    command_lines = _wrap(command, CARD_WIDTH, 99, indent="  ")
    room = max(CARD_LINES - len(command_lines), 1)
    label = row["project"] + (f" · {row['item']}" if row.get("item") else "")
    room -= 1
    step = _wrap(row.get("next_step") or "", CARD_WIDTH, min(2, max(room, 0)))
    room -= len(step)
    ref = row.get("ref")
    meta = [str(ref)] if ref else []
    meta += [row.get("owner") or "—", row.get("ready") or "—"]
    meta_line = " · ".join(meta)
    if len(meta_line) > CARD_WIDTH and ref:
        meta_line = f"{ref} · " + _cut(" · ".join(meta[1:]), max(CARD_WIDTH - len(str(ref)) - 3, 1))
    head = [_cut(label, CARD_WIDTH)]
    if room >= 1:
        head.append(meta_line if ref else _cut(meta_line, CARD_WIDTH))
        room -= 1
    head += step
    if room >= 1 and row.get("waiting_reason"):
        head.append(_cut(f"“{row['waiting_reason']}”", CARD_WIDTH))
    return [*head, *command_lines]
