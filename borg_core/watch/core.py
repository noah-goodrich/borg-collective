"""PURE activity-diff logic: two snapshots in, a list of events out.

No I/O of any kind -- no network, no filesystem, no clock, no subprocess. `shell.py` owns the `gh`
call and the snapshot file; this module only decides what CHANGED. Pinned by an AST import walk in
test_core.py, because the clean-architecture linter classifies by basename and its allow-list would
wave through `json` or `pathlib` here.

EVERY EVENT CARRIES ITS ORIGIN, and callers must treat `title`/`body`/`author` as DATA. PR titles and
comment bodies are external-origin text: an instruction-shaped string inside one is something to
report, never something to follow. That is the same rule checkpoints carry (SA3) and it matters more
here, because this module's whole output is untrusted text arriving on a schedule.
"""

from __future__ import annotations

import re

# Event kinds, ordered most-actionable first. The order is the reporting order.
NEW_PR = "new_pr"
REVIEW_APPROVED = "review_approved"
REVIEW_CHANGES_REQUESTED = "review_changes_requested"
NEW_COMMENT = "new_comment"
MERGED = "merged"
CLOSED = "closed"
HEAD_MOVED = "head_moved"

KIND_ORDER = (
    REVIEW_CHANGES_REQUESTED,
    REVIEW_APPROVED,
    NEW_PR,
    NEW_COMMENT,
    MERGED,
    CLOSED,
    HEAD_MOVED,
)


# Which review decisions are worth an event. A decision not listed here (PENDING, REVIEW_REQUIRED,
# or a value GitHub adds later) is a state change nobody needs woken for.
_DECISION_EVENTS = {
    "APPROVED": REVIEW_APPROVED,
    "CHANGES_REQUESTED": REVIEW_CHANGES_REQUESTED,
}


def _by_number(prs: list | None) -> dict:
    """Index a snapshot's PR list by number. A snapshot with no `prs` key is an empty index.

    Accepts None rather than requiring the caller to coalesce: `snapshot.get("prs")` is the natural
    call site and a missing key is the cold-start case, which must be handled rather than crash.
    """
    out = {}
    for pr in prs or []:
        num = pr.get("number")
        if isinstance(num, int):
            out[num] = pr
    return out


def _event(kind: str, pr: dict, number: int, detail: str) -> dict:
    """One event record. `title` is carried as opaque payload for a human -- never branched on."""
    return {"kind": kind, "number": number, "title": pr.get("title", ""), "detail": detail}


def _transitions(number: int, before: dict, after: dict) -> list:
    """Events for a PR present in BOTH snapshots. Split out of `diff` to keep each job readable."""
    events = []

    old_dec, new_dec = before.get("review_decision", ""), after.get("review_decision", "")
    kind = _DECISION_EVENTS.get(new_dec) if new_dec != old_dec else None
    if kind:
        events.append(_event(kind, after, number, f"review decision -> {new_dec}"))

    # Comment arrivals, counted rather than diffed by id: the count is what the API gives cheaply,
    # and a DECREASE (a deleted comment) is not an event worth waking anyone for.
    old_c, new_c = before.get("comment_count", 0), after.get("comment_count", 0)
    if isinstance(new_c, int) and isinstance(old_c, int) and new_c > old_c:
        events.append(_event(NEW_COMMENT, after, number,
                             f"{new_c - old_c} new comment(s), now {new_c}"))

    old_head, new_head = before.get("head", ""), after.get("head", "")
    if new_head and old_head and new_head != old_head:
        events.append(_event(HEAD_MOVED, after, number,
                             f"head {old_head[:7]} -> {new_head[:7]} (any stamp is void)"))
    return events


def diff(previous: dict, current: dict) -> list:
    """Events between two snapshots, most-actionable kind first.

    A MISSING PREVIOUS SNAPSHOT YIELDS NO EVENTS, not "everything is new". The first run must be
    silent: treating a cold start as N new PRs would page the reader with the entire backlog and
    train them to ignore the channel, which is the failure mode every alerting surface dies of. The
    caller stores the snapshot and reports nothing.
    """
    if not previous or not previous.get("prs"):
        return []

    was, now = _by_number(previous.get("prs")), _by_number(current.get("prs"))
    events = []

    for number, pr in now.items():
        before = was.get(number)
        if before is None:
            events.append(_event(NEW_PR, pr, number, f"opened by {pr.get('author', '?')}"))
        else:
            events.extend(_transitions(number, before, pr))

    # A PR that left the open set was merged or closed. Which one is carried on the snapshot rather
    # than guessed from its absence.
    for number, before in was.items():
        if number in now:
            continue
        state = (before.get("state") or "").upper()
        events.append(_event(MERGED if state == "MERGED" else CLOSED, before, number,
                             f"no longer open (state {state or 'unknown'})"))

    events.sort(key=lambda e: (KIND_ORDER.index(e["kind"]) if e["kind"] in KIND_ORDER else 99,
                               e["number"]))
    return events


