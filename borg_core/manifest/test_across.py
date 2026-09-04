"""Unit tests for borg_core.manifest.across (the pure CROSS-manifest layer).

Calling convention: in-process only, plain data in and plain data out. No filesystem, no fixture
files on disk, no `tmp_path` -- every manifest here is a dict built by `_manifest()` below. The
on-disk case is deliberately somewhere else: E2a, the offline two-repository acceptance case, belongs
to test_shell.py, next to the real `tmp_path` git repositories and the loader that stamps `_id`.
Splitting it that way is what keeps this file from inheriting the REPO_ROOT path-depth trap
merge-tree/test_s4_manifests.py documents, where a moved file silently discovers zero manifests and
the failure reads as "the feature is missing" rather than "the test moved".

TWO LOAD-BEARING TESTS HERE, both regression tests for a report that was EMPTY while green, which is
the failure no assertion about a report's CONTENTS can tell apart from "there was no collision".
test_a_collision_is_still_reported_when_no_manifest_carries_a_program_key covers the skip: merge-tree's
copy of this logic passes over any manifest without a top-level `program` key, so once AC7 retires the
word its contested report goes permanently empty -- measured, `contested []` with a real collision
injected. test_two_different_manifests_both_stemmed_rollout_still_contest_over_a_shared_row covers the
residual instance found inside this module's own first draft: `_id` falls back to the filename stem, so
keying the holder map on `_id` merged two different `rollout.json` files into ONE claimant and returned
`[]`. Every other assertion in this file is about shape; those two are about whether the code runs at
all, and they are why identity is now the argument index and `_id` only the printed label.

Every positive case is paired with a negative case proving the condition discriminates.
"""

from __future__ import annotations

import ast
from pathlib import Path

from borg_core.manifest import across


def _manifest(rows, apex=None, **top):
    """One manifest, rebuilt fresh per call so no test can mutate another's input.

    `**top` carries the identity keys under test -- `_id` (what production stamps) and `program` (the
    retired word) -- as TOP-LEVEL keys rather than helper parameters, because which of the two is
    present is the whole subject of the tripwire cases and a defaulted parameter would quietly supply
    one of them.
    """
    manifest: dict = {"rows": rows}
    if apex is not None:
        manifest["apex"] = apex
    manifest.update(top)
    return manifest


def _row(order, ref, lane=None, **extra):
    row = {"order": order, "ref": ref, **extra}
    if lane is not None:
        row["lane"] = lane
    return row


def _stacked(parent, child):
    return {"parent": parent, "child": child, "kind": "stacked", "source": "declared"}


def _apex_edge(parent, child):
    return {"parent": parent, "child": child, "kind": "apex", "source": "declared"}


def _pair(parent, child):
    """Two rows in one default lane, which is the smallest shape that yields exactly one edge."""
    return [_row("1", parent), _row("2", child)]


# ── edges_from: the cross-manifest union ─────────────────────────────────────


def test_two_manifests_yield_the_union_and_the_count_is_the_sum_when_nothing_overlaps():
    first = _manifest(_pair("z/z#1", "a/a#2"))
    second = _manifest(_pair("a/a#3", "b/b#4"))
    assert len(across.edges_from([first])) == 1
    assert len(across.edges_from([second])) == 1
    union = across.edges_from([first, second])
    assert len(union) == 2, "disjoint declarations must not collapse into each other"
    assert {(e["parent"], e["child"]) for e in union} == {("z/z#1", "a/a#2"), ("a/a#3", "b/b#4")}


def test_an_edge_declared_identically_by_two_manifests_collapses_to_one():
    """Two projects naming the same dependency is normal input, so the duplicate is dropped rather
    than reported. MUTATION: `seen[key] = edge` instead of `setdefault` -- still one edge, so the
    second half of this test is what makes the first half mean anything.

    A duplicated ordering edge counts twice in any indegree computation, which ranks its child a
    level too deep and drops it out of the ready set.
    """
    manifest = _manifest(_pair("z/z#1", "a/a#2"))
    assert across.edges_from([manifest, dict(manifest)]) == across.edges_from([manifest])
    # Discriminator: collapsing is not "return the first manifest's edges". A genuinely different
    # second declaration still grows the list.
    other = _manifest(_pair("a/a#3", "b/b#4"))
    assert len(across.edges_from([manifest, other])) == 2


