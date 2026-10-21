"""The arrival brief: four plain lines a SessionStart hook shows the human, built from ONE `borg link --json` document.

PURE: no I/O of any kind. `brief(doc)` takes the parsed document of `borg link <repository> --json` and returns the
text of a top-level `systemMessage`; the hook (`arrival_hook.py`) is the thin impure wrapper that fetches the
document and prints. Nothing here reads the registry, git or a clock, so the brief is a PRESENTATION of the page's
own data and cannot become a second, drifting reader.

The four lines (the screen-4 mock of `2026-10-05-board-chooser-and-trains-ux.md`):

  last time   how old the newest checkpoint is, then its own tl;dr (free text, so it is the line that is cut)
  next        `render.next_action`: THE SAME DERIVATION AS THE REPOSITORY PAGE'S `next` LINE, plus who moves it
  watch out   derived facts first (STALE checkpoint, dirty tree, clock skew, ...), else `nothing flagged`
  since then  HEAD moves since the checkpoint (`focus.since`, additive), directives shipped since, last activity

Every line is at most `render.PAGE_COLUMNS` visible columns. A command is never cut: `next` narrows its own label
and repository to make room (`render._next_action_line`), and every other line is made of facts that are clipped at
part boundaries or free text that may end in `…`.
"""

from __future__ import annotations

import re
from datetime import datetime, timezone

from borg_core.link import core, render

# A checkpoint older than this many days is STALE: the `next` it states may no longer be true.
STALE_DAYS = 7
_PREFIX = 13  # " last time   ": one space, the label padded to 11, one space
_RULE_WIDTH = 60
_TLDR = re.compile(r"^\s*(?:\*\*)?tl;dr(?:\*\*)?\s*[-–—:]*\s*(?:\*\*)?\s*", re.IGNORECASE)
_SEP = " · "
_DAY = 86400
_CHECKPOINT_STAMP = re.compile(r"^(\d{4})-(\d{2})-(\d{2})(?:-(\d{2})(\d{2})(\d{2})?)?")
# The reflog messages that mean "history moved forward here": a commit (plain, merge, amend), a merge, or a pull.
_HEAD_MOVES = ("commit", "merge", "pull")


def checkpoint_epoch(filename: str) -> int | None:
    """Seconds since the epoch (local time) that a checkpoint FILENAME states, or None if it states none.

    `2026-10-19-162310-0e958b.md` and `2026-09-25-1704.md` both lead with a date and a clock; a bare date reads as
    midnight. The name is the only timestamp a checkpoint carries that survives a `git checkout`, which resets mtimes.
    """
    found = _CHECKPOINT_STAMP.match(filename)
    if found is None:
        return None
    year, month, day, hour, minute, second = (int(found[index] or 0) for index in range(1, 7))
    try:
        return int(datetime(year, month, day, hour, minute, second).timestamp())
    except (ValueError, OverflowError, OSError):
        return None


def count_head_moves(reflog: str, since_epoch: int) -> int:
    """How many of a `HEAD` reflog's entries after `since_epoch` are a commit, a merge or a pull.

    A reflog line is `<old> <new> <name> <email> <epoch> <tz>\\t<message>`. One pull that brings ten commits is ONE
    entry, so this counts moves of HEAD and is named that, never "commits".
    """
    moves = 0
    for line in reflog.splitlines():
        head, _, message = line.partition("\t")
        fields = head.rsplit(" ", 2)
        moved = len(fields) == 3 and fields[1].isdigit() and int(fields[1]) > since_epoch
        if moved and message.startswith(_HEAD_MOVES):
            moves += 1
    return moves


def session_mode(cwd: str, root: str) -> str:
    """`orchestrator` when `cwd` is exactly `root`, else `project`: `lib/borg-hooks.sh::_borg_session_mode`, ported.

    Trailing slashes are trimmed from both sides (a lone `/` stays), and the comparison is an exact string match, so
    a descendant of the workspace root is a repository session. tests/arrival_brief.bats runs both on one table.
    """
    return "orchestrator" if _trim(cwd) == _trim(root) else "project"


def _trim(path: str) -> str:
    while path.endswith("/") and path != "/":
        path = path[:-1]
    return path


def session_title(cwd: str) -> str:
    """The title a repository session is given when it has none: the directory's own name."""
    return _trim(cwd).rsplit("/", 1)[-1]


def unavailable(reason: str) -> str:
    """The one line a failed brief shows. Silence is never the fallback; this always says `unavailable`."""
    flat = " ".join(str(reason).split()) or "no reason given"
    return render.clip(f"borg: arrival brief unavailable ({flat})", render.PAGE_COLUMNS)


def _generated_epoch(doc: dict) -> int | None:
    try:
        return int(
            datetime.strptime(str(doc.get("generated_at")), core.ISO_FORMAT).replace(tzinfo=timezone.utc).timestamp()
        )
    except ValueError:
        return None


def _checkpoint_days(doc: dict) -> int | None:
    """Whole days between the newest checkpoint's filename stamp and the document's own `generated_at`."""
    names = (doc.get("focus") or {}).get("checkpoints") or []
    stamp = checkpoint_epoch(str(names[0])) if names else None
    now = _generated_epoch(doc)
    return None if stamp is None or now is None else max(now - stamp, 0) // _DAY


