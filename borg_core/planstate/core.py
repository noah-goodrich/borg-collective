"""PURE plan-state logic: criterion parsing, evidence-annotation validation, verdicts, and the flip.

NO os, NO subprocess, NO environment, NO clock, NO filesystem. This module is named on
pyproject.toml's `[tool.clean-arch.module_map]` Domain list by BASENAME (`core.py` was already
there), so the import check applies to it -- and `test_core.py` walks its imports by AST anyway,
because W9004's allow-list permits `pathlib`, `json` and `datetime` and is therefore the coarser of
the two gates. Every impure answer this module needs arrives as an argument.

THE ANNOTATION IS NEVER A COMMAND. `validate_annotation` is an ALLOWLIST -- a closed set of four
kinds, each carrying a ref or a path matched against an anchored character class -- and not a
denylist of metacharacters. That direction is the whole of AC9: a denylist is a list of the attacks
someone thought of, and the four kinds genuinely need no character outside `[A-Za-z0-9._/#-]`. The
runner for `bats:` and `pytest:` is selected in `shell.py` from the KIND, never assembled from the
annotation's text, so there is no string anywhere in this package that a plan file contributes to
and a shell then parses.
"""

from __future__ import annotations

import re

from borg_core.manifest import core as manifest_core

# THE CRITERION TEST IS `borg_core/link/core.py::plan_progress`'S, TRANSCRIBED RATHER THAN IMPORTED.
# That function answers (met, total) and is the counter the board already renders; this one needs the
# line index and the text as well, so it cannot call it. What it must not do is invent a SECOND
# counting rule -- a file where `borg link` says 3/9 and `planstate` says 3/11 has two truths in it,
# and the one that flips boxes would be the wrong one to be wrong. `- [` at line start, `- [x]` for
# met: byte for byte what plan_progress tests. `plan_progress` is deliberately left untouched.
_CRITERION_PREFIX = "- ["
_MET_PREFIX = "- [x]"
_UNMET_PREFIX = "- [ ]"

# An indented sub-bullet naming the machine-readable evidence. The prose `- Verify:` sibling is not
# matched here and is never rewritten -- it is the clause a human reads, and the amendment's whole
# shape is that the annotation sits BESIDE it rather than replacing it.
_EVIDENCE_RE = re.compile(r"^\s+-\s+Evidence:\s*(.+?)\s*\Z")

# Surrounding backticks are the documented authoring form (`- Evidence: \`pytest:borg_core/planstate/\``)
# and carry no meaning, so they are stripped before validation rather than being accepted INTO the
# value -- otherwise a backtick would have to be in the allowlist, which is the one character this
# package least wants there.
_TICKS = "`"

_KINDS = ("pr", "path", "bats", "pytest")

# THE AUDIT TRAIL, AND THE ONLY THING THIS PACKAGE EVER APPENDS TO A LINE (AC2, and AC8 as restated
# 2026-09-11). `_ANNOTATION_MARK` is the literal AC2 greps for; it is also the idempotence test, so
# the spelling is a constant rather than two string literals that could drift apart.
_ANNOTATION_MARK = "flipped by link-up"


def annotation_for(evidence: str) -> str:
    """The ` *(flipped by link-up: <evidence>)*` suffix for one flipped criterion.

    THE EVIDENCE IS COLLAPSED TO SINGLE SPACES, which is a no-op for every string `verdict_for_*`
    produces and is not there for tidiness: a newline inside `evidence` would split one line into
    two and break AC8's "no other line moved" by construction. Making that impossible in the
    formatter is cheaper than a validator nobody can see from the call site.

    LINE LENGTH: this suffix can push a criterion line past the repository's 120-column wrap, and it
    is allowed to. AC8 requires the annotation on the SAME line as the checkbox, so the alternatives
    are a continuation line (which AC8 forbids) or reflowing the criterion's prose (which would move
    lines AC8 requires to be byte-identical). The overflow is bounded -- the suffix is 24 characters
    plus one evidence line, and every evidence line this package emits is a validated ref or path
    plus a short verb -- and it lands only on lines this package rewrote.
    """
    return f" *({_ANNOTATION_MARK}: {' '.join(evidence.split())})*"