def test_no_manifests_and_no_rows_both_yield_no_edges():
    assert across.edges_from([]) == []
    assert across.edges_from([_manifest([])]) == []
    # Discriminator: the function is not simply always empty.
    assert across.edges_from([_manifest(_pair("z/z#1", "a/a#2"))]) != []


def test_the_union_is_independent_of_manifest_order_and_of_row_order():
    """Byte-stability is the property a logged or diffed sweep depends on, and there are two ways to
    lose it: the order the caller supplies the manifests, and the order the rows sit in a file.

    The negative at the bottom is what stops this from being vacuous. Argument order IS observable in
    this module -- contested_refs' first claimant depends on it -- so invariance here is a fact about
    edges_from, not an artifact of the fixtures being symmetrical.
    """
    first = _manifest(_pair("z/z#1", "a/a#2"), apex={"ref": "y/y#9"})
    second = _manifest(_pair("a/a#3", "b/b#4"))
    assert across.edges_from([first, second]) == across.edges_from([second, first])

    reordered = _manifest(list(reversed(first["rows"])), apex={"ref": "y/y#9"})
    assert across.edges_from([reordered]) == across.edges_from([first])

    claimants = [_manifest([_row("1", "o/r#1")], _id="first"), _manifest([_row("1", "o/r#1")], _id="second")]
    assert across.contested_refs(claimants) != across.contested_refs(list(reversed(claimants)))


def test_edges_are_sorted_by_kind_then_child_then_parent():
    """Hand-authored expected list, NOT a re-computation of the implementation -- an oracle that
    sorts the same way the code does cannot catch the code sorting wrongly.

    The fixture is chosen so the two candidate sort keys disagree: by `(kind, child, parent)` the
    stacked edges come out `a/a#2` then `b/b#4`, whose PARENTS (`z/z#1`, `a/a#3`) are in descending
    order -- so a `(kind, parent, child)` sort would swap the last two rows.
    """
    first = _manifest(_pair("z/z#1", "a/a#2"), apex={"ref": "y/y#9"})
    second = _manifest(_pair("a/a#3", "b/b#4"))
    got = across.edges_from([first, second])
    assert got == [
        _apex_edge("y/y#9", "a/a#2"),
        _apex_edge("y/y#9", "z/z#1"),
        _stacked("z/z#1", "a/a#2"),
        _stacked("a/a#3", "b/b#4"),
    ]
    assert [e["parent"] for e in got if e["kind"] == "stacked"] == ["z/z#1", "a/a#3"], "not parent-major"


# ── contested_refs: who claims a row ─────────────────────────────────────────


def test_two_manifests_claiming_one_row_ref_produce_exactly_one_contested_line():
    claimants = [
        _manifest([_row("1", "o/r#1"), _row("2", "o/r#2")], _id="ingest"),
        _manifest([_row("1", "o/r#1"), _row("2", "o/r#3")], _id="warehouse"),
    ]
    assert across.contested_refs(claimants) == ["o/r#1: kept by ingest, also claimed by warehouse"]
    # Discriminator: it is the SHARED ref that produces the line, not the mere presence of two
    # manifests. Give them disjoint rows and the report is empty.
    disjoint = [
        _manifest([_row("1", "o/r#9")], _id="ingest"),
        _manifest([_row("1", "o/r#8")], _id="warehouse"),
    ]
    assert across.contested_refs(disjoint) == []


def test_a_third_claimant_still_names_the_first_as_keeper():
    """The keeper is the FIRST claimant, not the previous one -- otherwise a chain of three would
    report `b` as keeping a ref that `a` holds, and resolving the conflict by deleting `a`'s row
    would leave a report nobody could act on.
    """
    claimants = [_manifest([_row("1", "o/r#1")], _id=name) for name in ("a", "b", "c")]
    assert across.contested_refs(claimants) == [
        "o/r#1: kept by a, also claimed by b",
        "o/r#1: kept by a, also claimed by c",
    ]


