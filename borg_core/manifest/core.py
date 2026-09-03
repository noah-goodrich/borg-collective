"""Pure logic for borg's declared manifests: the cross-repository graph a set of rows describes.

This module is UNCONDITIONALLY free of raw I/O: no subprocess, no file open(), no network, no
environment reads, no clock reads. Every function here takes already-gathered data as arguments and
returns plain data structures or strings. All I/O (filesystem reads, subprocess calls, environment
and clock lookups) lives in shell.py, which calls into this module for the actual logic.

Ports the pure half of merge-tree/programs.py:40-271 -- GATE_KINDS, PREREQ_ORDERS, DEFAULT_LANE,
looks_like_manifest, validate, lanes, derive_edges, unmapped_gates and their private helpers.
PORTED, NOT IMPORTED, and that is forced twice over: `merge-tree` carries a hyphen so it can never
be a Python package name, and pyproject.toml:76 pins
`allowed_prefixes = ["borg_core", "__future__"]`, so an import would fail `make lint` even if the
path resolved.

THE PORT HAS DELIBERATELY DIVERGED from the copy that still lives in merge-tree/programs.py, which
is itself still live (merge-tree/coordinator.py rewrites manifests through its writer and
merge-tree/gather.py derives the viz graph from it). The differences, so the next editor of either
copy can see them: this side validates `after` and derives edges from it (the writer over there
accepts an `after` of any shape and derives nothing from it, so its write gate is WEAKER than this
read gate -- a manifest it happily writes can be rejected here), this side deduplicates edges within
a manifest, this side requires every declared ref to be a FULL `owner/repo#num`, this side no longer
closes `gate.kind` to GATE_KINDS (see _validate_gate: an unrecognized kind is a ROUTER concern here
and a validation error over there, so this read gate is the WEAKER of the two on that one field --
the only axis where the asymmetry runs that direction), and this side does not use the retired
"program" vocabulary in any name. Retiring one of the two copies is AC7's problem, not this module's.

WHY DECLARED EDGES EXIST AT ALL. Branch topology only ever links PRs inside ONE repository -- a base
branch is a repository-local name -- so nothing mechanical says `stillpoint#48` must merge before
`ingle#12`. That ordering lives only in the head of whoever planned the work. It therefore has to be
*declared*, and this module reads borg's own declaration of it.

ROWS KEY ON `ref`, and that is a deliberate divergence from keying on repository + number. `ref` is
already the one canonical key used everywhere -- recon's items, the derived edges, and the
cross-source dedup in borg_core/recon/core.py:186-194 all key off the EXACT `owner/repo#number`
string. Keying rows the same way means derived edges need no ref normalization, which removes a whole
silent-failure class: a wrong `Owner/repo` -> `repo#num` transform yields edges whose endpoints match
no item, so they disappear from the graph without ever raising. See parse_ref for the rule that keeps
it that way.

PROSE IS NEVER GUESSED INTO AN EDGE. `gate.blocked_by` is prose ("waiting on Kelly's review"), so it
is never string-matched; a blocker with no ref is correct input, not a defect, and guessing would
manufacture edges pointing at nothing. Those gates are counted and reported by unmapped_gates
instead. The only machine-readable blocker channel is `gate.blocked_by_ref`, and validate requires it
to parse as a full ref precisely so it can never become prose by accident.

EVERY DECLARED REF IS HELD TO A VOCABULARY, and validate is where that is surfaced. The vocabulary is
NOT the same at all four sites, and the asymmetry is deliberate rather than an oversight:

  * `rows[].ref` accepts three kinds -- a GitHub PR, a Jira key, or an http(s) link (`refs.ref_kind`).
    A chain describes a project, and a project has the ticket that asked for it and the document that
    explains it, not only its pull requests.
  * `apex.ref`, `gate.blocked_by_ref` and every `after` entry still require a full `owner/repo#number`
    (parse_ref). These are EDGE ENDPOINTS, and an edge means "this merges before that" -- a question
    only a ref with resolvable merge state can answer. So a Jira row can be declared but cannot yet be
    another row's prerequisite. Deliberate MVP boundary, stated so nobody "fixes" it by widening the
    endpoints without first deciding what an edge into a document would mean.
A shorthand like `ingle#12` used to validate clean, load through discovery, and produce a node that
AC3's targeted fetch cannot build (it renders `unknown`, which AC3 forbids) and that ref_slug cannot
scope to any repository (so the row is invisible in its own repository's grid). parse_ref's contract
is that a non-conforming ref is a manifest defect to SURFACE, not a string to repair -- this is the
surfacing point, and a validate error is fatal at load in shell._load_manifest.

VOCABULARY. A *repository* is a git repo; a *project* is work spanning one or more repositories.
"Program" is retired and names nothing here. The manifest FILES still live under `.borg/programs/`
and still carry a top-level `program` key; those two literals are read verbatim because they are what
is on disk, and nothing new is named after them.

WHERE MANIFESTS COME FROM. Files are read only from `<repository>/.borg/programs/` -- never from
`<repository>/.borg/` and never from the repository root. But the sweep spans EVERY registered
repository, not just the one in scope: a manifest declaring refs across four repositories lives under
exactly one of them, so repository-scoped discovery renders an empty grid for the other three (the
hardened spec's B6). Discovery is GLOBAL (shell.discover_registered); *selection* is scoped
(select_for_repository below).
"""

# THE C0302 DISABLE THAT USED TO SIT HERE IS GONE, AND THE SPLIT IS WHY. This module crossed the
# 1000-line ceiling on 2026-09-01 when the writer's two pure helpers landed at 999, and carried a
# measured disable for exactly one commit. The note under it said: "If it needs to grow again, SPLIT
# IT rather than extending this note: the seam is already visible -- the ref vocabulary (`parse_ref`,
# `ref_slug`, `slug_from_remote`, `suggest_full_ref`, and their regexes) is a self-contained ~120
# lines that the validator, the selector and the topology all merely consume."
#
# It needed to grow again the same day, so the split happened rather than the note growing. The ref
# vocabulary is `refs.py`; this file is back under the ceiling at ~930 lines and needs no exemption.
# Every public name from it is re-exported above, so `core.parse_ref` and `refs.parse_ref` are the
# same object and no caller moved.
#
# The general lesson, which is why this paragraph survives the disable it replaces: a suppression
# with an expiry condition written next to it is the only kind that gets removed. An unconditional
# one is permanent by default.

