"""Pure logic for a Queen handoff: the template and the lint. No clock, no filesystem, no environment.

WHY THIS EXISTS. On 2026-11-02 one handoff ("land the in-flight DE-2182 PRs") named PRs in two repositories and
ran one worker session for 336 calls, two compactions and about $40 (noah-goodrich/borg-collective#500). A
handoff is now scoped to ONE PR thread, and `check` is the rule: exactly one PR ref in the goal, a stop condition,
and the next thread named for a fresh session.

A handoff is a checkpoint-shaped document (tl;dr, then the five numbered sections), because `borg next`,
`borg link` and the arrival brief read the newest checkpoint whole. Only two readers matter for the shape:
`## 4. Blockers` carries `Waits on you:` (the person's rows) and every top-level list item of `## 5. Next Session`
is an AGENT row. So the stop condition rides on the ONE numbered item of section 5, and the next thread is a prose
line below the list: prose is not a row, so a fresh session's thread never shows up as this session's work.

PR REFS. `owner/repo#N`, a bare `#N` and a `https://github.com/<owner>/<repo>/pull/N` URL count. `owner/repo#N`
cannot be told from an issue by its spelling, so it counts; an `/issues/N` URL does not. The same PR spelled two
ways counts once, and a bare `#N` is the same PR as a qualified ref with that number.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

STOP_PREFIX = "Stop condition:"
NEXT_PREFIX = "Next thread (a fresh session, not this one):"
NEXT_NONE = "none"
CLOSE_PHRASE = "then /borg-link-up and end"

_REPO = r"[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9_.-]+"
_URL = re.compile(rf"https://github\.com/({_REPO})/pull/(\d+)")
_QUALIFIED = re.compile(rf"(?<![\w/.-])({_REPO})#(\d+)\b")
_BARE = re.compile(r"(?<![\w/#&])#(\d+)\b")
_GOAL_HEADING = re.compile(r"^##\s*1\.?\s*goal\b", re.IGNORECASE)
_ANY_H2 = re.compile(r"^##\s")
_STOP_LINE = re.compile(r"^\s*Stop condition:\s*(.*\S)\s*$", re.IGNORECASE | re.MULTILINE)
_NEXT_LINE = re.compile(r"^\s*Next thread\b[^:\n]*:\s*(.*\S)\s*$", re.IGNORECASE | re.MULTILINE)
_DONE_WHEN = re.compile(r"\bdone when\b\s*\S", re.IGNORECASE)


@dataclass(frozen=True)
class Verdict:
    """The lint result: `problems` empty means the handoff passes."""

    ok: bool
    problems: tuple[str, ...]
    refs: tuple[str, ...]


def pr_refs(text: str) -> list[str]:
    """The distinct PR refs in `text`, in order of first appearance, spelled `owner/repo#N` or `#N`."""
    found: list[tuple[int, str, str]] = []
    scrubbed = text
    for match in _URL.finditer(text):
        found.append((match.start(), match.group(1), match.group(2)))
    scrubbed = _URL.sub(lambda m: " " * len(m.group(0)), scrubbed)
    for match in _QUALIFIED.finditer(scrubbed):
        found.append((match.start(), match.group(1), match.group(2)))
    scrubbed = _QUALIFIED.sub(lambda m: " " * len(m.group(0)), scrubbed)
    for match in _BARE.finditer(scrubbed):
        found.append((match.start(), "", match.group(1)))
    found.sort()
    qualified_numbers = {number for _, repo, number in found if repo}
    refs: list[str] = []
    for _, repo, number in found:
        if not repo and number in qualified_numbers:
            continue
        ref = f"{repo}#{number}"
        if ref not in refs:
            refs.append(ref)
    return refs


def goal_section(text: str) -> str:
    """The body of `## 1. Goal`, up to the next `## ` heading. Empty when the section is absent."""
    body: list[str] = []
    inside = False
    for line in text.splitlines():
        if _GOAL_HEADING.match(line):
            inside = True
        elif inside and _ANY_H2.match(line):
            break
        elif inside:
            body.append(line)
    return "\n".join(body)


def split_prompt(refs: list[str]) -> str:
    """The message for a goal that names more than one PR: one handoff per ref, one worker session each."""
    listed = ", ".join(refs)
    return (
        f"split: this goal names {len(refs)} PR threads ({listed}). A worker session takes ONE thread: "
        f"write {len(refs)} handoffs, one per ref, each with its own stop condition, and name the "
        "next thread in each so a fresh session picks it up."
    )


def _goal_problems(text: str) -> tuple[list[str], list[str]]:
    """The goal rule: the problems and the PR refs found. One PR ref passes; none or several fail."""
    goal = goal_section(text)
    refs = pr_refs(goal)
    if not goal.strip():
        return ["no `## 1. Goal` section"], refs
    if not refs:
        return ["the goal names no PR ref (owner/repo#N, #N or a PR URL): a handoff is one PR thread"], refs
    return ([split_prompt(refs)] if len(refs) > 1 else []), refs


def _stop_problems(text: str) -> list[str]:
    """The stop-condition rule: a `Stop condition:` line that says done when X and ends with /borg-link-up."""
    stop = _STOP_LINE.search(text)
    if stop is None:
        return [f"no `{STOP_PREFIX}` line: say what ends the session (done when X, {CLOSE_PHRASE})"]
    # JUSTIFICATION: re.Match.group on the match this function just made, not a layer reach.
    said = stop.group(1)  # pylint: disable=clean-arch-demeter
    if _DONE_WHEN.search(said) and "/borg-link-up" in said:
        return []
    return [f"the stop condition must read: done when X, {CLOSE_PHRASE}"]


def _next_problems(text: str) -> list[str]:
    """The next-thread rule: the line exists, naming a thread or `none`."""
    if _NEXT_LINE.search(text) is None:
        return [f"no `{NEXT_PREFIX}` line: name the next thread, or `{NEXT_NONE}` when this is the last"]
    return []


def check(text: str) -> Verdict:
    """Lint one handoff document. Every rule that fails adds a line, so one run reports everything wrong."""
    goal_problems, refs = _goal_problems(text)
    problems = [*goal_problems, *_stop_problems(text), *_next_problems(text)]
    return Verdict(ok=not problems, problems=tuple(problems), refs=tuple(refs))


def render(goal: str, done_when: str, next_thread: str, waits_on_you: tuple[str, ...] = ()) -> str:
    """The handoff document for one PR thread. The caller runs `check` on the result before writing it."""
    goal = " ".join(goal.split())
    stop = f"Done when {' '.join(done_when.split())}, {CLOSE_PHRASE}."
    nxt = " ".join(next_thread.split()) or NEXT_NONE
    waits = "\n".join(f"- {' '.join(item.split())}" for item in waits_on_you)
    waits_block = f"Waits on you:\n{waits}" if waits else "Waits on you: none"
    return (
        f"tl;dr: handed to one worker session: {goal}\n"
        f"{stop} Next, in a fresh session: {nxt}.\n\n"
        f"## 1. Goal\n\n{goal}\n\n{STOP_PREFIX} {stop}\n\n"
        "## 2. Accomplished\n\nNothing yet: written by the Queen as a handoff.\n\n"
        "## 3. Ready to Commit\n\nNothing.\n\n"
        f"## 4. Blockers\n\nNo blockers.\n\n{waits_block}\n\n"
        f"## 5. Next Session\n\n1. {goal} {stop}\n\n{NEXT_PREFIX} {nxt}\n"
    )