def summary(events: list) -> str:
    """One line per event, most-actionable first. Empty string when nothing moved."""
    if not events:
        return ""
    return "\n".join(f"#{e['number']} {e['kind']}: {e['detail']}" for e in events)


# ── The auto-post allowlist ──────────────────────────────────────────────────────────────────────
#
# THE INVARIANT THAT MAKES UNATTENDED POSTING SAFE: an action is selected ONLY by machine-derived
# structured fields -- review decision, head sha, tree equality, CI conclusion -- and NEVER by
# reading a PR title, body, or comment. Those are external-origin text arriving on a schedule, so a
# watcher that let them choose an action would be executing instructions written by whoever last
# commented. Titles and bodies are carried through this module as opaque payload for a human to
# read; nothing here branches on their content, and the posted body is a template filled with
# derived values only, so no external string is ever echoed back into a comment.
#
# The second rule: only DERIVED FACTS post unattended. A fact ("the head moved, so the stamp at the
# old sha is void") is checkable and self-correcting. A VERDICT ("this is approved") asserts that a
# review happened, and a machine asserting a review that nobody performed is the whole defect class
# this repository has spent a week removing. The one exception is spelled out in `may_restamp`.

ACTION_NONE = "none"
ACTION_VOID_NOTICE = "void_notice"
ACTION_RESTAMP = "restamp"

# Never, under any circumstance reachable from a schedule.
FORBIDDEN = ("merge", "close", "approve_changes_requested", "force_push", "edit_settings")


# WRITTEN AGAINST THE STAMPS ACTUALLY IN USE, not against the protocol as described. The first
# draft anchored on `^STACK-APPROVAL:` with a `\S+` machine field and matched NONE of the three real
# stamps on this repository -- they carry a `## ` markdown prefix, machine names containing spaces
# and `/` ("personal machine / session borg-collective-6a"), and backtick-wrapped shas. That is the
# third gate-that-cannot-fire in one day, and the fix is the same each time: read the artifact
# before writing the matcher.
#
# The machine field is `.+?` on purpose. It is free-form and already inconsistent across posts, and
# nothing downstream branches on it -- it is carried into a re-stamp body as an opaque label, so
# constraining it would only re-create the matching failure above.
STAMP_RE = re.compile(
    r"^[#*\s]*STACK-APPROVAL:\s+(?P<machine>.+?)\s+APPROVES\s+#(?P<number>\d+)\s+@\s+"
    r"`?(?P<sha>[0-9a-f]{7,40})`?(?P<trailer>.*)$",
    re.MULTILINE,
)

# A trailer that is more than punctuation means the stamp was QUALIFIED -- the live example is
# "@ c531e1f — CONDITIONAL". A qualified verdict must not be carried forward automatically: the
# conditions live in prose this module deliberately does not read, so it cannot know whether they
# were met. Punctuation-only trailers are noise and are ignored.
_TRIVIAL_TRAILER = set(" \t.,;:—-–*_`")


def qualified(trailer: str) -> bool:
    """Does this stamp carry a qualifier, making it ineligible for an unattended carry-forward?"""
    return any(ch not in _TRIVIAL_TRAILER for ch in trailer or "")