from __future__ import annotations

import re
from typing import Any

from borg_core.manifest import refs as _refs
from borg_core.manifest.errors import (
    _GOT_MARKER,
    offending_value,
    partition_errors,
)
from borg_core.manifest.refs import (
    expects_github,
    is_reference,
    parse_ref,
    ref_kind,
    ref_slug,
    slug_from_remote,
    suggest_full_ref,
    text as _text,
)

# Declared, not aliased: `__all__` tells ruff (F401) and pylint these are deliberate public surface
# rather than unused imports. The `X as X` spelling satisfies ruff but pylint rejects it (C0414).
__all__ = [
    "expects_github",
    "is_reference",
    "offending_value",
    "parse_ref",
    "partition_errors",
    "ref_kind",
    "ref_slug",
    "slug_from_remote",
    "suggest_full_ref",
]

# RE-EXPORTED, NOT REIMPLEMENTED. The ref vocabulary moved to refs.py when this module crossed
# C0302's ceiling; these mean no caller, test or golden moved with it, and `core.parse_ref` IS
# `refs.parse_ref` -- no second definition to drift.
#
# IMPORTED, NOT ASSIGNED. `x = _refs.x` is a module-scope ATTRIBUTE READ, so every alias landed in
# `test_module_reads_no_environment_or_clock_at_import_time`'s exact-set assertion -- a test about
# clocks accumulating re-export names. An import produces no `ast.Attribute` node.
#
# ONLY NAMES WITH CALLERS (counted: 13, 7, 8, 2, 1, 1). The kind constants and `is_tracked` have zero
# consumers through `core.` and are reached as `refs.X`. `_REF_RE` is private to refs.py, so aliasing
# it would be a protected-access bypass for a name nothing outside that module matches on.


# THE ROUTER'S VOCABULARY, NOT THE VALIDATOR'S. `decision` means a human must *choose*;
# `verification` means someone must *run* something. The distinction matters because a `verification`
# with declared outcomes is never a blocker on a *person* -- anyone can run it -- so it must not be
# routed to the awaiting-you tier the way a `decision` is.
#
# THE VALIDATOR NO LONGER CLOSES ON THIS SET. `_validate_gate` requires only that a gate NAME some
# kind; a kind outside this set is a ROUTER concern and routes to `render._GROUP_UNSURE` rather than
# costing the row. See `_validate_gate` for the argument.
#
# CONSEQUENCE, STATED SO THE NEXT READER DOES NOT DELETE IT AS DEAD: after that demotion this
# constant has no production reader at all -- `render.py` never imports this module, it carries its
# own `_GATE_ROUTING` table. The one live tie is
# `test_render.py::test_the_router_covers_every_declared_gate_kind`, which asserts the router is
# never BEHIND this declared vocabulary. That subset test is load-bearing for this constant's
# continued existence; removing either leaves the other pointless.
GATE_KINDS = {"decision", "verification"}

# Rows whose `order` is one of these are merged pre-stack prerequisites: real ancestors of the chain
# with no declared position among themselves. They keep their file order (see _sort_key).
#
# THE DASHES ARE FOUR DISTINCT VALUES: ASCII HYPHEN-MINUS (U+002D), EN DASH (U+2013), EM DASH
# (U+2014) and the empty string. Copied byte-for-byte from merge-tree/programs.py:48, not retyped,
# and pinned by a codepoint assertion in test_core.py because the glyphs are visually
# indistinguishable at a glance. Every prerequisite row in both live manifests uses U+2013
# exclusively (7 of 16 rows), so an editor pass or a "normalize the punctuation" reflex that rewrote
# the en dash to ASCII would drop all seven into the numbered bucket, where the digit search finds
# nothing and they fall back to file index. In the live data that happens to land the same order by
# luck; the regression surfaces in exactly one place,
# test_prerequisites_sort_ahead_of_numbered_rows_in_file_order.
PREREQ_ORDERS = {"-", "–", "—", ""}

DEFAULT_LANE = "_default"

# The states the github recon adapter emits, lowercased at lib/recon/adapters/recon-adapter-github:179
# (`state: (.state | ascii_downcase)`) from the GraphQL `PullRequest.state` enum. Exactly three
# values, and draft-ness is NOT one of them -- a draft PR is `open` with `isDraft` carried in the
# prose `changed` field. Do not add a fourth token without checking it against
# borg_core/recon/core.py:27's `_RESOLVED_STATE_RE`, which decides what counts as resolved.
#
# STATE_CLOSED HAS NO READER HERE and that is deliberate: ready_set reads STATE_OPEN and
# STATE_MERGED, and `closed` is simply neither, so it needs no branch of its own. It is declared
# because this is the adapter's CLOSED vocabulary -- naming two of three tokens would leave the
# third looking like an oversight, and the "do not add a fourth token" rule above is only checkable
# against a complete list.
STATE_OPEN = "open"
STATE_MERGED = "merged"
STATE_CLOSED = "closed"

# The edge kinds that express ORDERING, and therefore the only ones levels() and ready_set() read.
# `apex` is deliberately absent: an apex edge points from the tracker at EVERY row, so counting it
# would give every row an in-edge from one rank-0 node and flatten the entire stack into level 1.
# This mirrors merge-tree/render_graph.py:662, which filters its rank sweep to the same two kinds.
ORDERING_EDGE_KINDS = ("stacked", "blocks")


_ORDER_DIGITS = re.compile(r"(\d+)")


def _rows(manifest: dict[str, Any]) -> list[dict[str, Any]]:
    """The manifest's rows, or an empty list. Never raises on a malformed value."""
    rows = manifest.get("rows")
    return [r for r in rows if isinstance(r, dict)] if isinstance(rows, list) else []


# `_text` is imported as refs.text above -- one definition, in the leaf that owns the vocabulary. See
# its docstring for the stripping contract and the inherited integer-0 trap. The private spelling is
# kept because thirty call sites in this module use it.


def looks_like_manifest(doc: Any) -> bool:
    """Positive shape check, so discovery cannot mistake unrelated JSON for a manifest.

    Discovery globs a directory; a stray file that happens to live there must be skipped rather than
    half-parsed into edges. Requires a `rows` list specifically -- the one field every manifest has
    and that arbitrary config JSON is unlikely to carry. The `isinstance(doc, dict)` guard is
    load-bearing, not padding: a top-level JSON list would raise AttributeError on `.get`.
    """
    return isinstance(doc, dict) and isinstance(doc.get("rows"), list)


