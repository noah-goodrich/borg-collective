"""The pure CROSS-manifest layer: every function here takes a LIST of manifests, never a single one.

This module is UNCONDITIONALLY free of raw I/O, on exactly core.py's terms: no subprocess, no file
open(), no network, no environment reads, no clock reads. It imports `typing` and two sibling
modules, `borg_core.manifest.core` and `borg_core.manifest.refs`, and nothing else.
borg_core/manifest/test_across.py asserts that by walking this file's AST rather than by trusting
`make lint`, because the clean-architecture linter's allow-list already permits `pathlib`, `json`
and `datetime` -- so it is the COARSER of the two gates, and a `Path(x).read_text()` in here keeps
the lint green at 10.00/10 while the AST walk goes red (measured both ways). The name still has to
appear in pyproject.toml's clean-arch Domain map even so: that check classifies by BASENAME and
RETURNS EARLY on a file it cannot classify, so an omission there is silent rather than loud. Both
facts hold at once, which is why there are two gates and neither replaces the other; the paragraphs
in pyproject.toml about picture.py and render.py carry the full argument.

WHY THIS IS NOT IN core.py -- DECIDED, NOT DRIFTED INTO. The session checkpoint that scheduled this
work said "port into borg_core/manifest/core.py". That is mechanically impossible without weakening
a gate: core.py is 976 lines and pylint's default `max-module-lines` is 1000 with no override in
pyproject.toml, so there are 24 lines of headroom, and the two functions below are more than FIVE
TIMES that at this tree's docstring density -- 131 lines by an AST walk over this file's top-level
FunctionDefs (46 and 85), which lands core.py at 1107 before the blank separators an appended copy
needs. THE MARGIN IS SHRINKING, WHICH MAKES THE CONCLUSION MORE ROBUST, NOT LESS: it was 57 when
this paragraph was written, 50 after a resync, and 24 once `next_order_in_lane` landed in core.py
to give the lane ordering one owner. Every edit that makes core.py the right home for something
else makes it a worse home for these two.

HEADROOM is the durable half of that arithmetic and the 131 is not: it measures the two
functions below, so any docstring they gain moves it, and it has now moved THREE times -- an earlier
draft claimed ~95, the two-oracles paragraph added to edges_from took the total from 115 to 127, and
by 2026-09-03 every digit here was stale (943/57/127/42/1070) because commit 3bb1418 -- itself
titled "correct four claims that did not match the tree" -- added lines to core.py and to
edges_from's docstring without re-running the arithmetic. Every number in this paragraph is now
AST-measured rather than remembered. Re-measure with an AST walk over this file's top-level
FunctionDefs before repeating the digit, or read only the conclusion, which no plausible edit
reverses: stripping the prose WOULD fit, since the two bodies are ~14 lines of actual code, and
prose at this density is exactly what this
tree asks for -- which is why the answer here is a split and not a C0302 disable. The tree holds both
precedents and they point opposite ways -- borg_core/link/render.py carries a
`# pylint: disable=too-many-lines`, while core.py's OWN module docstring records refs.py being SPLIT
OUT of it "when this module crossed C0302's ceiling", together with the general rule written beside
that split: a suppression with an expiry condition next to it is the only kind that ever gets
removed, an unconditional one is permanent by default. For a module whose seam is already visible,
the documented precedent is split, not disable.

THE SEAM IS REAL, AND IT IS INCOMPLETE ON PURPOSE. Every function in core.py takes ONE manifest;
every function here takes a set of them. `core.select_for_repository` is the one exception -- it also
takes a list, and it stays in core.py for now, because moving it is a CONTRACT-phase change with live
callers while this commit is an expand phase. So "one manifest lives in core, many live in across" is
true of everything except that one name. The next reader should FINISH the move rather than conclude
the seam was arbitrary and start filing single-manifest functions here.

PORTS, NOT IMPORTS. `edges_from` is merge-tree/programs.py's function of the same name;
`contested_refs` is the contested-ref half of merge-tree/gather.py's `apply_program_projects`, split
away from the item re-keying that stays over there. Ported rather than imported, and that is forced
twice over exactly as core.py records: `merge-tree` carries a hyphen so it can never be a Python
package name, and pyproject.toml pins `allowed_prefixes = ["borg_core", "__future__"]`, so an import
would fail `make lint` even if the path resolved.

BOTH merge-tree COPIES STAY LIVE AND UNTOUCHED. This is AC7's EXPAND phase: the new form ships and no
caller is repointed. Repointing merge-tree/gather.py and merge-tree/coordinator.py is the CONTRACT
phase, and it may not happen until the shorthand refs in merge-tree/test_coordinator.py have been
migrated to satisfy this side's stricter ref vocabulary. Until then two implementations coexist by
design, and they are not identical: `contested_refs` carries three deliberate divergences from the
copy it ports, each documented on the function with the failure it exists to prevent.
"""