def _age(days: int) -> str:
    return "today" if days < 1 else ("yesterday" if days == 1 else f"{days}d ago")


def _row(label: str, text: str) -> str:
    return f" {label:<11} {text}"


def _facts_row(label: str, facts: list[str], empty: str) -> str:
    """A row of derived facts joined by `·`. A fact is kept WHOLE or dropped whole, never cut: the ones that do not
    fit are counted (`+2 more`), so a long line says something is missing instead of ending mid-fact."""
    room = render.PAGE_COLUMNS - _PREFIX
    kept: list[str] = []
    for fact in facts:
        more = len(facts) - len(kept) - 1
        tail = f"{_SEP}+{more} more" if more else ""
        if len(_SEP.join([*kept, fact])) + len(tail) > room and kept:
            break
        kept.append(fact)
    left = len(facts) - len(kept)
    text = _SEP.join(kept) + (f"{_SEP}+{left} more" if left else "")
    return _row(label, render.clip(text or empty, room))


def _tldr(head: str) -> str:
    """The checkpoint's own tl;dr paragraph, flat, else the first line that is prose, else ""."""
    lines = head.splitlines()
    for index, line in enumerate(lines):
        if _TLDR.match(line):
            paragraph = [_TLDR.sub("", line, count=1)]
            for more in lines[index + 1 :]:
                if not more.strip() or more.lstrip().startswith(("#", "-", "*")):
                    break
                paragraph.append(more)
            return " ".join(" ".join(paragraph).replace("**", "").split())
    return ""


def _last_time(doc: dict) -> str:
    focus = doc.get("focus") or {}
    if not focus.get("checkpoints"):
        return _row("last time", "no checkpoint yet; /borg-link-up writes one")
    days = _checkpoint_days(doc)
    said = _tldr(str(focus.get("checkpoint_head") or "")) or str((focus.get("entry") or {}).get("summary") or "")
    lead = f"{_age(days)}" if days is not None else "checkpoint"
    room = render.PAGE_COLUMNS - _PREFIX - len(lead) - len(_SEP)
    return _row("last time", f"{lead}{_SEP}{render.clip(said, room)}" if said else lead)


def _next(doc: dict) -> str:
    # The owner tag is appended AFTER the line, so the line is told how many columns to leave free for it, and its
    # indent difference (the page indents `next` by 2; the brief's value column is _PREFIX wide). The owner is
    # `yours`, `mine` or `unowned` (a checkpoint item nobody owns), and is present whenever the line names a next.
    _, owner = render.next_action(doc)
    tag = f"  owner: {owner}" if owner else ""
    line, _ = render.next_action(doc, reserve=_PREFIX - len("  next  ") + len(tag))
    return _row("next", line[len("next  ") :] + tag)


def _watch_out(doc: dict) -> str:
    entry = (doc.get("focus") or {}).get("entry") or {}
    days = _checkpoint_days(doc)
    facts: list[str] = []
    if days is not None and days >= STALE_DAYS:
        facts.append(f"STALE: checkpoint is {days}d old, verify its next in git")
    if entry.get("has_uncommitted_changes"):
        facts.append("uncommitted work left behind")
    skew = entry.get("clock_divergence") or {}
    if skew.get("detected"):
        facts.append(f"clock skew ~{int(skew.get('delta_seconds') or 0) // 60}m")
    if entry.get("waiting_reason"):
        facts.append(f"waiting: {entry['waiting_reason']}")
    capacity = doc.get("capacity") or {}
    if capacity.get("over_limit"):
        facts.append(f"{capacity.get('active')} active, limit {capacity.get('limit')}")
    if (doc.get("waiting") or {}).get("degraded"):
        facts.append("PR sweep degraded")
    return _facts_row("watch out", facts, "nothing flagged")


def _since_then(doc: dict) -> str:
    focus = doc.get("focus") or {}
    entry = focus.get("entry") or {}
    facts: list[str] = []
    moves = (focus.get("since") or {}).get("head_moves")
    if isinstance(moves, int):
        facts.append("HEAD has not moved" if moves == 0 else f"HEAD moved {moves} time{'s' if moves != 1 else ''}")
    names = focus.get("checkpoints") or []
    day = str(names[0])[:10] if names else ""
    shipped = [
        str(item.get("slug") or "")
        for item in focus.get("assimilated") or []
        if day and str(item.get("ship_date") or "") >= day
    ]
    if shipped:
        facts.append(f"{len(shipped)} directive{'s' if len(shipped) != 1 else ''} shipped")
    if entry.get("relative_activity"):
        facts.append(f"last active {entry['relative_activity']}")
    return _facts_row("since then", facts, "nothing recorded")


def brief(doc: dict) -> str:
    """The arrival brief for a repository session: a rule line naming the repository, then the four lines."""
    name = str((doc.get("focus") or {}).get("name") or "repository")
    head = render.clip(f"▸ {name} ", _RULE_WIDTH)
    rule = head + "─" * max(_RULE_WIDTH - len(head), 3)
    return "\n".join([rule, _last_time(doc), _next(doc), _watch_out(doc), _since_then(doc)])