def declared_body(manifest: dict[str, Any]) -> dict[str, Any]:
    """A manifest's declared body: every key the AUTHOR wrote, and no key this package derived.

    ONE definition of "derived", used by both directions of the round trip. `_manifest_identity`
    needs it to compare two copies of one declaration; `shell.write_manifest` needs it so a document
    that came out of `_load_manifest` -- which stamps `_path` AND `_id` -- can go back to disk
    without persisting either. Those two had to agree and did not: the writer this replaces stripped
    exactly `_path`, so every synced file gained a permanent `"_id"` that nothing rejects and nothing
    reads. The only symptom was a `git diff` on a tracked directory.

    PREFIX RULE, NOT A NAME LIST. A list would have to be updated in this file every time the loader
    learns to stamp something, and the failure mode of forgetting is silent persistence of the new
    key. `_`-prefixed means derived, everywhere in this package, and `manifest_dir`'s docstring
    already relies on that convention holding.

    Note `merge-tree/coordinator.py:98` does this same strip by hand to build the payload for an
    out-of-repo sync shim, and is NOT yet routed here -- it still names `_path` alone. Repointing it
    is the retirement's job; until then that shim receives an `_id` this writer no longer writes.
    """
    return {k: v for k, v in manifest.items() if not k.startswith("_")}


def _validate_apex(apex: Any) -> list[str]:
    """Problems with a manifest's optional apex. No apex at all is valid, not a problem.

    Core-rule exception, and the state BOTH live manifests are actually in: work small enough to need
    no diagram and no gates legitimately has no tracker, and pointing at one that does not exist is
    worse than pointing at nothing.
    """
    if apex is None:
        return []
    if not isinstance(apex, dict):
        return ["apex: must be an object when present"]
    ref = _text(apex.get("ref"))
    if not ref:
        return ["apex: present but has no ref"]
    if parse_ref(ref) is None:
        # Same rule as every other declared ref: declared_refs feeds AC3's targeted fetch, and a
        # shorthand apex would render `unknown` forever. See the module docstring.
        return [f"apex: ref must be a full ref (owner/repo#num){_GOT_MARKER}{ref}"]
    return []


def _blocked_by_ref_error(gate: dict[str, Any], ref: str, label: str) -> str:
    """What is wrong with a gate's optional `blocked_by_ref`, or "" when nothing is.

    `blocked_by_ref` is the OPTIONAL machine-readable companion to the prose `blocked_by`, and its
    only job is to be an edge endpoint. Two ways that fails silently, both checked here:

    NOT A FULL REF. A bare `"#"` test admitted prose -- `"waiting on PR #149"`, `"#149"`, even
    `"#"` -- and prose here produces a `blocks` edge pointing at nothing, which is the exact failure
    `blocked_by` stays prose to avoid. Worse than the `after` channel, because a gate carrying ANY
    truthy `blocked_by_ref` is excluded from unmapped_gates: the gate then appears in no report at
    all while permanently wedging its row out of ready_set. The live manifest's own prose carries
    `#`-bearing text (`"PM1-PM10 depend only on gather.py (PR #149)"`), so this is the shape a hand
    author actually writes.

    NAMING ITS OWN ROW. `_blocks_edges` drops a self-edge, unmapped_gates skips any gate with a
    truthy `blocked_by_ref`, and ready_set then sees a row with no parents -- so an OPEN decision
    gate is erased in three places at once and its row is announced READY. `_validate_after` has had
    exactly this check on the sibling channel since it was written; the more dangerous channel was
    missing it.
    """
    value = _text(gate.get("blocked_by_ref"))
    if not value:
        return ""
    if parse_ref(value) is None:
        return f"{label}: gate.blocked_by_ref must be a full ref (owner/repo#num){_GOT_MARKER}{value}"
    if value == ref:
        return f"{label}: gate.blocked_by_ref names its own ref {value}"
    return ""


def _validate_gate(gate: Any, ref: str, label: str) -> list[str]:
    """Problems with one row's optional gate. Extra keys (e.g. a live gate's `outcomes`) are ignored.

    Takes the row's own `ref` for the same reason `_validate_after` does: the self-reference check
    cannot be made without it.

    AN UNRECOGNIZED KIND IS THE ROUTER'S PROBLEM; AN ABSENT ONE IS A DEFECT. `kind` used to be closed
    to `GATE_KINDS`, which meant a typo'd `review` was a row-scoped error and -- after
    docs/plans/directives/2026-08-27-degrade-the-row-not-the-manifest.md made degradation row-level --
    silently DELETED the row. That is strictly worse than the outcome the renderer already built for
    it: `render._route` sends any kind it does not recognize to the `unsure` group, which names the
    kind on the page. So the row loads, ranks, draws and routes, and the human sees the word they
    mistyped instead of a gap.

    EMPTY OR MISSING STAYS FATAL, and the two are different facts. `render._next_tally` reads
    `kind = gate.get("kind") or ""` and `_route("")` returns `mine` BECAUSE AN UNGATED ROW IS MINE. A
    demoted blank kind would land a GATED row under `mine`, whose heading (`render._GROUP_HEADINGS`
    owns the wording) claims no decision is needed first -- which the router cannot know about a gate
    that named no kind. That is the unfounded assertion `render._GROUP_UNSURE` exists to avoid, and
    blank is less known still. Blank stays fatal so `_route("")` means "no gate", never "a gate that
    named nothing"; `_text` collapses `None`, a missing key, `""` and `"   "` into that one case.

    `blocked_by` and `resolved_by` stay REQUIRED and stay row-scoped errors. They are not vocabulary
    questions -- a gate that names neither its blocker nor its settlement parks work while pointing at
    nothing, and no renderer can route around that.
    """
    if gate is None:
        return []
    if not isinstance(gate, dict):
        return [f"{label}: gate must be an object"]

    errors = []
    if not _text(gate.get("kind")):
        errors.append(f"{label}: gate.kind is required")
    for field in ("blocked_by", "resolved_by"):
        if not _text(gate.get(field)):
            # A blocker with no pointer at its settlement is the defect this field exists to prevent:
            # it parks work for weeks while naming nothing that would unpark it.
            errors.append(f"{label}: gate.{field} is required")

    problem = _blocked_by_ref_error(gate, ref, label)
    if problem:
        errors.append(problem)
    return errors


