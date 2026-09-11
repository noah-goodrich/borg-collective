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

    Each entry is `{line, checked, text, annotation, annotation_line}` where `line` is a 0-based
    index into `text.split("\\n")` and `annotation` is the raw post-`Evidence:` string (backticks
    stripped) or None.

    THE SCAN FOR THE SUB-BULLET STOPS AT THE NEXT CRITERION, at the next unindented non-blank line,
    and at nothing else -- so a criterion whose prose runs over several indented lines still finds an
    `Evidence:` bullet below them, and a criterion with no annotation can never adopt the next
    criterion's. A blank line does NOT stop the scan: a 120-wrapped document routinely separates a
    criterion's sub-bullets from its prose, and stopping there was the difference between reading
    this repository's own directive correctly and reading it as fully unannotated.
    """
    lines = text.split("\n")
    criteria: list[dict] = []
    for index, line in enumerate(lines):
        if not line.startswith(_CRITERION_PREFIX):
            continue
        annotation, annotation_line = _annotation_below(lines, index)
        criteria.append(
            {
                "line": index,
                "checked": line.startswith(_MET_PREFIX),
                "text": line[len(_UNMET_PREFIX) :].strip(),
                "annotation": annotation,
                "annotation_line": annotation_line,
            }
        )
    return criteria


def _annotation_below(lines: list[str], start: int) -> tuple[str | None, int | None]:
    """The `- Evidence:` value belonging to the criterion at `lines[start]`, and its line index.

    SPLIT OUT so `parse_criteria` stays one loop with one job, mirroring the seam
    `link/core.py::_paragraph_from` takes for the same reason: the caller answers WHICH lines are
    criteria, this answers WHAT hangs off one.
    """
    for offset in range(start + 1, len(lines)):
        candidate = lines[offset]
        if candidate.startswith(_CRITERION_PREFIX):
            return None, None
        if candidate.strip() and not candidate[0].isspace():
            return None, None
        match = _EVIDENCE_RE.match(candidate)
        if match:
            return match.group(1).strip(_TICKS).strip(), offset
    return None, None


def validate_annotation(raw: str | None) -> dict:
    """`{ok, kind, value, reason}` for one raw annotation. The ONLY gate between file content and
    anything that forks.

    `ok` False is never an error and never an exception -- it is an `unknown` verdict with a reason
    attached, because the two facts "this pin is malformed" and "this work regressed" must not share
    a value. See `verdict_for` and the Risks section of the directive.
    """
    if raw is None:
        return _rejected("", "", "no evidence annotation")
    candidate = raw.strip().strip(_TICKS).strip()
    if not candidate:
        return _rejected("", "", "empty evidence annotation")
    kind, _, value = candidate.partition(":")
    if kind not in _KINDS:
        return _rejected(kind, value, f"unknown evidence kind {kind!r} (expected one of {', '.join(_KINDS)})")
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
        return {"ok": True, "kind": kind, "value": value, "reason": ""}
    if not _PATH_RE.match(value) or ".." in value.split("/"):
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


def verdict_for_pr(value: str, fetch: dict) -> tuple[str, str]:
    """`(verdict, evidence line)` for a `pr:` annotation, given a `link.shell.finish_fetch` result.

    NEVER `fail` FROM A DEGRADED SOURCE (the directive's third Risk). The fetch result carries
    `attempted` and `status` precisely so "I could not look" and "I looked and it is open" are
    different answers; an unauthenticated `gh`, an offline host, a rate limit and a deadline miss all
    land as `status: failed` / `attempted: False` and resolve here to `unknown`. A ref the fetch
    answered for but that carries no entry -- deleted, renamed, or not visible -- is also `unknown`,
    for the same reason: nothing was learned about the work.

    `merged` IS THE ONLY PASS. The token is lowercased upstream by `grid.fetched_items` to match the
    github adapter's `ascii_downcase`, so this comparison is against the same vocabulary a swept item
    would carry, not a second one.
    """
    if not fetch.get("attempted") or fetch.get("status") == "failed":
        return UNKNOWN, f"pr:{value} -- the GitHub source is unreachable or was not asked"
    item = (fetch.get("items") or {}).get(value)
    if not isinstance(item, dict) or not item.get("state"):
        return UNKNOWN, f"pr:{value} did not resolve (deleted, renamed, or not visible)"
    state = str(item["state"]).lower()
    if state == "merged":
        return PASS, f"pr:{value} is merged"
    return FAIL, f"pr:{value} is {state}, not merged"


def apply_flips(text: str, lines_to_flip: list[int]) -> str:
    """`text` with `- [ ]` replaced by `- [x]` at each 0-based index in `lines_to_flip`.

    THE ONLY BYTE THAT CHANGES IS THE ONE INSIDE THE BRACKETS (AC8). No strip, no rewrap, no
    normalisation of trailing whitespace, no touching of the line ending -- the prefix is replaced by
    slicing at a FIXED LENGTH and the remainder of the line is concatenated back verbatim, so a line
    with trailing spaces or a criterion whose text contains `- [ ]` again survives byte-identically.
    `"\\n".join(split("\\n"))` is an exact round trip, including a trailing newline (which splits to a
    final empty element), so a file does not gain or lose one by passing through here.

    A LINE THAT IS NOT AN UNCHECKED CRITERION IS LEFT ALONE rather than raising. The caller has
    already filtered to `pass` verdicts; this second test makes the function total, so a stale index
    (a caller that re-read the file between deriving and writing) can produce a no-op but never a
    corrupted line.
    """
    if not lines_to_flip:
        return text
    targets = set(lines_to_flip)
    lines = text.split("\n")
    for index in targets:
        if 0 <= index < len(lines) and lines[index].startswith(_UNMET_PREFIX):
            lines[index] = _MET_PREFIX + lines[index][len(_UNMET_PREFIX) :]
    return "\n".join(lines)