def prior_stamp(comments: list, number: int) -> str:
    """The sha of the newest valid STACK-APPROVAL for `number`, or "" when there is none.

    WHY THE APPROVAL SIGNAL IS A COMMENT AND NOT `reviewDecision`. Measured on this repository:
    every PR is authored by the account that owns it, GitHub blocks self-review, and
    `reviewDecision` is therefore EMPTY on all of them, always. An allowlist keyed on
    `review_decision == "APPROVED"` would have been a gate that can never fire -- the exact defect
    class this repository has spent a week removing -- so the signal has to be the stamp the two
    machines actually use.

    Reading comment bodies re-opens the surface the module docstring closes, so this is the ONE
    place external text is parsed, and it is bounded four ways:

      1. `authorAssociation` must be OWNER. That field is API-derived, not body-derived, so it
         cannot be spoofed from inside a comment. The repository is PUBLIC and anyone may comment,
         which is what makes this filter load-bearing rather than decorative.
      2. The format is exact. A prose mention of the protocol does not match.
      3. The stamp's PR number must equal the PR it sits on, so a real stamp cannot be copy-pasted
         onto a different PR to launder approval onto it.
      4. What it yields is a SHA, not an action. The action is still chosen by tree equality in
         `may_restamp`, so the worst a forged-but-OWNER stamp could do is authorize re-stamping a
         tree that is byte-identical to one already stamped.

    Later comments win, so a re-stamp supersedes an earlier one.
    """
    found = ""
    for comment in comments or []:
        if not isinstance(comment, dict):
            continue
        if (comment.get("author_association") or "").upper() != "OWNER":
            continue
        match = STAMP_RE.search(comment.get("body") or "")
        if not match:
            continue
        # `re.Match` is a stdlib value object with no seam to delegate through; wrapping it would
        # add a class whose only job is to forward .group(). Same call and same convention as
        # borg_core/planstate/core.py:144.
        # JUSTIFICATION: stdlib re.Match has no delegate to add; see the three lines above.
        if int(match.group("number")) != number:  # pylint: disable=clean-arch-demeter
            continue
        # JUSTIFICATION: as above -- stdlib match object, no delegate to add.
        if qualified(match.group("trailer")):  # pylint: disable=clean-arch-demeter
            # A conditional stamp is recorded as "no auto-carryable stamp", which refuses rather
            # than permits. The event is still reported to a human either way.
            continue
        # JUSTIFICATION: as above -- stdlib match object, no delegate to add.
        found = match.group("sha")  # pylint: disable=clean-arch-demeter
    return found


def head_moved_past(stamped_sha: str, head: str) -> bool:
    """Is `head` genuinely a different commit from `stamped_sha`?

    ABBREVIATION-AWARE, and that is the whole point. A stamp records a 7-char sha while the API
    returns 40, so a naive `head != stamped_sha` reports the SAME commit as moved — which made the
    first version propose a "your stamp is void" notice for a head that still matched its stamp
    exactly. Caught end-to-end, not by a unit test, because both helpers looked right in isolation
    and only the composition was wrong. One predicate now, used by both callers.
    """
    if not stamped_sha or not head:
        return False
    return not head.startswith(stamped_sha) and not stamped_sha.startswith(head)


def may_restamp(stamped_sha: str, after: dict, trees_identical: bool) -> bool:
    """May a prior STACK-APPROVAL be re-stamped at the new head, unattended?

    ONLY when a prior stamp exists AND the tree did not change. That is the single case where the
    earlier verdict is still literally true of the code: a rebase or an amended message changes
    commits without changing content, so re-stamping continues a judgment a human already made
    rather than manufacturing a new one. `trees_identical` must come from a real tree comparison
    (`git diff --quiet`), never from equal commit counts or an unchanged diffstat, both of which a
    content change can preserve.
    """
    # `not stamped_sha` is REDUNDANT WITH A PYTHON ACCIDENT, and stays anyway. The final clause
    # below would also refuse an empty stamp, because `"bbb".startswith("")` is True in Python, so
    # `not head.startswith("")` is False. That means this guard survives mutation testing -- and it
    # is kept because the refusal must be INTENTIONAL, not a side effect of empty-prefix semantics
    # that a future rewrite of the sha comparison would silently remove. Belt and braces, stated so
    # a cleanup pass does not read the surviving mutant as proof the line is dead.
    if not stamped_sha or not trees_identical:
        return False
    if (after.get("review_decision") or "").upper() == "CHANGES_REQUESTED":
        return False
    return head_moved_past(stamped_sha, after.get("head") or "")


def decide(event: dict, stamped_sha: str, after: dict, trees_identical: bool) -> str:
    """Which allowlisted action, if any, this event authorizes unattended.

    Returns one of ACTION_*. Anything not explicitly returned here is `none`, so a new event kind
    added to `diff()` cannot silently acquire posting rights -- the default is refusal, and a caller
    wanting a new autonomous action has to come here and say so.
    """
    if event.get("kind") != HEAD_MOVED:
        return ACTION_NONE
    if not stamped_sha:
        return ACTION_NONE
    if not head_moved_past(stamped_sha, after.get("head") or ""):
        # The snapshot saw a different string but it is the SAME commit. Nothing is void and
        # nothing needs carrying forward; there is no true statement to post.
        return ACTION_NONE
    if may_restamp(stamped_sha, after, trees_identical):
        return ACTION_RESTAMP
    return ACTION_VOID_NOTICE
