"""Pure logic for the eval coverage ledger and the changed-files selector.

UNCONDITIONALLY free of I/O. The ledger, the items on disk, the set of existing eval paths, today's
date and the changed-file list all arrive as arguments.

LEDGER SHAPE (`evals/ledger.json`, JSON because the Python core, bats via `jq` and CI all read it
with nothing to install; YAML would add a parser dependency to a gate whose point is zero cost):

    {"version": 1,
     "evals": {"evals/<name>": {"covers": ["<glob>", ...]}},
     "items": {"skills/<name>": {"eval": "evals/<name>"},
               "agents/<name>": {"waiver": "<reason>", "review_by": "YYYY-MM-DD"}}}

`items` is CLOSED over `skills/*/SKILL.md` and `agents/*.md`: every one is an eval or a dated waiver,
so the next skill cannot arrive with neither. `evals` is the selector's table: an eval is chosen when
a changed file matches one of its `covers` globs. An eval row may exist with no item pointing at it
(a harness over a CLI or a data contract rather than a skill).

GLOBS: `*` and `?` stay inside one path segment, `**` crosses segments, and a trailing `/**` matches
everything beneath the directory. Matching is on repo-relative POSIX paths.

THE SELECT-ALL RULE. A change to the ledger, to the shared eval machinery, or to the Makefile can alter
what EVERY eval means, so it selects all of them instead of trying to reason about which are safe.
"""

from __future__ import annotations

import re
from typing import NamedTuple

LEDGER_PATH = "evals/ledger.json"
VERSION = 1

# Paths whose change selects every eval. `evals/*` is the single-segment form on purpose: it matches
# top-level files in evals/ (the ledger, shared helpers) and never a per-eval directory's contents,
# which select only that eval through its own `covers`. The whole Makefile is listed rather than just
# its eval targets: telling the two apart needs a parser for make, and over-selecting on a Makefile
# change is the cheap direction to be wrong in.
SELECT_ALL_GLOBS = ("evals/*", "Makefile", "borg_core/evals/**")

_DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


class Selection(NamedTuple):
    """What the selector chose, and why a given answer was reached."""

    evals: list[str]
    select_all: bool
    reason: str


def glob_regex(pattern: str) -> re.Pattern[str]:
    """Compile a path glob (`*`, `?`, `**`, trailing `/**`) to an anchored regex."""
    out: list[str] = []
    i = 0
    while i < len(pattern):
        if pattern.startswith("/**", i) and i + 3 == len(pattern):
            out.append("/.+")
            i += 3
        elif pattern.startswith("**", i):
            out.append(".*")
            i += 2
        elif pattern[i] == "*":
            out.append("[^/]*")
            i += 1
        elif pattern[i] == "?":
            out.append("[^/]")
            i += 1
        else:
            out.append(re.escape(pattern[i]))
            i += 1
    return re.compile("^" + "".join(out) + "$")


def matches(path: str, globs: list[str] | tuple[str, ...]) -> bool:
    """True when `path` matches any glob."""
    return any(glob_regex(g).match(path) for g in globs)


def _row_problems(name: str, row: object, evals: dict, today: str) -> list[str]:
    if not isinstance(row, dict):
        return [f"{name}: row must be an object"]
    has_eval, has_waiver = "eval" in row, "waiver" in row
    if has_eval == has_waiver:
        return [f"{name}: must carry exactly one of `eval` or `waiver`"]
    if has_eval:
        if row["eval"] not in evals:
            return [f"{name}: eval {row['eval']!r} has no row in `evals`"]
        return []
    out: list[str] = []
    if not str(row["waiver"]).strip():
        out.append(f"{name}: waiver has no reason")
    review_by = str(row.get("review_by", ""))
    # JUSTIFICATION: flat validation ladder; a lookup table would hide the per-branch message
    if not _DATE.match(review_by):  # pylint: disable=clean-arch-delegation
        out.append(f"{name}: waiver needs review_by as YYYY-MM-DD")
    elif review_by < today:
        out.append(f"{name}: waiver expired {review_by} (today {today}) -- build the eval or renew with a reason")
    return out


def ledger_problems(ledger: dict, on_disk: list[str], existing_evals: set[str], today: str) -> list[str]:
    """Every way the ledger fails to be a closed, honest account of `on_disk` items."""
    problems: list[str] = []
    evals = ledger.get("evals", {})
    items = ledger.get("items", {})
    if ledger.get("version") != VERSION:
        problems.append(f"ledger: version must be {VERSION}")
    for item in sorted(set(on_disk) - set(items)):
        problems.append(f"{item}: not in the ledger -- add an eval or a dated waiver")
    for item in sorted(set(items) - set(on_disk)):
        problems.append(f"{item}: ledger row names an item that does not exist")
    for name, row in sorted(evals.items()):
        if name not in existing_evals:
            problems.append(f"{name}: eval path missing (no {name}/run.sh)")
        covers = row.get("covers") if isinstance(row, dict) else None
        if not isinstance(covers, list) or not covers or not all(isinstance(c, str) and c for c in covers):
            problems.append(f"{name}: needs a non-empty `covers` list of globs")
    for name, row in sorted(items.items()):
        problems.extend(_row_problems(name, row, evals, today))
    return problems


def select(ledger: dict, changed: list[str]) -> Selection:
    """Choose the evals a set of changed files should run."""
    evals = ledger.get("evals", {})
    names = sorted(evals)
    for path in changed:
        if matches(path, SELECT_ALL_GLOBS):
            return Selection(names, True, f"{path} is shared eval machinery: selecting all {len(names)}")
    picked = [n for n in names if any(matches(p, evals[n].get("covers", [])) for p in changed)]
    if not picked:
        return Selection([], False, f"nothing to run: {len(changed)} changed file(s), none covered by an eval")
    return Selection(picked, False, f"{len(picked)} of {len(names)} eval(s) cover {len(changed)} changed file(s)")
