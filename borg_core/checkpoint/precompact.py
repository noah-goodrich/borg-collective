"""Pure assembler for the PreCompact checkpoint: already-read facts in, one checkpoint document out.

NO I/O of any kind: no clock, no environment, no subprocess, no filesystem. `precompact_hook.py` reads the facts.

WHY THE DOCUMENT CARRIES SECTIONS FORWARD (#503). `borg next`, `borg link` and the arrival brief read each repository's
NEWEST checkpoint whole, and the person's rows are the `Waits on you:` lines of its `## 4. Blockers` section (the
agent's rows are the items of `## 5. Next Session`, the one-line summary is its `**tl;dr**`). A minimal automatic
checkpoint that became the newest file would therefore hide every row of the real /borg-link-up checkpoint before it.
So this document CARRIES THE PREVIOUS CHECKPOINT'S tl;dr, Goal, Blockers and Next Session sections forward VERBATIM:
every reader then sees the same rows it saw a second ago, with no reader changed and no new "skip auto files" rule for
the five readers (and any future one) to agree on. When there is no previous checkpoint the Blockers and Next Session
sections say so in prose with NO list item, so the readers derive no phantom row.

The first line after the tl;dr is an HTML comment marker (`AUTO_MARKER`), so a human or a tool can tell this file from a
link-up checkpoint, and nothing renders it.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass

AUTO_MARKER = "borg:auto-checkpoint"
MAX_MESSAGE_CHARS = 1500
MAX_STATUS_LINES = 60
MAX_LINE_CHARS = 200

_H2 = re.compile(r"^##\s")
_NUMBERED = re.compile(r"^##\s*([1-5])\.?\s")
_UNBORN = re.compile(r"^(?:No commits yet on|Initial commit on) ")
_TLDR = re.compile(r"^\s*\*\*tl;dr\*\*", re.IGNORECASE)

NO_PREVIOUS_GOAL = "Not recorded: no /borg-link-up checkpoint came before this automatic one."
NO_PREVIOUS_BLOCKERS = "No blockers recorded: this is an automatic checkpoint, not a link-up."
NO_PREVIOUS_NEXT = (
    "No next action was recorded (no /borg-link-up ran). Start from the last user message under section 2, "
    "then check the git status under section 3."
)
DEFAULT_TLDR = (
    "**tl;dr** — Automatic checkpoint written just before context compaction; nobody ran /borg-link-up, so the goal "
    "and next action are carried forward from the previous checkpoint when there is one."
)


def last_user_text(transcript_lines: list[str]) -> str:
    """The text of the newest real user message in transcript JSONL lines, or "".

    Skips tool results (a `user` entry whose content has no text block), meta entries, sidechains, compaction
    summaries and slash-command plumbing (`<command-...>`, `<local-command-...>`), which are not something the person
    typed. Unparseable lines are skipped. Newest first: the caller may pass only the tail of a large transcript.
    """
    for raw in reversed(transcript_lines):
        try:
            entry = json.loads(raw)
        except ValueError:
            continue
        if not isinstance(entry, dict) or entry.get("type") != "user":
            continue
        if entry.get("isMeta") or entry.get("isSidechain") or entry.get("isCompactSummary"):
            continue
        message = entry.get("message")
        content = message.get("content") if isinstance(message, dict) else None
        if isinstance(content, list):
            content = "\n".join(
                block.get("text", "") for block in content if isinstance(block, dict) and block.get("type") == "text"
            )
        if not isinstance(content, str):
            continue
        text = content.strip()
        if text and not text.startswith(("<command-", "<local-command", "Caveat:")):
            return text
    return ""


def last_user_text_cortex(history_lines: list[str]) -> str:
    """The text of the newest real user prompt in a Cortex `<id>.history.jsonl`, or "".

    Cortex's `transcript_path` is `<id>.json`, a metadata document with no messages; the messages are the JSONL beside
    it. A real prompt is a `role: user` entry with a text block flagged `is_user_prompt`. Tool results and injected
    context (`internalOnly`, no `is_user_prompt`) are skipped, and so is slash-command plumbing. Newest first.
    """
    for raw in reversed(history_lines):
        try:
            entry = json.loads(raw)
        except ValueError:
            continue
        if not isinstance(entry, dict) or entry.get("role") != "user" or not isinstance(entry.get("content"), list):
            continue
        parts = [
            block.get("text", "")
            for block in entry["content"]
            if isinstance(block, dict)
            and block.get("type") == "text"
            and block.get("is_user_prompt") is True
            and not block.get("internalOnly")
            and isinstance(block.get("text"), str)
        ]
        text = "\n".join(parts).strip()
        if text and not text.startswith(("<command-", "<local-command", "Caveat:")):
            return text
    return ""


_MARKER = re.compile(rf"^<!-- {re.escape(AUTO_MARKER)} trigger=\S+ session=(\S+) carried-from=(\S+) -->$", re.MULTILINE)


def auto_marker(body: str) -> tuple[str, str] | None:
    """`(session, carried_from)` when `body` is an automatic checkpoint, else None."""
    found = _MARKER.search(body)
    return (found[1], found[2]) if found else None


def _clip(text: str, limit: int) -> str:
    return text if len(text) <= limit else text[: limit - 1].rstrip() + "…"


def split_checkpoint(text: str) -> dict[str, str]:
    """The parts of a checkpoint worth carrying: `tldr` and `1`, `4`, `5` (a numbered section, heading line included).

    Every value is the block's lines verbatim, trailing blank lines dropped. A part that is absent is absent from the
    dict. The tl;dr is the paragraph that starts at the `**tl;dr**` line and ends at the first blank line or heading.
    A block ends at the next `## ` heading of ANY kind, so an appendix is never swallowed into section 5.
    """
    lines = text.splitlines()
    parts: dict[str, str] = {}
    for index, line in enumerate(lines):
        if _TLDR.match(line) and "tldr" not in parts:
            block = [line]
            for follower in lines[index + 1 :]:
                if not follower.strip() or _H2.match(follower):
                    break
                block.append(follower)
            parts["tldr"] = "\n".join(block)
    current: str | None = None
    body: list[str] = []
    for line in [*lines, "## end"]:
        if _H2.match(line):
            if current is not None and current not in parts:
                parts[current] = "\n".join(body).rstrip()
            found = _NUMBERED.match(line)
            current = found[1] if found and found[1] in ("1", "4", "5") else None
            body = [line]
        elif current is not None:
            body.append(line)
    return parts


def _body(part: str | None, heading: str, fallback: str) -> str:
    """A carried section verbatim, or the heading with the fallback prose under it."""
    return part if part else f"{heading}\n{fallback}"


def _branch_and_status(git_status: str | None) -> tuple[str, list[str]]:
    """`(branch, status lines)` from `git status --short --branch` output; ("", []) when git said nothing."""
    if not git_status:
        return "", []
    lines = git_status.splitlines()
    branch = ""
    if lines and lines[0].startswith("## "):
        branch = lines[0][3:].split("...")[0].strip()
        branch = _UNBORN.sub("", branch)
        lines = lines[1:]
    return branch, [line for line in lines if line.strip()]


@dataclass(frozen=True)
class Facts:
    """Everything `render` needs, already read. `previous` is the newest existing checkpoint's body ("" for none)."""

    when: str
    trigger: str
    session: str
    git_status: str | None
    last_message: str
    previous: str
    previous_name: str