def test_contested_lines_print_in_ref_order_even_when_they_are_found_in_the_reverse():
    """The terminal `sorted` is live, ported, observable behaviour, and until this case it had NO
    oracle: every other fixture in this file happens to emit its lines already in ascending order --
    a single collision, or (as directly above) several claimants over ONE ref with ascending labels --
    so deleting the sort changed no expectation anywhere.

    This is the smallest shape where insertion order and sorted order DISAGREE. `ingest` claims both
    refs; the second manifest then contests only the LATER ref and the third only the EARLIER one, so
    the lines are found high-then-low and must print low-then-high. Two claimants cannot do it: one
    collision is one line, and one line is sorted by construction.

    Hand-authored expected list, in order, for the same reason
    test_edges_are_sorted_by_kind_then_child_then_parent has one -- an oracle that re-derives the sort
    cannot catch the sort being wrong.

    MUTATION: `return contested` in place of `return sorted(contested)`. Measured -- this case goes
    red and every other case in the file stays green, which is exactly what "the sort had no oracle"
    meant.

    What the ordering is worth on the wire: these lines are what a human reads to settle a declaration
    conflict, and AC6's eval harness counts them. Ordered by discovery instead, the report reshuffles
    itself whenever the registry hands the manifests over in a different order, so a diff of two
    sweeps shows churn where no declaration changed.
    """
    claimants = [
        _manifest([_row("1", "o/r#1"), _row("2", "o/r#2")], _id="ingest"),
        _manifest([_row("1", "o/r#2")], _id="warehouse"),
        _manifest([_row("1", "o/r#1")], _id="pipelines"),
    ]
    got = across.contested_refs(claimants)
    assert got == [
        "o/r#1: kept by ingest, also claimed by pipelines",
        "o/r#2: kept by ingest, also claimed by warehouse",
    ]
    # Discriminator, and the proof the fixture is not already sorted by construction: the line printed
    # FIRST is the one produced LAST, by the last manifest in argument order. If that ever stops
    # holding, this case has decayed back into the vacuous shape it was written to replace.
    assert got[0].endswith(f"also claimed by {claimants[-1]['_id']}"), "printed first, found last"


def test_one_manifest_cannot_contest_itself_but_two_sharing_a_label_do():
    """The self-contest property, stated at the ONE level where it is true of this function: a single
    manifest with a repeated ref. `core.row_refs` deduplicates and core.validate rejects a duplicate
    ref inside one manifest, so a repeated ref is two facts about one claim rather than two claims.

    TWO MANIFESTS SHARING A LABEL ARE A DIFFERENT CASE AND THEY CONTEST. They are two claimants
    because identity is the argument index, not the label, and the emitted line therefore names
    `ingest` TWICE. That reads oddly and is meant to: it is the only honest rendering of two files
    that disagree while calling themselves the same thing, which is exactly what two repositories
    each holding a `rollout.json` produce once `_id` falls back to the filename stem.

    WHERE THE OLD ASSERTION WENT. This case used to claim two same-label manifests were ONE claimant,
    on the reasoning that it stopped a single manifest reached through two registry paths from
    accusing itself. That property is real but it is not this function's: shell.discover collapses
    body-identical manifests on `_manifest_identity` before any caller sees a list, and test_shell.py
    owns the assertion because proving it needs two real repository directories on disk. A caller
    that hand-assembles a list without going through discovery is asking about the list it passed.
    """
    assert across.contested_refs([_manifest([_row("1", "o/r#1"), _row("2", "o/r#1")], _id="ingest")]) == []
    twin = [_manifest([_row("1", "o/r#1")], _id="ingest"), _manifest([_row("1", "o/r#1")], _id="ingest")]
    assert across.contested_refs(twin) == ["o/r#1: kept by ingest, also claimed by ingest"]
    # Discriminator: it is still the shared REF that produces the line, never the shared label. Same
    # `_id` on both, disjoint rows, and the report is empty -- so the line above is evidence of a
    # collision rather than of the label matching itself.
    same_label = [_manifest([_row("1", "o/r#1")], _id="ingest"), _manifest([_row("1", "o/r#2")], _id="ingest")]
    assert across.contested_refs(same_label) == []
    # Discriminator: identical rows under DIFFERENT identities are a real contest.
    assert len(across.contested_refs([_manifest([_row("1", "o/r#1")], _id=n) for n in ("ingest", "other")])) == 1