def _after_entry_error(entry: Any, ref: str, label: str) -> str:
    """What is wrong with one `after` entry, or "" when nothing is.

    Guard clauses rather than an if/elif ladder: the same `errors.append(...)` in every branch of a
    chain is what the clean-architecture linter reads as a delegation anti-pattern (W9005), and one
    reason-per-return is easier to extend anyway.
    """
    if not isinstance(entry, str):
        return f"{label} must be a ref string{_GOT_MARKER}{type(entry).__name__}"
    value = entry.strip()
    if not value:
        return f"{label} is empty"
    if parse_ref(value) is None:
        # A bare `"#" in value` test admitted `"waiting on PR #149"`, `"#149"` and `"#"`, each of
        # which becomes a `stacked` edge whose parent is that literal string -- a parent no state
        # lookup can ever resolve, so the row leaves ready_set permanently while the query built
        # from declared_refs goes looking for prose.
        return f"{label} must be a full ref (owner/repo#num){_GOT_MARKER}{value}"
    if value == ref:
        return f"{label} names its own ref {value}"
    return ""


def _validate_after(row: dict[str, Any], ref: str, label: str) -> list[str]:
    """Problems with one row's optional `after` list -- AC4's fork channel. SHAPE only.

    Lanes express a LINEAR track and nothing else: a lane is a sequence, so two rows that both depend
    on the same parent cannot be said in lane vocabulary. `after: [refs]` is the explicit parent list
    that makes a fork expressible.

    Checked here: `after` must be a list, every entry must be a non-blank ref-looking string (the same
    `#` test `gate.blocked_by_ref` gets, for the same reason -- prose here would produce an ordering
    edge pointing at nothing), and a row may not name ITSELF, which would declare a row its own
    prerequisite and, in levels(), be silently dropped as a self-edge rather than reported.

    NOT checked, deliberately: whether the named ref is a row in THIS manifest. An `after` ref that
    points outside the manifest is VALID input -- it is exactly what AC3's targeted fetch exists to
    resolve, and rejecting it would make the one case the feature was built for a validation error.

    `after: null` is treated as absent, matching how _validate_gate treats a null gate.

    THE WRITE GATE IS WEAKER THAN THIS READ GATE, and that asymmetry is worth knowing about:
    merge-tree/programs.py -- still live, still rewriting every manifest in place through its own
    writer -- validates no `after` at all, so it will happily write `"after": "o/r#2"` (a bare
    string) which this rejects, dropping the ENTIRE file at shell._load_manifest. Today's live
    manifests carry no `after`, so it is latent. See the module docstring for the full divergence
    list.
    """
    after = row.get("after")
    if after is None:
        return []
    if not isinstance(after, list):
        return [f"{label}: after must be a list of refs"]

    errors = []
    for j, entry in enumerate(after):
        problem = _after_entry_error(entry, ref, f"{label}: after[{j}]")
        if problem:
            errors.append(problem)
    return errors


def _row_ref_error(ref: str, label: str) -> str:
    """What is wrong with a row's own `ref`, or "" when nothing is.

    THREE VOCABULARIES, NOT ONE (2026-09-01). A row may name a GitHub pull request, a Jira issue, or a
    link (Notion, a Google Doc, an uploaded asset). `refs.ref_kind` decides which; "" means the string
    is none of them and is a defect. Before this the only legal ref was `owner/repo#num`, which was
    inherited rather than decided -- and retiring merge-tree, whose validator accepted any non-empty
    string, would have made that narrowing permanent on the deletion commit.

    THE RULE DID NOT GET LOOSER, IT GOT TYPED. Each kind is anchored, so the mistake this check exists
    to catch is still caught: `ingle#12` is a GitHub ref missing its owner, matches no kind, and is
    reported -- with `suggest_full_ref` handing back the exact token when the author already named
    this repository. Accepting anything non-empty is what let that typo resolve against nothing.

    The message names all three vocabularies rather than only GitHub's, because an author who wrote
    `docs/spec.md` needs to know a bare path is not a link, not be told about `owner/repo#num`.
    """
    if not ref:
        return f"{label}: missing ref"
    if not _refs.ref_kind(ref):
        return (
            f"{label}: ref must be a GitHub ref (owner/repo#num), a Jira key (PROJ-123) "
            f"or an http(s) link{_GOT_MARKER}{ref}"
        )
    return ""


def _validate_row(row: Any, index: int, seen: dict[str, int]) -> list[str]:
    """Every problem with one row. `seen` accumulates ref -> first index across the whole pass."""
    label = f"rows[{index}]"
    if not isinstance(row, dict):
        return [f"{label}: not an object (got {type(row).__name__}) -- a bare value declares nothing"]

    errors = []
    ref = _text(row.get("ref"))
    problem = _row_ref_error(ref, label)
    if problem:
        errors.append(problem)
    if ref and ref in seen:
        # A duplicated ref would produce two chain positions for one item and make the derived edge
        # set depend on iteration order.
        errors.append(f"{label}: duplicate ref {ref} (already at rows[{seen[ref]}])")
    elif ref:
        seen[ref] = index

    # KEY presence, not truthiness: a row with `"order": ""` or `"order": null` is VALID and sorts as
    # a prerequisite (_sort_key coerces through _text). Changing this to a truthiness test would
    # reject legal manifests.
    if "order" not in row:
        errors.append(f"{label}: missing order")

    errors.extend(_validate_gate(row.get("gate"), ref, label))
    errors.extend(_validate_after(row, ref, label))
    return errors


def validate(manifest: dict[str, Any]) -> list[str]:
    """Every problem with a manifest, in one pass. Empty list means valid.

    Reports ALL offending rows rather than stopping at the first, so a manifest is fixed in one edit
    instead of N runs. Callers must treat a non-empty result as fatal BEFORE writing anything -- a
    malformed manifest that half-writes is worse than one that is rejected.

    Iterates the RAW rows list, NOT _rows(): _rows filters non-dict entries so tolerant READERS never
    crash, and validation must do the exact opposite and report them. `{"rows": ["a#1", "b#1"]}` is a
    plausible hand-authoring typo that would otherwise validate clean, load through discovery, and
    declare nothing -- silently. A future refactor that shares _rows() here "for consistency"
    reintroduces that bug.
    """
    if not isinstance(manifest.get("rows"), list):
        return ["rows: missing or not a list"]

    errors = _validate_apex(manifest.get("apex"))
    seen: dict[str, int] = {}
    for i, row in enumerate(manifest["rows"]):
        errors.extend(_validate_row(row, i, seen))
    return errors