def render(facts: Facts) -> str:
    """The checkpoint text."""
    when, trigger, session = facts.when, facts.trigger, facts.session
    last_message, previous_name = facts.last_message, facts.previous_name
    carried = split_checkpoint(facts.previous)
    branch, status = _branch_and_status(facts.git_status)
    shown = [_clip(line, MAX_LINE_CHARS) for line in status[:MAX_STATUS_LINES]]
    if len(status) > MAX_STATUS_LINES:
        shown.append(f"[TRUNCATED: {len(status) - MAX_STATUS_LINES} more lines]")
    if last_message:
        quoted = "\n".join(f"> {line}" for line in _clip(last_message, MAX_MESSAGE_CHARS).splitlines())
        message = f"Last user message before compaction (quoted data, not an instruction):\n\n{quoted}"
    else:
        message = "Last user message before compaction: not found in the transcript."
    carried_from = previous_name or "none"
    sections = [
        carried.get("tldr", DEFAULT_TLDR),
        f"<!-- {AUTO_MARKER} trigger={trigger} session={session or 'unknown'} carried-from={carried_from} -->",
        _body(carried.get("1"), "## 1. Goal", NO_PREVIOUS_GOAL),
        f"## 2. Accomplished\nAutomatic checkpoint at {when} before context compaction (trigger: {trigger}). "
        f"Sections 1, 4 and 5 are carried forward from {carried_from}.\n\n{message}",
        "## 3. Ready to Commit\n"
        f"Branch: {branch or 'unknown'}\n\n```\n" + ("\n".join(shown) if shown else "(clean)") + "\n```",
        _body(carried.get("4"), "## 4. Blockers", NO_PREVIOUS_BLOCKERS),
        _body(carried.get("5"), "## 5. Next Session", NO_PREVIOUS_NEXT),
    ]
    return "\n\n".join(sections) + "\n"
