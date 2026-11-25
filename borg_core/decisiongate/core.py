"""Pure logic of the decision gate: does a final assistant message ask Noah to decide, and what to tell the model.

WHY THIS EXISTS. On 2026-10-04, 2026-10-15 and 2026-11-25 a session that needed decisions from Noah wrote terse lists
("Needs Noah: #97, close or restate scope") instead of asking through AskUserQuestion with real context. Memory rules
failed twice, so the Stop hook (`hooks/borg-decision-gate.sh`) enforces it: it blocks a turn whose final message holds a
decision request while the turn made no AskUserQuestion call.

PRECISION OVER RECALL. A false positive blocks an innocent report and costs a turn, so only two shapes count, and both
are structural, never a keyword anywhere in prose:

1. a LABEL line: a line that begins with a request phrase (`Needs Noah`, `Needs you`, `Waits on you`, `Decision
   needed`, `Decide`, `Your call`, `Open questions`, ...) and then ends, or continues after a `:` or dash. "Decided:",
   "Decision: shipped" and "I decided" are not labels. A label may also open a sentence after a full stop
   ("Done. Waits on you: #97"). A label whose content is `none` (or `nothing`, `n/a`) is not a
   request;
2. a QUESTION LIST: two or more list items that each end in `?`, outside code fences. One closing "Want me to proceed?"
   is conversation, not a decision list.

Fenced code and block quotes are blanked before either test, so a quoted old report or a pasted transcript passes.
No clock, no filesystem, no environment.
"""

from __future__ import annotations

import re

ASK_TOOL_NAMES = frozenset({"AskUserQuestion", "ask_user_question"})

_FENCE = re.compile(r"^\s*(```|~~~)")
_QUOTE = re.compile(r"^\s*>")
_MARKUP = r"^\s*(?:#{1,6}\s+|[-*+]\s+|\d+[.)]\s+)?(?:\*\*|__|\*|_)?\s*"
_PHRASE = (
    r"(?:needs?\s+(?:noah|you|your\s+(?:call|decision|input|approval|answer))"
    r"|waits?\s+on\s+(?:you|noah)|waiting\s+on\s+(?:you|noah)|blocked\s+on\s+(?:you|noah)"
    r"|awaiting\s+(?:your|noah(?:'s)?)\s+\w+"
    r"|decisions?\s+(?:needed|required|for\s+(?:you|noah)|waiting)"
    r"|decide|your\s+call|you\s+decide|for\s+you\s+to\s+decide|to\s+decide"
    r"|(?:open\s+)?questions?\s+(?:for|to)\s+(?:you|noah)|open\s+questions?"
    r"|questions?\s+for\s+you)"
)
_LABEL = re.compile(_MARKUP + _PHRASE + r"(?:\*\*|__|\*|_)?\s*(?P<after>[:—–-].*|\.|\?)?\s*$", re.IGNORECASE)
_INLINE_LABEL = re.compile(r"[.!?]\s+(?:\*\*|__)?" + _PHRASE + r"(?:\*\*|__)?\s*(?P<after>:.*)$", re.IGNORECASE)
_NONE = re.compile(r"^[:—–-]\s*(?:\*\*)?\s*(?:none|nothing|n/?a|no\s+\w+|nil|no one)\b", re.IGNORECASE)
_QUESTION_ITEM = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s+.*\?\s*(?:\*\*|__)?\s*$")


def _prose_lines(text: str) -> list[str]:
    """The lines of `text` outside fenced code and block quotes."""
    kept: list[str] = []
    fenced = False
    for line in text.splitlines():
        if _FENCE.match(line):
            fenced = not fenced
            continue
        if not fenced and not _QUOTE.match(line):
            kept.append(line)
    return kept


_NONE_LINE = re.compile(r"^\s*(?:[-*+]\s+)?(?:\*\*)?\s*(?:none|nothing|n/?a|nil|no one|no decisions?)\b", re.IGNORECASE)


def _is_label(line: str, following: str) -> bool:
    """True for a request label. `following` is the next non-blank line: a bare label over `None.` is not a request."""
    found = _LABEL.match(line.rstrip()) or _INLINE_LABEL.search(line.rstrip())
    if not found:
        return False
    after = found.group("after") or ""
    if after and not after.strip(":.?-\u2014\u2013 "):
        after = ""
    if after:
        return not _NONE.match(after)
    return not _NONE_LINE.match(following)


def asks_for_decision(text: str) -> bool:
    """True when `text` holds a decision request addressed to the person (a label line, or a question list)."""
    lines = _prose_lines(text)
    for index, line in enumerate(lines):
        following = next((rest for rest in lines[index + 1 :] if rest.strip()), "")
        if _is_label(line, following):
            return True
    return sum(1 for line in lines if _QUESTION_ITEM.match(line)) >= 2


def reason() -> str:
    """The block reason: what the model must do instead of leaving the request as text."""
    return (
        "Your final message puts a decision to Noah as plain text, and this turn made no AskUserQuestion call. "
        "Do not leave it as a list. Re-ask EACH open decision through AskUserQuestion (rounds of at most 4), and make "
        "every one stand on its own, written as if Noah has read nothing this session: "
        "(1) what the thing is, in plain words, not a bare PR or issue number; "
        "(2) why it is open and what is blocked on it; "
        "(3) 2 to 4 options, each with its pros, its cons and exactly what choosing it runs; "
        "(4) your recommendation, listed first and marked (Recommended); "
        "(5) a source link (PR, issue, file or commit). "
        "If a decision is already settled or you can make it yourself, drop it from the list instead of asking. "
        "If nothing is left to ask, say so in one line and stop."
    )