# ANCHORED, AND DELIBERATELY NARROW. No space, no quote, no `;`, no backtick, no `$`, no `(`/`)`,
# no `|`, no `&`, no `<`/`>`, no newline -- none of them by enumeration, all of them by absence from
# the class. `\Z` rather than `$`, because `$` matches before a trailing newline and
# `path:ok\n; rm -rf /` would validate against a `$`-anchored pattern.
_PATH_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._/-]*\Z")

PASS = "pass"
FAIL = "fail"
UNKNOWN = "unknown"


def parse_criteria(text: str) -> list[dict]:
    """Every acceptance criterion in `text`, in file order, with its evidence annotation if any.

    Each entry is `{line, checked, text, annotation}` where `line` is a 0-based index into
    `text.split("\\n")` and `annotation` is the raw post-`Evidence:` string (backticks stripped) or
    None. `text` is the criterion's line MINUS the checkbox prefix, stripped -- which is what
    `apply_flips` matches a target line against, so a criterion that moved between the derive and
    the write is recognised as a different line rather than flipped by position.

    THE SCAN FOR THE SUB-BULLET STOPS AT THE NEXT CRITERION, at the next unindented non-blank line,
    and at nothing else -- so a criterion whose prose runs over several indented lines still finds an
    `Evidence:` bullet below them, and a criterion with no annotation can never adopt the next
    criterion's. A blank line does NOT stop the scan: a 120-wrapped document routinely separates a
    criterion's sub-bullets from its prose, and stopping there was the difference between reading
    this repository's own directive correctly and reading it as fully unannotated.
    """
    lines = text.split("\n")
    criteria: list[dict] = []
    fenced = False
    for index, line in enumerate(lines):
        # A FENCED BLOCK IS NOT CRITERIA -- see the twin guard in `link/core.py::plan_progress`, which
        # this must stay in step with. Found by running this module against its OWN directive, whose
        # amendment shows an example `- [ ] **AC6 ...**` inside a code fence: the example parsed as a
        # real criterion, so the document reported 10 criteria where it has 9. An unreachable phantom
        # is not harmless here -- it can never resolve to `pass` (its annotation is illustrative, not
        # real), so it would sit in the proposal block forever telling a reader that work is outstanding
        # which does not exist.
        if line.lstrip().startswith("```"):
            fenced = not fenced
            continue
        if fenced:
            continue
        if not line.startswith(_CRITERION_PREFIX):
            continue
        criteria.append(
            {
                "line": index,
                "checked": line.startswith(_MET_PREFIX),
                "text": line[len(_UNMET_PREFIX) :].strip(),
                "annotation": _annotation_below(lines, index),
            }
        )
    return criteria


def _annotation_below(lines: list[str], start: int) -> str | None:
    """The `- Evidence:` value belonging to the criterion at `lines[start]`.

    SPLIT OUT so `parse_criteria` stays one loop with one job, mirroring the seam
    `link/core.py::_paragraph_from` takes for the same reason: the caller answers WHICH lines are
    criteria, this answers WHAT hangs off one.
    """
    for offset in range(start + 1, len(lines)):
        candidate = lines[offset]
        if candidate.startswith(_CRITERION_PREFIX):
            return None
        if candidate.strip() and not candidate[0].isspace():
            return None
        match = _EVIDENCE_RE.match(candidate)
        if match:
            # The same shape borg_core/manifest/refs.py::parse_ref carries a disable for.
            # JUSTIFICATION: reading the group of a Match this function just produced, not a foreign object.
            return match.group(1).strip(_TICKS).strip()  # pylint: disable=clean-arch-demeter
    return None