def _sort_key(row: dict[str, Any], index: int) -> tuple[int, int, int]:
    """Sort rows within a lane by declared merge order.

    Prerequisites come first in file order -- a hand-authored list is itself a declaration, and they
    carry no number to sort on. Numbered rows follow, by the integer in `order`, which covers both
    lane-prefixed ids (`E1`, `I2`) and plain single-stack integers (`1`, `2`). A number that cannot be
    parsed falls back to file position rather than being dropped.

    The THIRD element is explicit, not inherited from Python's stable sort: two rows in one lane whose
    orders parse to the same number (`1` and `E1`) are resolved by declared file position, and
    test_two_orders_parsing_to_the_same_number_are_broken_by_file_position is what pins it -- reversing
    it flips the lane, which flips the direction of the derived edge and inverts the level assignment.

    ON THE PREREQUISITE BRANCH the third element is shape only and CANNOT affect any ordering: the
    second element is already the row index, so no two prerequisite rows ever tie on it. It is written
    as (0, i, i) to keep both branches the same arity rather than because file order needs restating,
    and no test can discriminate it because there is no behavior there to discriminate.
    """
    order = _text(row.get("order"))
    if order in PREREQ_ORDERS:
        return (0, index, index)
    match = _ORDER_DIGITS.search(order)
    # JUSTIFICATION: reading the group of a Match this function just produced, not a foreign object.
    return (1, int(match.group(1)) if match else index, index)  # pylint: disable=clean-arch-demeter


def next_order_in_lane(manifest: dict[str, Any], lane: str, skip_index: int = -1) -> str:
    """The order a NEW row must carry to sort after every row already in `lane`.

    PUBLIC BECAUSE THE INCREMENT BELONGS WITH THE ORDERING. `_sort_key` decides where a row sits;
    anything that appends to a lane needs the next position, and a caller computing that from
    `order` strings is paraphrasing this module. `borg_core.manifest.cli` did exactly that and got
    two defects out of it -- it stripped lane names differently to `lanes` above, and it extracted
    DIGITS while `_sort_key` falls back to the row's FILE INDEX for an order holding none, so a
    digit-free order at index 3 sorts as position 3 while the caller counted it as nothing and
    handed a newcomer position 1, ahead of an untouched row that was then declared to depend on it.

    Prerequisites are excluded because they are not in the numbered sequence: `_sort_key` puts them
    in bucket 0, ahead of every numbered row, and a lane holding only prerequisites therefore starts
    its numbering at 1. `skip_index` lets a row being MOVED avoid counting itself, and it indexes
    `_rows`' filtered view -- the same enumeration `_sort_key` is handed here.
    """
    highest = 0
    for index, row in enumerate(_rows(manifest)):
        if index == skip_index or (_text(row.get("lane")) or DEFAULT_LANE) != lane:
            continue
        bucket, position, _ = _sort_key(row, index)
        if bucket:
            highest = max(highest, position)
    return str(highest + 1)


def lanes(manifest: dict[str, Any]) -> dict[str, list[dict[str, Any]]]:
    """Rows grouped by lane and sorted into declared merge order within each lane.

    A manifest with no `lane` on any row is single-stack mode and yields one lane. Rows missing a ref
    are excluded, and that exclusion is a LOAD-BEARING PRECONDITION, not tidiness: _stacked_edges,
    _after_edges, _apex_edges and _blocks_edges all index `row["ref"]` directly with no `.get`, which
    is safe only because this function already dropped refless rows and derive_edges builds its row
    list by flattening this output rather than calling _rows(). validate has already reported them.

    Lane names come back in `sorted()` order, NOT declaration order -- a live two-lane manifest yields
    `contract` before `cutover`. That is a public property of the return value; derive_edges re-sorts
    its edges anyway, but a consumer iterating lanes() sees alphabetical.
    """
    grouped: dict[str, list[tuple[tuple[int, int, int], dict[str, Any]]]] = {}
    for i, row in enumerate(_rows(manifest)):
        if not _text(row.get("ref")):
            continue
        lane = _text(row.get("lane")) or DEFAULT_LANE
        grouped.setdefault(lane, []).append((_sort_key(row, i), row))
    return {lane: [r for _, r in sorted(rs, key=lambda p: p[0])] for lane, rs in sorted(grouped.items())}


def _edge(parent: str, child: str, kind: str) -> dict[str, Any]:
    """One edge, always stamped `source: "declared"`.

    Provenance is not decoration: it is what makes a wrong edge falsifiable, and what lets a consumer
    split derived edges from declared ones without re-deriving either.
    """
    return {"parent": parent, "child": child, "kind": kind, "source": "declared"}


def _stacked_edges(by_lane: dict[str, list[dict[str, Any]]], declared_children: set[str]) -> list[dict[str, Any]]:
    """Consecutive rows within each lane. Cross-LANE pairs are never linked -- an edge between lanes
    would invent a total order nobody declared.

    A row in `declared_children` -- one whose `after` list supplied at least one usable parent --
    gets NO lane edge into it. That is the derivation rule SCHEMA.md:259-261 records for the field:
    "explicit `after` overrides consecutive-row inference within the lane." Unioning the two instead
    is what makes an INTRA-lane fork -- the exact shape AC4 adds `after` for -- silently render as a
    linear chain: rows 1,2,3 in one lane where row 3 declares `after: [row1]` keeps the inferred
    2->3 edge, so 3 ranks below 2 rather than beside it and READY announces one child instead of two.

    The override is keyed on edges ACTUALLY PRODUCED, not on the presence of an `after` key, so an
    empty or wholly unusable `after` (`[]`, `[7]`, `["  "]`) leaves the row attached to its lane
    rather than orphaning it from a chain it never opted out of.
    """
    edges = []
    for rows in by_lane.values():
        for parent, child in zip(rows, rows[1:]):
            p, c = _text(parent["ref"]), _text(child["ref"])
            if p != c and c not in declared_children:
                edges.append(_edge(p, c, "stacked"))
    return edges