from __future__ import annotations

from typing import Any

from borg_core.manifest import core, refs


def edges_from(manifests: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """All declared edges across every manifest, deduplicated and byte-stable.

    THREE LINES OF CODE UNDER A LONG DOCSTRING, and that ratio is the honest one: `core.derive_edges`
    already deduplicates and sorts WITHIN one manifest, so the only new work here is the
    cross-manifest union. What needs writing down is not the loop, it is why the union is permitted
    to collapse anything at all.

    TWO MANIFESTS NAMING THE SAME DEPENDENCY IS NORMAL, NOT AN ERROR. A cross-repository chain lives
    under exactly one repository, so a second project that depends on one of its rows declares that
    same ordering from its own side -- which is what declaring means, and neither declaration is
    wrong. Identical edges therefore COLLAPSE rather than being reported: a duplicated ordering edge
    counts TWICE in any indegree computation, which ranks its child one level too deep and drops it
    out of the ready set. A contested *ref* is the opposite case -- reported, never resolved -- and
    the asymmetry is deliberate; see contested_refs.

    THE TWO KEYS DIFFER, AND ONLY THE SORT ONE IS OBSERVABLE. `(kind, parent, child)` collapses and
    `(kind, child, parent)` sorts, transcribing core.derive_edges. But the collapse key is a
    set-membership key -- two edges collide iff all three fields are equal -- so permuting ITS
    components preserves the equivalence classes exactly and changes nothing, measured on a fixture
    whose parent order and child order deliberately disagree. The SORT key is wire-visible to every
    consumer that renders or diffs these rows, and it is the one a "tidy-up" must not touch. Stated
    this way because an earlier version of this paragraph credited both, which points a maintainer at
    the wrong line to preserve.

    TRANSCRIBED, NOT EXTRACTED INTO A SHARED HELPER, SO BOTH COPIES CARRY THEIR OWN ORACLE.
    test_edges_are_sorted_by_kind_then_child_then_parent exists under that one name TWICE -- in
    test_across.py for this function and in test_core.py for core.derive_edges -- each with a
    hand-authored expected list and a "not parent-major" discriminator. Neither can stand in for the
    other, and that is measured rather than assumed: because this function RE-SORTS the union, a flip
    of derive_edges' terminal key leaves every assertion about edges_from green, and a flip of the key
    below leaves every assertion about derive_edges green. Each mutation fails exactly its own
    namesake and nothing else in borg_core. Delete either test and one copy of the rule is pinned by
    nothing. Collapsing them into one `core` helper is the right CONTRACT-phase move and is declined
    here for the reason at the top of this module: it restructures derive_edges, a live path, in a
    commit whose rule is that no existing path changes.

    `edges_from([]) == []`. An empty registry, a sweep that discovered no manifests, and a repository
    with no `.borg/programs/` directory all arrive here as the empty list, and none of them is an
    error.
    """
    seen: dict[tuple[str, str, str], dict[str, Any]] = {}
    for manifest in manifests:
        for edge in core.derive_edges(manifest):
            seen.setdefault((edge["kind"], edge["parent"], edge["child"]), edge)
    return sorted(seen.values(), key=lambda e: (e["kind"], e["child"], e["parent"]))


def contested_refs(manifests: list[dict[str, Any]]) -> list[str]:
    """Refs that more than one manifest claims as its OWN work: one sorted line per collision.

    Every line reads exactly `"<ref>: kept by <first-claimant>, also claimed by <later-claimant>"`.
    That shape is a PORT and is pinned on both sides -- merge-tree/test_gather.py asserts the
    identical form, and AC6's eval harness calls each entry a "contested line" -- so it is a wire
    format to preserve, not prose to improve.

    THE FIRST CLAIMANT KEEPS THE REF AND THE COLLISION IS REPORTED, NEVER SILENTLY RESOLVED. Two
    manifests claiming one row is a declaration conflict only a human can settle; picking a winner
    quietly would let the loser's chain lose a member with nothing on screen to say so.

    IDENTITY IS THE ARGUMENT INDEX; `_id` IS ONLY THE PRINTED LABEL. This separation is the second
    residual instance of the defect class in (a) below, and it was found in this very function: `_id`
    falls back to the FILENAME STEM in shell._load_manifest, which is precisely the state AC7 drives
    the tree toward, so two DIFFERENT manifests in two different repositories both called
    `rollout.json` both label themselves `rollout`. Keying the holder map on the label made the
    holder comparison find them EQUAL, so a genuine contest over one row returned `[]` -- the first
    claimant kept the ref, the second lost it, and nothing reached the screen. Green because two
    claimants merged into one, exactly the outcome the paragraph above says is impossible. Keying on
    `enumerate`'s index instead makes identity guaranteed-distinct per element, so no pair of
    arguments can ever collapse.

    THAT IS SAFE BECAUSE THE DEDUP LIVES UPSTREAM, IN shell.discover. Index identity means a manifest
    supplied twice would accuse itself, and the reason it cannot arrive twice is that `discover`
    collapses body-identical manifests on `_manifest_identity` (a serialised `core.declared_body`)
    before any caller sees a list -- its docstring names the git-worktree case as the reason, since
    `.borg/programs/` is git-tracked and `drone feature` produces a second checkout of every manifest
    that `borg add` then registers beside its parent. A caller that hand-assembles a list without
    going through discovery is asking a question about the list it passed, and gets an answer about
    that list. Do not re-add a label-equality guard here to compensate: that is what hid the
    two-`rollout.json` contest, and it would hide it again.

    THREE DELIBERATE DIVERGENCES FROM THE SOURCE, each one a failure class rather than a preference.

    (a) NOTHING IS READ FROM A TOP-LEVEL `program` KEY -- not the identity, not the label -- and this
        is the entire reason the port exists. merge-tree's version reads `manifest["program"]` and
        `continue`s past any manifest without one. borg_core's loader (shell._load_manifest) stamps
        `_id` and is pinned never to invent `program` -- test_shell.py's
        test_discover_reads_a_declared_id_but_synthesizes_no_program_key asserts
        `"program" not in without_key` -- so once AC7 finishes retiring the word, merge-tree's
        version can no longer fail at all: measured, stripping the key yields `contested []` even
        with a real collision injected. Green because the code stopped running. That is the defect
        class this function is built to be immune to.

    (b) IT NEVER SKIPS A MANIFEST, AND NOW IT CANNOT EVEN MERGE TWO. The positional string
        `manifest[<index>]` is the LABEL's fallback, reached when `_id` is absent or blank; it is no
        longer load-bearing for identity, because identity is the index whether or not a label
        exists. That makes the never-skip rule strictly stronger than it was: skipping would
        reproduce (a) under a different key name, and under the old spelling an identity COLLISION
        reproduced it too, silently, without any key having to move. Neither failure is reachable
        now -- a manifest with no readable identity key still claims its rows, and two manifests can
        share every printed character without sharing a claim. A positional label is less useful to
        a reader than a slug, but it is still TRUE and still VISIBLE, and in production `_id` is
        always stamped, so seeing one is a TRIPWIRE: a caller assembled manifests without going
        through the loader.

    (c) IT KEYS ON `core.row_refs`, NOT on rows-plus-apex the way the source does, because a contest
        is over WORK OWNERSHIP. core.row_refs' own docstring carries the argument: a manifest's rows
        are the work, while its apex is a tracker and its `after`/`gate.blocked_by_ref` entries are
        pointers at work happening somewhere else. Two projects sharing one tracker issue is not a
        contest, and two projects where one `after`-points at the other's row is the NORMAL
        cross-project case that manifests exist to express -- reporting either as contested turns the
        signal into noise, and a report nobody believes is worse than no report. merge-tree's copy
        includes the apex because it uses the same map to REGROUP items onto a project, which is a
        different job and stays over there.

    ALGORITHM. Walk manifests in argument order -- first claimant wins, so the order the caller
    supplies is observable in the output and discovery order is the tiebreak. For each, walk
    `core.row_refs(m)`, which is already sorted and deduplicated, so the result is deterministic
    regardless of row order within a file. `setdefault` the ref to `(index, label)` and append a line
    whenever the stored INDEX differs from this one; the stored label rides along so the holder's
    printed name needs no second pass over the arguments to recover. A manifest cannot contest
    ITSELF: row_refs is deduplicated, and core.validate already rejects a duplicate ref inside one
    manifest, so a repeated ref is two facts about one claim rather than two claims.
    """
    holder_of: dict[str, tuple[int, str]] = {}
    contested: list[str] = []
    for index, manifest in enumerate(manifests):
        label = refs.text(manifest.get("_id")) or f"manifest[{index}]"
        for ref in core.row_refs(manifest):
            holder_index, holder_label = holder_of.setdefault(ref, (index, label))
            if holder_index != index:
                contested.append(f"{ref}: kept by {holder_label}, also claimed by {label}")
    return sorted(contested)