def validate_annotation(raw: str | None) -> dict:
    """`{ok, kind, value, reason}` for one raw annotation. The ONLY gate between file content and
    anything that forks.

    `ok` False is never an error and never an exception -- it is an `unknown` verdict with a reason
    attached, because the two facts "this pin is malformed" and "this work regressed" must not share
    a value. See `verdict_for` and the Risks section of the directive.
    """
    if raw is None:
        return _rejected("", "", "no evidence annotation")
    # JUSTIFICATION: whitespace/backtick unwrapping of a local string this function owns.
    candidate = raw.strip().strip(_TICKS).strip()  # pylint: disable=clean-arch-demeter
    if not candidate:
        return _rejected("", "", "empty evidence annotation")
    # `partition` is the total form of `split(":", 1)` and cannot raise on an annotation with no colon.
    # JUSTIFICATION: splitting a local string this function owns, not a caller-supplied collaborator.
    kind, _, value = candidate.partition(":")  # pylint: disable=clean-arch-demeter
    if kind not in _KINDS:
        return _rejected(kind, value, f"unknown evidence kind {kind!r} (expected one of {', '.join(_KINDS)})")
    return _validate_value(kind, value)


def _validate_value(kind: str, value: str) -> dict:
    """The per-kind half of `validate_annotation`. SPLIT OUT BECAUSE PYLINT MEASURED IT (R0911, 8
    returns against a ceiling of 6), and the seam is the honest one: the caller answers WHICH KIND
    this annotation claims to be, and this answers WHETHER ITS PAYLOAD IS ACCEPTABLE."""
    if not value:
        return _rejected(kind, value, f"{kind}: annotation carries no {'ref' if kind == 'pr' else 'path'}")
    if kind == "pr":
        # THE INJECTION GATE IS manifest.core.parse_ref, not a second regex written here. It is the
        # same character class `borg_core/link/grid.py::_fetchable` validates against before an owner
        # reaches a GraphQL document body, and the same one recon-adapter-github uses -- so a `pr:`
        # ref that this module accepts is exactly a ref the existing fetch path already accepts, and
        # there is no third place for the two vocabularies to drift apart.
        if manifest_core.parse_ref(value) is None:
            return _rejected(kind, value, f"pr: {value!r} is not a bare owner/repo#number ref")
    elif not _PATH_RE.match(value) or ".." in value.split("/"):
        return _rejected(kind, value, f"{kind}: {value!r} is not a plain repo-relative path")
    return {"ok": True, "kind": kind, "value": value, "reason": ""}


def _rejected(kind: str, value: str, reason: str) -> dict:
    """A refused annotation. Kept as a helper so every rejection carries the same four keys and a
    caller can never get a dict whose `reason` is missing on one branch."""
    return {"ok": False, "kind": kind, "value": value, "reason": reason}


def verdict_for_path(exists: bool, value: str) -> tuple[str, str]:
    """`(verdict, evidence line)` for a `path:` annotation, given the filesystem's answer.

    THE ONE KIND WHERE ABSENCE IS `fail` RATHER THAN `unknown`, and it is not an inconsistency with
    the `bats:`/`pytest:` rule below. A `path:` annotation asserts THAT THE FILE IS THE DELIVERABLE:
    its absence is the work not being done. A `bats:` path is a POINTER AT a check, so its absence is
    the pointer rotting -- `reference_line_pins_rot_anchor_instead`, and the directive's second Risk.
    """
    if exists:
        return PASS, f"path:{value} exists"
    return FAIL, f"path:{value} does not exist"


def verdict_for_suite(kind: str, value: str, present: bool, result: tuple[int, str] | None) -> tuple[str, str]:
    """`(verdict, evidence line)` for a `bats:`/`pytest:` annotation.

    THREE OUTCOMES AND ONLY ONE OF THEM IS `fail`. A missing path is `unknown` (the pin rotted); a
    runner that could not be started or did not answer is `unknown` (`result is None` -- the same
    "a degraded source yields unknown" policy the `pr:` kind takes, and the same one `proc.collect`
    already expresses by returning None). Only a runner that RAN and exited non-zero is `fail`.
    """
    if not present:
        return UNKNOWN, f"{kind}:{value} does not exist -- the pin rotted, not the work"
    if result is None:
        return UNKNOWN, f"{kind}:{value} -- runner {kind} could not be run or did not answer"
    code = result[0]
    if code == 0:
        return PASS, f"{kind}:{value} exited 0"
    return FAIL, f"{kind}:{value} exited {code}"