def _after_edges(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Explicit parents from each row's `after` list -- AC4's fork channel.

    EMITTED AS `stacked`, NOT AS A FOURTH KIND, and that is the judgment call. levels() and
    ready_set() treat lane adjacency and `after` identically: both say "this must merge before that."
    A distinct `after` kind would force every consumer -- the ranking, the ready set, the renderer,
    and anything that later reads the wire shape -- to learn a distinction with no behavioral
    difference behind it, and the first consumer to forget it would silently stop ordering forks.
    The declaration is preserved on the row itself for anyone who needs to know how the edge arose.
    """
    edges = []
    for row in rows:
        after = row.get("after")
        if not isinstance(after, list):
            continue
        child = _text(row["ref"])
        for entry in after:
            if not isinstance(entry, str):
                continue
            parent = entry.strip()
            if parent and parent != child:
                edges.append(_edge(parent, child, "stacked"))
    return edges


def _apex_edges(manifest: dict[str, Any], rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """One edge per row to the tracker, or none when there is no apex (the live case for both
    manifests). The apex's own row gets no self-edge."""
    apex = manifest.get("apex")
    apex_ref = _text(apex.get("ref")) if isinstance(apex, dict) else ""
    if not apex_ref:
        return []
    return [_edge(apex_ref, ref, "apex") for ref in (_text(r["ref"]) for r in rows) if ref != apex_ref]


def _blocks_edges(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Dependencies from `gate.blocked_by_ref`, the only machine-readable blocker channel.

    `blocks` is a dependency BETWEEN workstreams, not evidence two items are the same workstream.
    Neither live manifest carries a single `blocked_by_ref`, so every live gate flows to
    unmapped_gates instead and this path is fixture-only today.
    """
    edges = []
    for row in rows:
        gate = row.get("gate")
        if not isinstance(gate, dict):
            continue
        blocker = _text(gate.get("blocked_by_ref"))
        child = _text(row["ref"])
        if blocker and blocker != child:
            edges.append(_edge(blocker, child, "blocks"))
    return edges


def derive_edges(manifest: dict[str, Any]) -> list[dict[str, Any]]:
    """Declared edges from one manifest: `stacked` along each lane and from each `after`, `apex` to
    the tracker, `blocks` from each `gate.blocked_by_ref`.

    Consecutive rows in a lane yield a `stacked` edge -- that is what a declared merge order *means*,
    and together with `after` it is the only construct here that can span repositories, since each row
    names its own full ref. A row that declares its own parents through `after` takes those INSTEAD
    of the lane's inference, not in addition to them; see _stacked_edges.

    DEDUPLICATED on `(kind, parent, child)`, which the port did not need and this version does:
    `after` can restate an adjacency the lane already implies (and the `blocks` channel can restate
    an `after`), and a duplicated ordering edge would count TWICE in any indegree computation.

    ONLY THE TERMINAL SORT KEY IS OBSERVABLE, and an earlier version of this paragraph claimed both
    were. The dedup key is a set-membership key: two edges collide iff all three fields are equal, so
    permuting its components preserves the equivalence classes exactly and cannot change what is kept
    or emitted -- measured, on a fixture whose parent order and child order deliberately disagree.
    The SORT key `(kind, child, parent)` IS wire-visible, and a parent-major sort reorders rows for
    every consumer that renders or diffs them. So "unifying the two keys" is a no-op if the dedup key
    is the one moved and a behaviour change if the sort key is; only the latter needs guarding, and
    test_edges_are_sorted_by_kind_then_child_then_parent is what guards it.
    """
    by_lane = lanes(manifest)
    rows = [row for lane_rows in by_lane.values() for row in lane_rows]
    after_edges = _after_edges(rows)
    declared_children = {edge["child"] for edge in after_edges}
    edges = _stacked_edges(by_lane, declared_children) + after_edges + _apex_edges(manifest, rows) + _blocks_edges(rows)
    unique: dict[tuple[str, str, str], dict[str, Any]] = {}
    for edge in edges:
        unique.setdefault((edge["kind"], edge["parent"], edge["child"]), edge)
    return sorted(unique.values(), key=lambda e: (e["kind"], e["child"], e["parent"]))


def gates(manifest: dict[str, Any]) -> list[dict[str, str]]:
    """EVERY row's gate, sorted by ref. The total source for AC4's yours-vs-mine routing.

    Five keys per gate: `ref`, `kind`, `blocked_by`, `blocked_by_ref`, `resolved_by`. `kind` is what
    routes -- a `decision` blocks a PERSON, a `verification` blocks nobody in particular because
    anyone can run it -- and that routing has to see every gate, including the ones that DO carry a
    `blocked_by_ref`. unmapped_gates deliberately excludes those (they are already expressible as
    edges), so reaching for it as a routing source silently drops exactly the decisions that were
    careful enough to name their blocker. The plan's own named risk is a mis-set gate routing a
    human decision to an agent; reading the wrong function gets there with nothing mis-set at all.

    Reads through _rows() (tolerant) while validate reads the raw list (strict). The asymmetry is the
    design: reporting must never crash on data validation has already condemned.
    """
    out = []
    for row in _rows(manifest):
        gate = row.get("gate")
        if not isinstance(gate, dict):
            continue
        out.append(
            {
                "ref": _text(row.get("ref")),
                "kind": _text(gate.get("kind")),
                "blocked_by": _text(gate.get("blocked_by")),
                "blocked_by_ref": _text(gate.get("blocked_by_ref")),
                "resolved_by": _text(gate.get("resolved_by")),
            }
        )
    return sorted(out, key=lambda g: g["ref"])


def unmapped_gates(manifest: dict[str, Any]) -> list[dict[str, str]]:
    """The SUBSET of gates() that states a blocker in prose with no ref to point at.

    These are reported, never guessed at. "Waiting on Kelly's review" names a real blocker with no ref
    to point at; string-matching it into an edge would invent a dependency. Surfacing the count keeps
    them visible instead of silently absent from the graph. Both live manifests are 100% prose gates,
    so this is the production path, not an edge case.

    A gate carrying a `blocked_by_ref` IS expressible as an edge -- _blocks_edges emits it -- so
    counting it here too would report a mapped gate as unmapped and inflate a user-visible number.
    That exclusion is what makes this a subset and NOT a routing source; use gates() for that.

    Carries four keys, not gates()' five: `blocked_by_ref` is projected away because every member of
    this list has an empty one, and a key that is always "" is noise in a rendered report. Order is
    gates()' order, ascending ref.
    """
    return [
        {key: value for key, value in gate.items() if key != "blocked_by_ref"}
        for gate in gates(manifest)
        if gate["blocked_by"] and not gate["blocked_by_ref"]
    ]


def row_refs(manifest: dict[str, Any]) -> list[str]:
    """The refs of this manifest's ROWS, deduplicated and sorted. What select_for_repository scopes on.

    Deliberately narrower than declared_refs, and the narrowness is the point. A manifest's rows are
    the work; its apex is a tracker and its `blocked_by_ref`/`after` entries are pointers at work
    happening somewhere else. Scoping on the wider set puts another project's ENTIRE grid under this
    repository's header the moment this repository merely hosts its tracker issue or one cross-project
    blocker -- a wrong answer under a confident header, which is the exact failure class (the hardened
    spec's B3) this front door exists to remove. The spec binds the filter to `rows[].ref` for that
    reason.

    Same `_text` coercion and same exactness as declared_refs; see parse_ref for why nothing is
    normalized.
    """
    return sorted({ref for ref in (_text(row.get("ref")) for row in _rows(manifest)) if ref})


def declared_refs(manifest: dict[str, Any]) -> list[str]:
    """Every ref this manifest declares, deduplicated and sorted. The input to AC3's targeted fetch.

    Four sources: `rows[].ref`, each row's `gate.blocked_by_ref`, each entry of a row's `after`, and
    `apex.ref`. `after` is in the list even though it postdates the field's first enumeration, and it
    is arguably the most important entry: an `after` ref naming a row OUTSIDE this manifest is exactly
    what AC3's targeted fetch exists to resolve, and leaving it out would mean ready_set could never
    learn such a parent's state, so every forked row would be permanently not-ready.

    THE STRINGS ARE EXACT. No case fold, no `.git` handling, no rewriting of any kind -- see
    parse_ref for why any of those would produce refs matching no item. The ONE coercion applied is
    the module-wide `_text` (`str(x or "").strip()`), because that is the same coercion the edge
    builders apply: a declared ref and the edge endpoint derived from it MUST be the same string, or
    the fetch resolves one key while the graph indexes another. Blank values are dropped.

    SORTED, not declaration order, for the same reason derive_edges sorts: this is the input to a
    batched fetch whose result may be logged and diffed, and two runs over the same manifest with its
    rows reordered should produce byte-identical output.
    """
    refs: list[str] = []
    for row in _rows(manifest):
        refs.append(_text(row.get("ref")))
        gate = row.get("gate")
        if isinstance(gate, dict):
            refs.append(_text(gate.get("blocked_by_ref")))
        after = row.get("after")
        if isinstance(after, list):
            refs.extend(_text(entry) for entry in after if isinstance(entry, str))
    apex = manifest.get("apex")
    if isinstance(apex, dict):
        refs.append(_text(apex.get("ref")))
    return sorted({ref for ref in refs if ref})


def select_for_repository(manifests: list[dict[str, Any]], slug: str) -> list[dict[str, Any]]:
    """The manifests that declare at least one ref belonging to `slug` (an `owner/repo` pair).

    B6's selection half: discovery is global, selection is scoped. The module docstring's "WHERE
    MANIFESTS COME FROM" states why once; this is the narrowing half of it.

    IT SCOPES ON row_refs, NOT declared_refs -- rows only, per the hardened spec's B6. See row_refs
    for what hosting another project's tracker would otherwise do to this repository's grid.

    Matching is on the parsed `owner/repo` and never on a string prefix; ref_slug carries the
    `stillpoint-labs/stillpoint-web` argument for why.

    An empty `slug` selects NOTHING. A repository with no GitHub origin (shell.repository_slug returns
    "") must render an empty grid, not every manifest borg knows about. Returns the SAME dict objects,
    not copies -- discovery already returns the parsed manifests and a caller mutating one is editing
    discovery's return value.
    """
    if not slug:
        return []
    return [m for m in manifests if any(ref_slug(ref) == slug for ref in row_refs(m))]


def _unique_refs(refs: list[str]) -> list[str]:
    """Non-blank refs, coerced by _text, deduplicated, in first-appearance order."""
    seen: dict[str, None] = {}
    for ref in refs:
        value = _text(ref)
        if value:
            seen.setdefault(value, None)
    return list(seen)


def _ordering_pairs(nodes: set[str], edges: list[dict[str, Any]]) -> list[tuple[str, str]]:
    """`(parent, child)` for every ordering edge with BOTH endpoints inside `nodes`, deduplicated.

    Both-endpoints-inside is what stops an edge from inventing a node: a ref that appears only in
    `edges` is not a row anyone declared, and silently adding it would put a phantom in the grid.

    An edge with no `kind` contributes NOTHING. merge-tree/render_graph.py:244 defaults a missing kind
    to `stacked` at its gather boundary, but reproducing that default inside the ranking would let a
    malformed edge silently order the grid; every edge this package emits carries an explicit kind.
    """
    pairs: list[tuple[str, str]] = []
    seen: set[tuple[str, str]] = set()
    for edge in edges:
        if not isinstance(edge, dict) or _text(edge.get("kind")) not in ORDERING_EDGE_KINDS:
            continue
        pair = (_text(edge.get("parent")), _text(edge.get("child")))
        if pair[0] not in nodes or pair[1] not in nodes or pair[0] == pair[1] or pair in seen:
            continue
        seen.add(pair)
        pairs.append(pair)
    return pairs


def _rank_nodes(nodes: list[str], children: dict[str, list[str]], indegree: dict[str, int]) -> dict[str, int]:
    """Kahn sweep relaxing rank FORWARD -- longest path from any zero-indegree source.

    A CYCLE IS BROKEN, NOT DETECTED, and never raises. When the queue drains with nodes left, the
    smallest remaining ref is admitted outright and the sweep resumes; repeat until every node is
    placed. Three properties follow, and each is pinned by a test: the loop terminates (each node is
    processed at most once, so the work is bounded by V+E), no node is dropped (every node is admitted
    eventually), and the graph does not collapse to level 0 (the admitted node's descendants still
    relax forward). The back edge simply does not contribute, which is the only sane reading -- a
    cyclic declaration has no true ordering to report.

    Contrast merge-tree/render_graph.py:659-672, which computes the standard Kahn cycle counter
    (`proc`) and then NEVER READS IT: nodes on a cycle are never seeded and never enqueued, so they
    keep their initial rank of 0 and pile into column 0 mixed in with the genuine roots. Silently
    parking a cycle at the root is the behavior this deliberately does not inherit.

    For an acyclic graph the result is order-independent: a node is processed only once every parent
    is, so the queue order cannot change any rank.
    """
    rank = {node: 0 for node in nodes}
    done: set[str] = set()
    queue = sorted(node for node in nodes if indegree[node] == 0)

    # EVERY NODE IS POPPED EXACTLY ONCE, which is what bounds the loop and why there is no
    # already-seen guard here to go stale. A node is enqueued only when its indegree reaches zero,
    # which happens at most once (edges are deduplicated upstream, and each parent is popped once);
    # the forced admission below only ever picks a node that is neither done nor queued, because the
    # queue is empty when it runs; and a forced node keeps a positive indegree forever, since the
    # relaxation below skips children that are already done.
    while len(done) < len(nodes):
        if not queue:
            queue = [min(node for node in nodes if node not in done)]
        node = queue.pop(0)
        done.add(node)
        for child in children[node]:
            if child in done:
                continue
            rank[child] = max(rank[child], rank[node] + 1)
            indegree[child] -= 1
            if indegree[child] == 0:
                queue.append(child)
    return rank


def levels(refs: list[str], edges: list[dict[str, Any]]) -> list[list[str]]:
    """Rank every ref by longest-path depth. `levels(...)[i]` IS level `i`.

    RANK IS THE ROW INDEX, and that is DELIBERATELY the transpose of the JS `layout()` at
    merge-tree/render_graph.py:659-672, which assigns `x: rk*COL_W` and puts rank on the X axis. AC2
    requires time to flow DOWN, so rank is Y here and the returned list is read top to bottom.

    ONLY `stacked` and `blocks` contribute (ORDERING_EDGE_KINDS), mirroring render_graph.py:662.
    `apex` MUST NOT: an apex edge points from the tracker at EVERY row, so counting it would give
    every row an in-edge from one rank-0 node and flatten the whole stack into a single level 1 under
    the tracker.

    WITHIN-LEVEL ORDER IS ASCENDING REF, and that is a documented divergence: the JS sorts each rank
    by DESCENDING urgency and then ascending ref (render_graph.py:670). Urgency is per-item recon
    state, not manifest structure, and this function is pure over `(refs, edges)` -- taking a whole
    item table just to sort ties would drag live network state into the ranking. A caller that wants
    the urgency ordering can re-sort one level; it cannot un-do a nondeterministic one.

    Refs are deduplicated and blanks dropped; an empty input yields `[]`. Duplicate edges are
    collapsed before the indegree count, so a fork restating a lane adjacency cannot double-count.
    """
    nodes = _unique_refs(refs)
    if not nodes:
        return []

    children: dict[str, list[str]] = {node: [] for node in nodes}
    indegree: dict[str, int] = {node: 0 for node in nodes}
    for parent, child in _ordering_pairs(set(nodes), edges):
        children[parent].append(child)
        indegree[child] += 1

    rank = _rank_nodes(nodes, children, indegree)
    buckets: dict[int, list[str]] = {}
    for node in nodes:
        buckets.setdefault(rank[node], []).append(node)
    # No gaps are possible -- a node at rank k has a parent at rank k-1 -- but building by index keeps
    # the "index IS the level" contract true by construction rather than by argument.
    return [sorted(buckets.get(i, [])) for i in range(max(buckets) + 1)]


def _state_of(states: dict[str, Any], ref: str) -> str:
    """One ref's state token, or "" when nothing is known about it.

    Lowercased on read. The adapter already downcases at recon-adapter-github:179, so this only
    guards a caller that hands over the raw GraphQL enum; it introduces no token the adapter cannot
    emit. Keys are EXACT refs -- see parse_ref.
    """
    return _text(states.get(ref)).lower()


def ready_set(manifest: dict[str, Any], states: dict[str, Any]) -> list[str]:
    """AC4's READY set: rows that are open AND whose every parent has merged. Sorted, announced whole.

    `states` maps a ref to one of the github adapter's three tokens -- `open`, `closed`, `merged`
    (recon-adapter-github:179). Draft-ness is NOT a state there: a draft PR is `open`, and a caller
    that wants to exclude drafts must do so on its own signal rather than expecting a fourth token.

    A ref with NO known state is NOT ready, and is NOT a merged parent. Unknown is not merged --
    treating it as merged would announce work as startable on the strength of never having looked.
    That is precisely why declared_refs exists: AC3 fetches every declared ref that fell outside the
    sweep window, so "unknown" should be rare rather than routine.

    PARENTS COME FROM THE ORDERING EDGES, so `after` parents count identically to lane predecessors
    (_after_edges emits `stacked`) and `gate.blocked_by_ref` counts too -- a declared blocker is a
    parent in every sense that matters here.

    A PARENT OUTSIDE THIS MANIFEST is still a parent. `after` and `blocked_by_ref` may both name refs
    no row declares, and those are valid input, not errors. Such a parent is looked up in `states`
    exactly like any other: known-merged unblocks the row, anything else (including absent) does not.

    A REFERENCE PARENT IS SKIPPED, AND THIS IS THE ONLY PLACE THE TRACKED/REFERENCE SPLIT HAS TEETH.
    A `link` row (a Notion page, a Google Doc, an uploaded asset) has no resolvable state, so
    `_state_of` returns unknown for it forever and the `all(... == STATE_MERGED)` test below would be
    permanently False -- meaning a chain that puts its own spec document in a lane would report
    NOTHING ready, for as long as the document exists. Measured before this line was added: a
    three-row chain with a Notion link at order 1 returned `[]`; removing the link row returned the
    PR. The predicate is `refs.is_reference`, NOT `not is_tracked`: the latter is also true of a ref
    of no known kind, and a malformed `after: ["#149"]` must keep wedging its row rather than quietly
    unblocking it -- that is this function's own "unknown is not merged" rule, and skipping unknowns
    would invert it. Adding a source is a change in refs.py alone.

    THE ROW ITSELF NEEDS NO GUARD. An untracked ref has no state, so the `!= STATE_OPEN` test above
    already excludes it from being announced as ready -- a document is not work you can pick up.
    """
    parents: dict[str, list[str]] = {}
    for edge in derive_edges(manifest):
        if edge["kind"] in ORDERING_EDGE_KINDS and not _refs.is_reference(edge["parent"]):
            parents.setdefault(edge["child"], []).append(edge["parent"])

    ready = []
    for lane_rows in lanes(manifest).values():
        for row in lane_rows:
            ref = _text(row["ref"])
            if _state_of(states, ref) != STATE_OPEN:
                continue
            if all(_state_of(states, parent) == STATE_MERGED for parent in parents.get(ref, [])):
                ready.append(ref)
    return sorted(ready)