# ── the tripwires: `_id` labels a claimant, the index identifies one ─────────


def _contested_by_program_key(manifests):
    """merge-tree/gather.py's rule, transcribed just far enough to demonstrate its skip.

    This is the oracle for the defect, not a helper anyone should reuse: it reads `manifest["program"]`
    and `continue`s past a manifest without one, exactly as the live copy does. Transcribed rather
    than imported because `merge-tree` carries a hyphen and can never be a Python package name.
    """
    by_ref: dict[str, str] = {}
    lines: list[str] = []
    for manifest in manifests:
        program = str(manifest.get("program") or "").strip()
        if not program:
            continue
        for row in manifest["rows"]:
            ref = str(row.get("ref") or "").strip()
            holder = by_ref.setdefault(ref, program)
            if holder != program:
                lines.append(f"{ref}: kept by {holder}, also claimed by {program}")
    return sorted(lines)


def test_a_collision_is_still_reported_when_no_manifest_carries_a_program_key():
    """WHY THIS EXISTS: it is the regression test for a defect that was GREEN.

    AC7 retires the top-level `program` key, and borg_core's loader is pinned never to invent one
    (test_shell.py's test_discover_reads_a_declared_id_but_synthesizes_no_program_key). merge-tree's
    version keys on that word and skips every manifest lacking it, so on an AC7 tree it reports
    `contested []` with a real collision injected -- green because the code stopped running, which no
    assertion about the report's CONTENTS can distinguish from "there was no collision".

    The three assertions below are that distinction: this function reports, the retired rule is blind
    to the identical input, and the retired rule is not merely broken -- it reports the moment the
    word is put back. That last one is what makes the middle assertion evidence of a SKIP rather than
    of a typo in the oracle.
    """
    id_only = [
        _manifest([_row("1", "o/r#1")], _id="ingest"),
        _manifest([_row("1", "o/r#1")], _id="warehouse"),
    ]
    assert not any("program" in m for m in id_only), "the state AC7 leaves the tree in"
    assert across.contested_refs(id_only) == ["o/r#1: kept by ingest, also claimed by warehouse"]
    assert _contested_by_program_key(id_only) == [], "the retired rule goes silent, not wrong"

    with_word = [dict(m, program=m["_id"]) for m in id_only]
    assert _contested_by_program_key(with_word) == ["o/r#1: kept by ingest, also claimed by warehouse"]


def test_two_different_manifests_both_stemmed_rollout_still_contest_over_a_shared_row():
    """WHY THIS EXISTS: it is the regression test for a defect that returned `[]` -- the second, and
    residual, instance of the class the test above covers.

    shell._load_manifest falls back `_id` to the FILENAME STEM, which is the state AC7 drives the
    tree toward, so two repositories each holding a `rollout.json` produce two manifests whose `_id`
    is `rollout` and whose bodies are entirely different. Keying the holder map on `_id` made the
    holder comparison find those two claimants EQUAL: the first kept `acme/platform#400`, the second
    silently lost it, and `contested_refs` returned `[]` on a genuine conflict. Green because two
    claimants merged into one -- which, like the `program`-key skip, no assertion about the report's
    CONTENTS can distinguish from "there was no collision".

    Identity is now the argument index, so the fix is unconditional rather than a wider label: two
    elements of one list can never be one claimant no matter what they call themselves.
    """
    rollouts = [
        _manifest([_row("1", "acme/platform#400"), _row("2", "acme/platform#401")], _id="rollout"),
        _manifest([_row("1", "acme/platform#400"), _row("2", "acme/warehouse#900")], _id="rollout"),
    ]
    # The premise: DIFFERENT bodies, so shell.discover's content dedup cannot have collapsed these --
    # they reach a caller as two manifests, and only the shared label made them look like one.
    assert rollouts[0]["rows"] != rollouts[1]["rows"]
    assert across.contested_refs(rollouts) == ["acme/platform#400: kept by rollout, also claimed by rollout"]
    # Discriminator: exactly ONE line out of two rows each, so the report is about the shared ref and
    # not about the shared stem. Remove the overlap, keep the stem, and it goes silent.
    no_overlap = [
        _manifest([_row("1", "acme/platform#401")], _id="rollout"),
        _manifest([_row("1", "acme/warehouse#900")], _id="rollout"),
    ]
    assert across.contested_refs(no_overlap) == []