def verdict_for_pr(value: str, looked: bool, state: str | None) -> tuple[str, str]:
    """`(verdict, evidence line)` for a `pr:` annotation, given TWO FACTS and not a wire format.

    `looked` is "the source was asked and answered"; `state` is the token it answered with, or None
    for a ref it had nothing for. TRANSLATING A `link.shell.finish_fetch` RESULT INTO THOSE TWO IS
    `shell.pr_state`'S JOB, not this module's -- a pure module that reaches into
    `fetch["items"][value]["state"]` has a sibling package's dict layout encoded in it, and the
    defensive `or {}` such a reach needs means RENAMING that key downgrades every `pr:` criterion to
    `unknown` forever and silently. Two booleans-worth of interface cannot rot that way.

    NEVER `fail` FROM A DEGRADED SOURCE (the directive's third Risk). An unauthenticated `gh`, an
    offline host, a rate limit and a deadline miss all arrive as `looked=False` and resolve to
    `unknown`; a ref the fetch answered for but carries nothing for -- deleted, renamed, or not
    visible -- arrives as `state=None` and is `unknown` too, for the same reason: nothing was
    learned about the work.

    `merged` IS THE ONLY PASS. The token is lowercased upstream by `grid.fetched_items` to match the
    github adapter's `ascii_downcase`, and lowercased again here so this comparison cannot depend on
    which of the two produced it.
    """
    if not looked:
        return UNKNOWN, f"pr:{value} -- the GitHub source is unreachable or was not asked"
    if not state:
        return UNKNOWN, f"pr:{value} did not resolve (deleted, renamed, or not visible)"
    token = state.lower()
    if token == "merged":
        return PASS, f"pr:{value} is merged"
    return FAIL, f"pr:{value} is {token}, not merged"


def apply_flips(text: str, flips: list[tuple[int, str, str]]) -> tuple[str, int]:
    """`(text with each flip applied, how many boxes actually moved)`.

    Each flip is `(line index, the criterion's text as parsed, its evidence line)`.

    THE GUARD IS IDENTITY, NOT SHAPE, AND THAT IS THE WHOLE POINT OF THE `text` ELEMENT. The indices
    are captured during a derive that may have taken minutes -- a `pytest:` annotation runs a suite
    -- and a human may have edited the plan in that window. An earlier version tested only that the
    line at the index still started with `- [ ]`, which in an acceptance-criteria block is true of
    EVERY NEIGHBOUR: inserting one line above the target shifted every index by one and flipped the
    criterion below it instead, silently and with the wrong evidence attached. Testing that the line
    IS STILL THAT CRITERION makes a shifted file a no-op rather than a wrong answer.

    WHAT CHANGES ON A FLIPPED LINE (AC8 as restated 2026-09-11): the checkbox character, and the
    `annotation_for` suffix appended to the same line. Nothing else -- no strip, no rewrap, no
    normalisation of trailing whitespace, no touching of the line ending. The prefix is replaced by
    slicing at a FIXED LENGTH and the remainder is concatenated back verbatim, so a line with
    trailing spaces or a criterion whose own text contains `- [ ]` survives except for those two
    changes. `"\\n".join(split("\\n"))` is an exact round trip, including a trailing newline, so a
    file neither gains nor loses one by passing through here.

    A RE-RUN IS A NO-OP TWICE OVER. A criterion already carrying the mark gets no second annotation,
    and a criterion already `- [x]` fails the prefix test -- so a crash between the flip and
    whatever the caller does next can be recovered by simply running again.

    THE COUNT IS RETURNED RATHER THAN RECOMPUTED BY THE CALLER. This function is the only code that
    knows which targets it actually took, so a caller that re-diffs the two texts to find out is
    both slower and a second implementation of the same fact.
    """
    if not flips:
        return text, 0
    lines = text.split("\n")
    moved = 0
    for index, expected, evidence in flips:
        if not 0 <= index < len(lines):
            continue
        line = lines[index]
        if not line.startswith(_UNMET_PREFIX) or line[len(_UNMET_PREFIX) :].strip() != expected:
            continue
        flipped = _MET_PREFIX + line[len(_UNMET_PREFIX) :]
        if _ANNOTATION_MARK not in flipped:
            flipped += annotation_for(evidence)
        lines[index] = flipped
        moved += 1
    return "\n".join(lines), moved
