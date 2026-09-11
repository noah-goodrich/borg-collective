"""The orchestration rung: read a plan, resolve every criterion's evidence, report, and optionally
write. Impure by composition -- it calls `shell.py` -- and holds no logic of its own that `core.py`
could have held.

WHY THIS IS NOT IN `cli.py`: the `/borg-link-up` skill's caller is `--json`, and that skill (AC1-AC5)
will want the same report from Python without going through argparse and stdout. A CLI that is the only door to a
capability is a capability that has to be re-implemented the first time something else wants it.

THE `pr:` REFS ARE COLLECTED BEFORE ANYTHING IS RESOLVED, so the whole document costs ONE `gh`
round trip instead of one per criterion. That ordering is also what lets a document with no `pr:`
annotation spawn no subprocess at all.
"""

from __future__ import annotations

from pathlib import Path

from borg_core.planstate import core, shell

REPORT_VERSION = 1


def repo_root(path: Path) -> Path:
    """The nearest ancestor of `path` containing `.git`, else `path`'s directory.

    `path:` AND `bats:`/`pytest:` ANNOTATIONS ARE REPO-RELATIVE (the amendment's wording), so a plan at
    `docs/plans/directives/x.md` must resolve `borg_core/planstate/` against the repository, not
    against `docs/plans/directives/`. Falling back to the containing directory rather than raising
    keeps a plan file outside any repository usable -- its annotations simply resolve relative to
    where it sits, which is the only reading available.
    """
    here = path.resolve().parent
    for candidate in [here, *here.parents]:
        if (candidate / ".git").exists():
            return candidate
    return here


def _resolve(gate: dict, root: Path, fetch: dict) -> tuple[str, str]:
    """`(verdict, evidence line)` for one parsed criterion. Every impure answer arrives through
    `shell`; every DECISION is `core`'s.

    A REJECTED OR ABSENT ANNOTATION IS `unknown` WITH ITS REASON, never `fail` -- AC9's rejection and
    the directive's "a criterion resting on judgment is never flipped, and the checkpoint says so by
    name" are the same branch. Note what does NOT happen here: the rejected value is not logged into
    a command, not passed to a runner, and not interpolated into anything. It reaches `shell` only
    when `gate["ok"]` is True.
    """
    if not gate["ok"]:
        return core.UNKNOWN, gate["reason"]
    kind, value = gate["kind"], gate["value"]
    if kind == "pr":
        return core.verdict_for_pr(value, fetch)
    if kind == "path":
        return core.verdict_for_path(shell.exists(root, value), value)
    present = shell.exists(root, value)
    # THE RUNNER IS NOT STARTED FOR A PATH THAT IS NOT THERE. `verdict_for_suite` would answer
    # `unknown` either way, but running `pytest <missing>` to learn that costs a fork and returns
    # exit 4, which is indistinguishable from a genuinely broken suite at this layer.
    result = shell.run_suite(root, kind, value) if present else None
    return core.verdict_for_suite(kind, value, present, result)


def derive(path: Path, root: Path | None = None) -> dict:
    """The full report for one plan file. Reads; never writes. This is `--json`'s whole payload.

    `flips` IS THE INTERSECTION OF TWO CONDITIONS AND NOTHING ELSE: the criterion is currently
    `- [ ]`, and its verdict is `pass`. A `fail`, an `unknown`, and an already-`[x]` criterion are
    all absent from it, which is what AC8's byte-compare pins.
    """
    text = shell.read_text(path)
    if text is None:
        raise FileNotFoundError(f"cannot read plan file: {path}")
    base = root if root is not None else repo_root(path)
    criteria = core.parse_criteria(text)
    gates = [core.validate_annotation(entry["annotation"]) for entry in criteria]
    refs = [gate["value"] for gate in gates if gate["ok"] and gate["kind"] == "pr"]
    fetch = shell.resolve_prs(refs)
    rows = []
    flips = []
    for entry, gate in zip(criteria, gates):
        verdict, evidence = _resolve(gate, base, fetch)
        row = {
            "line": entry["line"],
            "checked": entry["checked"],
            "text": entry["text"],
            "annotation": entry["annotation"],
            "kind": gate["kind"] if gate["ok"] else "",
            "verdict": verdict,
            "evidence": evidence,
            "would_flip": verdict == core.PASS and not entry["checked"],
        }
        if row["would_flip"]:
            flips.append(entry["line"])
        rows.append(row)
    return {
        "report_version": REPORT_VERSION,
        "file": str(path),
        "root": str(base),
        "criteria": rows,
        "flips": flips,
        "counts": _counts(rows),
        "fetch": {"status": fetch.get("status", ""), "warnings": list(fetch.get("warnings") or [])},
    }


def _counts(rows: list[dict]) -> dict:
    """The report's tallies. Split out only so `derive` stays readable; no logic lives here that a
    consumer could not recompute from `criteria`."""
    return {
        "total": len(rows),
        "checked": sum(1 for row in rows if row["checked"]),
        core.PASS: sum(1 for row in rows if row["verdict"] == core.PASS),
        core.FAIL: sum(1 for row in rows if row["verdict"] == core.FAIL),
        core.UNKNOWN: sum(1 for row in rows if row["verdict"] == core.UNKNOWN),
        "would_flip": sum(1 for row in rows if row["would_flip"]),
    }


def apply(path: Path, report: dict) -> int:
    """Flip the report's `pass` criteria in `path` and return how many boxes moved.

    THE FILE IS RE-READ HERE rather than the derive's copy being edited in memory, because the derive
    may have taken minutes (a `pytest:` annotation runs a suite) and a human may have edited the plan
    in that window. `core.apply_flips` re-tests each target line for the `- [ ]` prefix, so a line
    that moved under us is a no-op rather than a corruption -- the count returned is what ACTUALLY
    moved, not what was proposed.

    NO WRITE AT ALL WHEN NOTHING WOULD MOVE. A run that flips nothing must not touch the file's
    mtime: `borg link`'s newest-checkpoint and directive readers sort on it, and an `--apply` that
    rewrites 30 directives byte-identically every session would reorder that board for no reason.
    """
    flips = list(report.get("flips") or [])
    if not flips:
        return 0
    text = shell.read_text(path)
    if text is None:
        raise FileNotFoundError(f"cannot read plan file: {path}")
    updated = core.apply_flips(text, flips)
    if updated == text:
        return 0
    shell.write_atomic(path, updated)
    return _moved(text, updated)


def _moved(before: str, after: str) -> int:
    """How many lines differ between the two texts. The honest count for `apply`'s return value --
    `len(flips)` would over-report when a target line moved under us and `apply_flips` no-op'd it."""
    old = before.split("\n")
    new = after.split("\n")
    return sum(1 for index, line in enumerate(old) if index < len(new) and line != new[index])