def test_the_label_is_read_from_id_even_when_a_stale_program_key_disagrees():
    """Production keeps the two in step -- `_id` reads a declared `program` verbatim and falls back to
    the filename stem -- so this fixture is deliberately impossible on disk. It is the only way to
    assert WHICH key supplies the printed label rather than that some key does.
    """
    claimants = [
        _manifest([_row("1", "o/r#1")], _id="ingest", program="stale-ingest"),
        _manifest([_row("1", "o/r#1")], _id="warehouse", program="stale-warehouse"),
    ]
    assert across.contested_refs(claimants) == ["o/r#1: kept by ingest, also claimed by warehouse"]
    assert "stale" not in across.contested_refs(claimants)[0]


def test_a_manifest_with_no_label_at_all_is_named_by_position_and_never_skipped():
    """The never-skip rule. Skipping would reproduce the `program` defect under a different key name:
    the function would go quietly empty the day the identity key moved again.

    The positional string is now the LABEL's fallback only -- identity is the argument index whether
    or not any `_id` is readable -- so an unlabelled manifest still claims its rows for a structural
    reason rather than because a synthesized name happened to be distinct. It is less useful than a
    slug and that is accepted: it is still TRUE and still VISIBLE. In production `_id` is always
    stamped, so a `manifest[N]` on screen is a tripwire saying a caller assembled manifests without
    going through the loader.
    """
    anonymous = [_manifest([_row("1", "o/r#1")]), _manifest([_row("1", "o/r#1")])]
    assert across.contested_refs(anonymous) == ["o/r#1: kept by manifest[0], also claimed by manifest[1]"]
    # A blank or whitespace `_id` is the same case as an absent one, and the index still tracks the
    # argument position rather than a counter over the labelled ones.
    blank = [_manifest([_row("1", "o/r#1")], _id="ingest"), _manifest([_row("1", "o/r#1")], _id="   ")]
    assert across.contested_refs(blank) == ["o/r#1: kept by ingest, also claimed by manifest[1]"]
    # Discriminator: the label is a FALLBACK. Given identities, no positional string appears.
    named = [_manifest([_row("1", "o/r#1")], _id=n) for n in ("ingest", "warehouse")]
    assert "manifest[" not in across.contested_refs(named)[0]


# ── divergence (c): a contest is over WORK, and only rows are work ───────────


def test_two_manifests_sharing_only_an_apex_ref_are_not_contested():
    """Two projects tracked by one issue is coordination, not a conflict. merge-tree's copy includes
    the apex because it regroups items onto a project with the same map; that job stays over there.
    """
    tracker = {"ref": "o/track#7"}
    claimants = [
        _manifest([_row("1", "o/r#1")], apex=tracker, _id="ingest"),
        _manifest([_row("1", "o/r#2")], apex=tracker, _id="warehouse"),
    ]
    assert across.contested_refs(claimants) == []
    # Discriminator: the same ref DOES contest once it is a ROW in both -- so the emptiness above is
    # about the apex being excluded, not about this ref shape being unreadable.
    as_rows = [
        _manifest([_row("1", "o/track#7")], _id="ingest"),
        _manifest([_row("1", "o/track#7")], _id="warehouse"),
    ]
    assert len(across.contested_refs(as_rows)) == 1


def test_an_after_pointer_at_another_manifests_row_is_not_contested():
    """This is the NORMAL cross-project case manifests exist to express: one project's row merges
    after another's. Reporting it would make every declared cross-repository dependency a conflict.
    """
    claimants = [
        _manifest([_row("1", "o/r#1")], _id="ingest"),
        _manifest([_row("1", "o/r#2", after=["o/r#1"])], _id="warehouse"),
    ]
    assert across.contested_refs(claimants) == []
    assert ("o/r#1", "o/r#2") in {(e["parent"], e["child"]) for e in across.edges_from(claimants)}, "still an edge"
    # Discriminator: promote the pointer to a row and it contests.
    as_row = [
        _manifest([_row("1", "o/r#1")], _id="ingest"),
        _manifest([_row("1", "o/r#1"), _row("2", "o/r#2")], _id="warehouse"),
    ]
    assert len(across.contested_refs(as_row)) == 1


def test_a_blocked_by_ref_pointer_at_another_manifests_row_is_not_contested():
    """A gate blocked on someone else's work is a dependency BETWEEN workstreams, not evidence that
    two manifests claim the same one.
    """
    gate = {"kind": "verification", "blocked_by": "prose", "blocked_by_ref": "o/r#1", "resolved_by": "it merges"}
    claimants = [
        _manifest([_row("1", "o/r#1")], _id="ingest"),
        _manifest([_row("1", "o/r#2", gate=gate)], _id="warehouse"),
    ]
    assert across.contested_refs(claimants) == []
    # Discriminator: the blocker ref is readable and does contest as a row.
    as_row = [
        _manifest([_row("1", "o/r#1")], _id="ingest"),
        _manifest([_row("1", "o/r#1")], _id="warehouse"),
    ]
    assert len(across.contested_refs(as_row)) == 1


def test_a_clean_pair_and_an_empty_list_are_both_silent():
    clean = [
        _manifest([_row("1", "acme/platform#10"), _row("2", "acme/warehouse#20")], _id="ingest"),
        _manifest([_row("1", "acme/pipelines#30")], _id="keypair"),
    ]
    assert across.contested_refs(clean) == []
    assert across.contested_refs([]) == []
    assert across.contested_refs([_manifest([])]) == []
    # Discriminator: these fixtures are readable -- they produce edges -- so the silence is about
    # ownership, not about the manifests being unparsed.
    assert across.edges_from(clean) != []


# ── purity ───────────────────────────────────────────────────────────────────


def test_across_imports_no_impure_module():
    """Mirrors borg_core/link/test_picture.py's AST walk, and exists for the same reason: `make lint`
    alone does NOT catch an impurity here. The clean-architecture linter's allow-list already permits
    `pathlib`, `json` and `datetime`, and its import check RETURNS EARLY on a file it cannot classify
    -- so this asserts the property directly rather than trusting pyproject's Domain map to stay
    right.

    The import set is asserted EXACTLY, not as a blacklist. A blacklist of module names is defeated by
    `from pathlib import Path as P`, which is the exact case test_shell.py's
    test_the_domain_layer_imports_no_io_modules was rewritten to catch; an exact set fails on any new
    name at all, impure or merely undeclared, which is the point for a module whose whole contract is
    "plain data in, plain data out".

    AND THERE IS NO BLACKLIST LINE BENEATH IT, deliberately. One used to sit here, intersecting the
    same value against `{"os", "subprocess", ...}` on the next line, and it was dead code: any impure
    import fails the exact-set assertion first, so the intersection could never execute in a run that
    was failing and could never fail in a run that reached it. borg_core/link/test_picture.py and
    test_render.py are blacklist-ONLY for the opposite reason -- neither pins an exact set, so there
    the intersection IS the assertion. Do not "unify" the three.

    MUTATION, chosen to land in the gap rather than in the overlap: add `from pathlib import Path`
    and a `Path("/tmp/flag").read_text()` in contested_refs. Measured -- `pylint
    --load-plugins=clean_architecture_linter borg_core/manifest/across.py` stays at 10.00/10 and
    exits 0, because `pathlib` is on W9004's allow-list, while this test goes red. `import os` plus
    an `os.environ` read is caught by BOTH gates (W9004, pylint exit 4, and this test red), so it
    demonstrates nothing about why this test is needed -- which is the only reason it is not the
    mutation named here.
    """
    tree = ast.parse(Path(across.__file__).read_text(encoding="utf-8"))
    imported: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            imported.update(alias.name.split(".")[0] for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.module:
            imported.add(node.module.split(".")[0])
    assert imported == {"__future__", "typing", "borg_core"}

    called = {n.func.id for n in ast.walk(tree) if isinstance(n, ast.Call) and isinstance(n.func, ast.Name)}
    assert "open" not in called
    attributes = {n.attr for n in ast.walk(tree) if isinstance(n, ast.Attribute)}
    assert not attributes & {"environ", "getenv", "isatty", "now", "run"}
