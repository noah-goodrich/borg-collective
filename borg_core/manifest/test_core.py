"""Unit tests for borg_core.manifest.core (the pure domain layer).

Calling convention: in-process only, plain data in and plain data out. No filesystem, no fixture
files on disk -- the three-repository manifest that merge-tree/test_programs.py loads from
fixtures/programs/three-repo-program.json is built by `_fixture()` below instead. Two reasons: this
package's test surface is two modules, and an on-disk fixture drags in the REPO_ROOT path-depth trap
that merge-tree/test_s4_manifests.py documents, where a moved file silently discovers zero manifests
and the failure reads as "the feature is missing" rather than "the test moved".

The load-bearing test here is test_a_lane_spanning_three_repositories_yields_cross_repository_edges.
Every other edge source in the pipeline is repository-local by construction, so if that one passes
vacuously the whole reason this package exists is unmet.
"""

from __future__ import annotations

import pytest

from borg_core.manifest import core


def _manifest(rows, apex=None):
    m = {"rows": rows}
    if apex is not None:
        m["apex"] = apex
    return m


def _row(order, ref, lane=None, **extra):
    r = {"order": order, "ref": ref, **extra}
    if lane is not None:
        r["lane"] = lane
    return r


def _gate(ref=None, **over):
    gate = {"blocked_by": "prose", "kind": "verification", "resolved_by": "it merges", **over}
    if ref is not None:
        gate["blocked_by_ref"] = ref
    return gate


def _fixture():
    """The three-repository manifest, rebuilt fresh each call so no test can mutate another's input.

    Content-equivalent to merge-tree/fixtures/programs/three-repo-program.json: an apex, two lanes,
    a merged prerequisite anchoring one of them, a lane whose declared order spans three
    repositories, one `decision` gate and one `verification` gate, both prose-only.
    """
    return {
        "program": "auth-hardening",
        "apex": {"ref": "acme/platform#900", "label": "auth hardening tracker"},
        "note": "Synthetic fixture. Exercises the case branch topology cannot reach.",
        "rows": [
            {"order": "–", "ref": "acme/platform#801", "lane": "ingest", "ticket": "", "status": "merged"},
            {
                "order": "I1",
                "ref": "acme/platform#834",
                "lane": "ingest",
                "ticket": "OPS-11",
                "status": "stacked",
                "gate": {
                    "blocked_by": "waiting on a colleague's review",
                    "kind": "decision",
                    "resolved_by": "review lands on acme/platform#834",
                },
            },
            {"order": "I2", "ref": "acme/warehouse#302", "lane": "ingest", "ticket": "OPS-12", "status": "review"},
            {
                "order": "I3",
                "ref": "acme/pipelines#301",
                "lane": "ingest",
                "ticket": "OPS-12",
                "status": "stacked",
                "next": True,
                "why": "unblocks the rest of the lane once #302 merges",
            },
            {"order": "K1", "ref": "acme/warehouse#292", "lane": "keypair", "ticket": "OPS-20", "status": "review"},
            {
                "order": "K2",
                "ref": "acme/warehouse#293",
                "lane": "keypair",
                "ticket": "OPS-20",
                "status": "stacked",
                "gate": {
                    "blocked_by": "needs a load test against staging",
                    "kind": "verification",
                    "resolved_by": "staging load-test run",
                    "outcomes": ["passes -> merge", "fails -> rework #292"],
                },
            },
        ],
    }


# ── constants ────────────────────────────────────────────────────────────────


def test_prereq_orders_carries_the_exact_four_codepoints():
    # The glyphs are visually indistinguishable, and the en dash is the ONLY one production uses.
    # A "normalize the punctuation" pass that swapped U+2013 for U+002D would leave this set looking
    # correct while dropping every live prerequisite row into the numbered bucket.
    assert sorted(ord(c) for c in core.PREREQ_ORDERS if c) == [0x2D, 0x2013, 0x2014]
    assert "" in core.PREREQ_ORDERS


def test_gate_kinds_declares_exactly_two_members():
    # DECLARED, not enforced: the validator no longer closes `gate.kind` to this set. It is the
    # vocabulary `render._GATE_ROUTING` must never fall behind, asserted over there.
    assert core.GATE_KINDS == {"decision", "verification"}


def test_default_lane_is_the_named_constant():
    assert core.DEFAULT_LANE == "_default"


def test_apex_is_not_an_ordering_kind():
    # An apex edge points at EVERY row; counting it would flatten the whole stack into one level.
    assert core.ORDERING_EDGE_KINDS == ("stacked", "blocks")
    assert "apex" not in core.ORDERING_EDGE_KINDS


def test_state_tokens_are_the_adapters_three():
    # recon-adapter-github:179 emits exactly these, lowercased from the GraphQL enum.
    assert (core.STATE_OPEN, core.STATE_MERGED, core.STATE_CLOSED) == ("open", "merged", "closed")


# ── validate ─────────────────────────────────────────────────────────────────


def test_a_minimal_manifest_is_valid():
    assert core.validate(_manifest([_row("1", "o/r#1")])) == []


def test_missing_rows_is_reported_and_stops_further_checks():
    # The apex is NOT checked on this branch; the sole element is the rows error.
    assert core.validate({}) == ["rows: missing or not a list"]
    assert core.validate({"rows": "nope", "apex": {}}) == ["rows: missing or not a list"]


def test_every_offending_row_is_reported_in_one_pass():
    # The whole point of returning a list: a manifest with three problems is fixed in one edit.
    # Row 2's gate is EMPTY, not mistyped: an unrecognized `kind` is no longer a validation error at
    # all (see test_an_unrecognized_gate_kind_is_the_routers_problem_not_the_validators), so a typo'd
    # one here would have quietly stopped exercising the third defect.
    errors = core.validate(_manifest([_row("1", ""), {"ref": "o/r#2"}, _row("3", "o/r#3", gate={})]))
    assert len(errors) >= 4
    assert any("rows[0]" in e for e in errors)
    assert any("rows[1]" in e and "order" in e for e in errors)
    assert any("rows[2]" in e and "gate.kind" in e for e in errors)


def test_a_duplicate_ref_is_rejected_and_names_the_earlier_index():
    errors = core.validate(_manifest([_row("1", "o/r#1"), _row("2", "o/r#1")]))
    assert any("duplicate ref o/r#1" in e and "rows[0]" in e for e in errors)


def test_an_unrecognized_gate_kind_is_the_routers_problem_not_the_validators():
    """MUTATION: restore `if kind not in GATE_KINDS: errors.append(...)`.

    An unrecognized kind then becomes a row-scoped error again, `_drop_invalid_rows` DELETES the row,
    and `render._GROUP_UNSURE` -- the group built to say "the router does not know this kind" --
    becomes unreachable through the front door for the second time.
    """
    for kind in ("decision", "verification"):
        assert core.validate(_manifest([_row("1", "o/r#1", gate=_gate(kind=kind))])) == []
    assert core.validate(_manifest([_row("1", "o/r#1", gate=_gate(kind="review"))])) == []


def test_a_gate_that_names_no_kind_is_still_a_defect():
    """UNRECOGNIZED AND ABSENT ARE DIFFERENT FACTS, and only the second is a defect.

    `render._route("")` returns `mine` ON THE STRENGTH OF THE ROW BEING UNGATED. A gate declaring a
    blank kind would take that same branch, so a row that HAS a gate would be routed by the rule for
    rows that do not -- and if the author meant a decision, that is the plan's own named risk (an
    agent acting on a human's call) arriving with nothing mis-set. Empty stays fatal so that stays
    impossible. Unrecognized is the OTHER fact and gets `unsure`, which names itself on the page.
    """
    for gate in ({"blocked_by": "prose", "resolved_by": "it merges"}, _gate(kind=""), _gate(kind="   ")):
        errors = core.validate(_manifest([_row("1", "o/r#1", gate=gate)]))
        assert any("gate.kind is required" in e for e in errors), gate


def test_a_gate_must_name_what_settles_it():
    gate = {"kind": "decision", "blocked_by": "waiting on someone"}
    errors = core.validate(_manifest([_row("1", "o/r#1", gate=gate)]))
    assert any("gate.resolved_by is required" in e for e in errors)


def test_a_gate_must_name_what_blocks_it():
    gate = {"kind": "decision", "resolved_by": "someone decides"}
    errors = core.validate(_manifest([_row("1", "o/r#1", gate=gate)]))
    assert any("gate.blocked_by is required" in e for e in errors)


def test_a_non_object_gate_is_rejected():
    assert any("gate must be an object" in e for e in core.validate(_manifest([_row("1", "o/r#1", gate="prose")])))


def test_a_row_without_a_gate_is_fine():
    # 13 of the 16 live rows have no gate.
    assert core.validate(_manifest([_row("1", "o/r#1")])) == []


def test_an_apex_without_a_ref_is_rejected():
    assert any("apex" in e for e in core.validate(_manifest([_row("1", "o/r#1")], apex={})))


def test_a_non_object_apex_is_rejected():
    assert core.validate(_manifest([_row("1", "o/r#1")], apex="acme/x#1")) == ["apex: must be an object when present"]


def test_no_apex_at_all_is_valid():
    # THE core-rule exception, and the state BOTH live manifests are actually in.
    assert core.validate(_manifest([_row("1", "o/r#1")])) == []


def test_an_order_key_present_but_empty_is_valid():
    # KEY presence, not truthiness -- an empty order sorts as a prerequisite.
    assert core.validate(_manifest([{"ref": "o/r#1", "order": ""}])) == []
    assert core.validate(_manifest([{"ref": "o/r#1", "order": None}])) == []


def test_non_dict_rows_are_validation_errors_not_silently_dropped():
    # {"rows": ["o/a#1"]} used to load as a VALID manifest declaring nothing. This is the test that
    # forces validate to iterate the RAW list rather than the tolerant _rows() reader.
    errors = core.validate({"program": "x", "rows": ["o/a#1", {"order": "1", "ref": "o/b#1"}]})
    assert len(errors) == 1
    assert "rows[0]" in errors[0] and "not an object" in errors[0]


def test_the_fixture_is_valid():
    assert core.validate(_fixture()) == []


@pytest.mark.parametrize(
    "ref",
    ["ingle#12", "PROJ-123", "o/r", "o/r#", "o/r#abc", "a/b/c#1", "/r#1", "o/#1", "o r/x#1"],
    ids=[
        "repo-shorthand",
        "jira-key",
        "no-number",
        "empty-number",
        "non-numeric",
        "two-slashes",
        "leading-slash",
        "empty-name",
        "space-in-owner",
    ],
)
def test_a_row_ref_that_is_not_a_full_ref_is_rejected(ref):
    # `ingle#12` is the one a model authoring a manifest headless (AC5) actually writes, and it used
    # to validate CLEAN: it then loads through discovery and produces a node parse_ref cannot build
    # (so AC3's targeted fetch renders it `unknown`, which AC3 forbids) and ref_slug cannot scope
    # (so the row is invisible in its own repository's grid). parse_ref's contract is that a
    # non-conforming ref is a defect to SURFACE; validate is the surfacing point.
    errors = core.validate(_manifest([_row("1", ref)]))
    assert any("must be a full ref" in e for e in errors), errors


def test_a_padded_row_ref_is_accepted_because_text_strips_it_first():
    # The negative pair, and a real property rather than an oversight: `_text` is applied module-wide
    # BEFORE parse_ref, so `" o/r#1 "` and `"o/r#1\n"` are the same declaration as `"o/r#1"` -- the
    # same coercion the edge builders and declared_refs apply, which is what keeps a declared ref and
    # the edge endpoint derived from it byte-identical.
    assert core.validate(_manifest([_row("1", " o/r#1 "), _row("2", "o/r#2\n")])) == []


def test_the_two_wrong_answers_a_shorthand_row_ref_would_produce():
    # The negative half, showing what validate is preventing rather than asserting it in prose.
    m = _manifest([_row("1", "ingle#12")])
    assert core.parse_ref("ingle#12") is None, "AC3 cannot build a node for it"
    assert core.select_for_repository([m], "stillpoint-labs/ingle") == [], "and no repository scopes it"


def test_an_apex_ref_that_is_not_a_full_ref_is_rejected():
    # The apex goes into declared_refs and therefore into AC3's fetch; a shorthand tracker would
    # render `unknown` forever, exactly like a shorthand row.
    errors = core.validate(_manifest([_row("1", "o/r#1")], apex={"ref": "tracker#9"}))
    assert errors == ["apex: ref must be a full ref (owner/repo#num), got tracker#9"]


def test_a_full_apex_ref_is_valid():
    assert core.validate(_manifest([_row("1", "o/r#1")], apex={"ref": "o/tracker#9"})) == []


# ── validate: row-level `after` (AC4) ────────────────────────────────────────


def test_an_after_list_of_refs_is_valid():
    assert core.validate(_manifest([_row("1", "o/r#1"), _row("2", "o/r#2", after=["o/r#1"])])) == []


def test_after_naming_a_ref_outside_this_manifest_is_valid_input_not_an_error():
    # AC3's targeted fetch exists to resolve exactly these. Rejecting them would make the one case
    # the feature was built for a validation error.
    assert core.validate(_manifest([_row("1", "o/r#2", after=["other/repo#99"])])) == []


def test_after_must_be_a_list():
    errors = core.validate(_manifest([_row("1", "o/r#1", after="o/r#2")]))
    assert errors == ["rows[0]: after must be a list of refs"]


def test_after_null_is_treated_as_absent():
    # Symmetric with a null gate, which _validate_gate also reads as "not present".
    assert core.validate(_manifest([_row("1", "o/r#1", after=None)])) == []


@pytest.mark.parametrize(
    "entry,fragment",
    [
        ("waiting on Kelly", "must be a full ref"),
        ("", "is empty"),
        ("   ", "is empty"),
        ("waiting on PR #149", "must be a full ref"),
        ("#149", "must be a full ref"),
        ("#", "must be a full ref"),
        (" # ", "must be a full ref"),
        ("repo#12", "must be a full ref"),
        ("o/r#abc", "must be a full ref"),
    ],
    ids=[
        "prose",
        "empty",
        "whitespace",
        "prose-with-hash",
        "bare-number",
        "bare-hash",
        "padded-hash",
        "shorthand",
        "non-numeric",
    ],
)
def test_a_non_ref_after_entry_is_rejected(entry, fragment):
    # Prose here would produce an ordering edge pointing at nothing -- the exact failure the prose
    # `blocked_by` field stays prose to avoid. The four `#`-bearing cases are what a bare
    # `"#" in value` test admitted: each one becomes a `stacked` edge whose parent is that literal
    # string, goes into declared_refs so the targeted fetch queries prose, and removes the row from
    # ready_set forever. The live manifest's own prose carries `(PR #149)`, so this is the shape a
    # hand author actually writes.
    errors = core.validate(_manifest([_row("1", "o/r#1", after=[entry])]))
    assert len(errors) == 1 and fragment in errors[0]


def test_a_prose_after_entry_that_slips_through_would_wedge_the_row_forever():
    # WHY the case above is worth nine rows: validate is the only thing standing between
    # `after: ["#149"]` and a row that can never be announced. derive_edges is tolerant by design
    # and will happily build the edge from whatever it is handed.
    m = _manifest([_row("1", "o/r#1"), _row("2", "o/r#2", after=["#149"])])
    assert [e["parent"] for e in core.derive_edges(m) if e["kind"] == "stacked"] == ["#149"]
    assert core.ready_set(m, {"o/r#1": "merged", "o/r#2": "open"}) == []
    assert core.validate(m), "validate is what stops this shape from ever loading"


def test_a_non_string_after_entry_is_rejected():
    errors = core.validate(_manifest([_row("1", "o/r#1", after=[7])]))
    assert len(errors) == 1 and "must be a ref string" in errors[0] and "int" in errors[0]


def test_a_row_that_names_itself_in_after_is_rejected():
    # A row cannot be its own prerequisite; as a self-edge it would be dropped silently rather than
    # reported.
    errors = core.validate(_manifest([_row("1", "o/r#1", after=["o/r#1"])]))
    assert len(errors) == 1 and "names its own ref" in errors[0]


def test_every_bad_after_entry_is_reported_not_just_the_first():
    errors = core.validate(_manifest([_row("1", "o/r#1", after=["prose", "", "o/r#1"])]))
    assert len(errors) == 3


# ── lanes ────────────────────────────────────────────────────────────────────


def test_rows_sort_by_declared_order_not_file_order():
    m = _manifest([_row("E3", "o/r#3", "eval"), _row("E1", "o/r#1", "eval"), _row("E2", "o/r#2", "eval")])
    assert [r["ref"] for r in core.lanes(m)["eval"]] == ["o/r#1", "o/r#2", "o/r#3"]


def test_prerequisites_sort_ahead_of_numbered_rows_in_file_order():
    # THE test that pins the en dash. E1 is deliberately FIRST in file order, so a port that dropped
    # U+2013 from PREREQ_ORDERS fails here and only here.
    m = _manifest([_row("E1", "o/r#9", "eval"), _row("–", "o/r#1", "eval"), _row("–", "o/r#2", "eval")])
    assert [r["ref"] for r in core.lanes(m)["eval"]] == ["o/r#1", "o/r#2", "o/r#9"]


def test_an_em_dash_and_an_ascii_hyphen_also_sort_as_prerequisites():
    m = _manifest([_row("E1", "o/r#9", "eval"), _row("—", "o/r#1", "eval"), _row("-", "o/r#2", "eval")])
    assert [r["ref"] for r in core.lanes(m)["eval"]] == ["o/r#1", "o/r#2", "o/r#9"]


def test_double_digit_order_sorts_numerically_not_lexically():
    m = _manifest([_row("E10", "o/r#10", "eval"), _row("E2", "o/r#2", "eval")])
    assert [r["ref"] for r in core.lanes(m)["eval"]] == ["o/r#2", "o/r#10"]


def test_an_unparseable_order_falls_back_to_file_position():
    m = _manifest([_row("later", "o/r#2", "eval"), _row("nope", "o/r#1", "eval")])
    assert [r["ref"] for r in core.lanes(m)["eval"]] == ["o/r#2", "o/r#1"]


def test_two_unparseable_orders_in_one_lane_keep_declared_file_order():
    # The negative pair for the test above and the FIRST of the two cases that discriminate
    # _sort_key's third tuple element. Both keys here are (1, index, index): with the third element
    # removed the second stays undiscriminated by Python's stable sort, but flipping the tie-break to
    # `-index` silently reverses the lane -- and with it the direction of the derived edge.
    m = _manifest([_row("nope", "o/r#2", "eval"), _row("later", "o/r#1", "eval")])
    assert [r["ref"] for r in core.lanes(m)["eval"]] == ["o/r#2", "o/r#1"]


def test_two_orders_parsing_to_the_same_number_are_broken_by_file_position():
    # `1` and `E1` both parse to 1, so the keys differ ONLY in the third element -- the one the
    # docstring calls out as explicit rather than inherited from the stable sort. The edge assertion
    # is the point: a reversed tie-break flips the lane order, which flips the derived edge from
    # o/r#1 -> o/r#2 to o/r#2 -> o/r#1 and inverts the level assignment for the whole lane.
    m = _manifest([_row("1", "o/r#1", "L"), _row("E1", "o/r#2", "L")])
    assert [r["ref"] for r in core.lanes(m)["L"]] == ["o/r#1", "o/r#2"]
    assert [e for e in core.derive_edges(m) if e["kind"] == "stacked"] == [
        {"parent": "o/r#1", "child": "o/r#2", "kind": "stacked", "source": "declared"}
    ]


def test_rows_with_no_lane_form_one_default_lane():
    m = _manifest([_row("1", "o/r#1"), _row("2", "o/r#2")])
    assert list(core.lanes(m)) == [core.DEFAULT_LANE]


def test_refless_rows_are_excluded_from_lanes():
    # The precondition that lets the edge builders index row["ref"] with no .get.
    assert core.lanes(_manifest([_row("1", "")])) == {}


def test_lane_names_come_back_alphabetically_not_in_declaration_order():
    m = _manifest([_row("1", "o/r#1", "cutover"), _row("C1", "o/r#2", "contract")])
    assert list(core.lanes(m)) == ["contract", "cutover"]


def test_a_malformed_rows_value_yields_no_lanes():
    assert core.lanes({"rows": "nope"}) == {}
    assert core.lanes({"rows": ["bare"]}) == {}


# ── derive_edges ─────────────────────────────────────────────────────────────


def test_consecutive_rows_in_a_lane_are_stacked():
    m = _manifest([_row("1", "o/r#1"), _row("2", "o/r#2"), _row("3", "o/r#3")])
    stacked = [e for e in core.derive_edges(m) if e["kind"] == "stacked"]
    assert stacked == [
        {"parent": "o/r#1", "child": "o/r#2", "kind": "stacked", "source": "declared"},
        {"parent": "o/r#2", "child": "o/r#3", "kind": "stacked", "source": "declared"},
    ]


def test_separate_lanes_do_not_link_to_each_other():
    m = _manifest([_row("E1", "o/r#1", "eval"), _row("K1", "o/r#2", "keypair")])
    assert [e for e in core.derive_edges(m) if e["kind"] == "stacked"] == []


def test_a_lane_spanning_three_repositories_yields_cross_repository_edges():
    # THE criterion. Branch topology cannot produce these: a base branch is a repository-local name,
    # so every derived edge is repository-local. Only a declaration crosses repositories.
    edges = core.derive_edges(_fixture())
    stacked = {(e["parent"], e["child"]) for e in edges if e["kind"] == "stacked"}
    assert ("acme/platform#834", "acme/warehouse#302") in stacked
    assert ("acme/warehouse#302", "acme/pipelines#301") in stacked
    repositories = {core.ref_slug(r) for pair in stacked for r in pair}
    assert len(repositories) >= 3


def test_the_merged_prerequisite_anchors_the_chain():
    stacked = {(e["parent"], e["child"]) for e in core.derive_edges(_fixture()) if e["kind"] == "stacked"}
    assert ("acme/platform#801", "acme/platform#834") in stacked


def test_every_row_gets_an_apex_edge_when_an_apex_exists():
    apex = [e for e in core.derive_edges(_fixture()) if e["kind"] == "apex"]
    assert len(apex) == len(_fixture()["rows"])
    assert {e["parent"] for e in apex} == {"acme/platform#900"}


def test_no_apex_means_no_apex_edges():
    m = _manifest([_row("1", "o/r#1"), _row("2", "o/r#2")])
    assert [e for e in core.derive_edges(m) if e["kind"] == "apex"] == []


def test_a_row_that_is_the_apex_gets_no_self_edge():
    m = _manifest([_row("1", "o/r#1")], apex={"ref": "o/r#1"})
    assert [e for e in core.derive_edges(m) if e["kind"] == "apex"] == []


def test_every_edge_carries_declared_provenance():
    # Provenance is what makes a wrong edge falsifiable.
    assert all(e["source"] == "declared" for e in core.derive_edges(_fixture()))


def test_output_is_deterministic_regardless_of_row_order():
    rows = [_row("1", "o/r#1"), _row("2", "o/r#2"), _row("3", "o/r#3")]
    assert core.derive_edges(_manifest(rows)) == core.derive_edges(_manifest(list(reversed(rows))))


def test_an_empty_manifest_yields_no_edges():
    assert core.derive_edges({"rows": []}) == []


def test_a_blocked_by_ref_becomes_a_blocks_edge():
    m = _manifest([_row("1", "o/r#2", gate=_gate("o/r#9"))])
    blocks = [e for e in core.derive_edges(m) if e["kind"] == "blocks"]
    assert blocks == [{"parent": "o/r#9", "child": "o/r#2", "kind": "blocks", "source": "declared"}]


def test_a_blocks_edge_may_cross_repositories():
    m = _manifest([_row("1", "acme/warehouse#2", gate=_gate("acme/platform#9"))])
    blocks = [e for e in core.derive_edges(m) if e["kind"] == "blocks"]
    assert blocks[0]["parent"] == "acme/platform#9"


def test_a_prose_only_gate_yields_no_blocks_edge():
    # The ONLY gate shape present in production: neither live manifest has a blocked_by_ref.
    m = _manifest([_row("1", "o/r#2", gate=_gate())])
    assert [e for e in core.derive_edges(m) if e["kind"] == "blocks"] == []


def test_a_self_blocking_ref_is_ignored():
    m = _manifest([_row("1", "o/r#2", gate=_gate("o/r#2"))])
    assert [e for e in core.derive_edges(m) if e["kind"] == "blocks"] == []


@pytest.mark.parametrize(
    "value",
    ["waiting on Kelly", "waiting on PR #149", "#149", "#", "repo#12", "o/r#abc"],
    ids=["prose", "prose-with-hash", "bare-number", "bare-hash", "shorthand", "non-numeric"],
)
def test_a_non_ref_blocked_by_ref_is_rejected_by_validate(value):
    errors = core.validate(_manifest([_row("1", "o/r#2", gate=_gate(value))]))
    assert any("blocked_by_ref must be a full ref" in e for e in errors)


def test_a_prose_blocked_by_ref_that_slips_through_is_erased_from_every_report():
    # WHY the gate channel is worse than the `after` channel, and why the bare `#` test had to go:
    # a gate carrying ANY truthy blocked_by_ref is excluded from unmapped_gates, so prose there
    # produces an edge pointing at nothing, appears in NO report, and wedges the row -- three
    # failures from one unchecked string.
    m = _manifest([_row("1", "o/r#2", gate=_gate("waiting on PR #149", kind="decision"))])
    assert [e["parent"] for e in core.derive_edges(m) if e["kind"] == "blocks"] == ["waiting on PR #149"]
    assert core.unmapped_gates(m) == []
    assert core.ready_set(m, {"o/r#2": "open"}) == []
    assert core.validate(m), "validate is what stops this shape from ever loading"


def test_a_gate_naming_its_own_row_is_rejected_by_validate():
    # THE self-referential gate. Unchecked it is erased in three places at once: _blocks_edges drops
    # the self-edge, unmapped_gates skips any gate carrying a blocked_by_ref, and ready_set then
    # sees a row with no parents -- so an OPEN decision gate is rendered nowhere and its row is
    # announced startable. _validate_after has had this check on the sibling channel from the start.
    gate = _gate("o/r#1", kind="decision", blocked_by="needs Noah to choose the rollout window")
    errors = core.validate(_manifest([_row("1", "o/r#1", gate=gate)]))
    assert len(errors) == 1 and "gate.blocked_by_ref names its own ref o/r#1" in errors[0]


def test_a_self_blocking_gate_is_padding_insensitive():
    # `_text` strips before comparing, so whitespace cannot smuggle the same ref past the check.
    gate = _gate("  o/r#1  ", kind="decision", blocked_by="needs Noah to choose the rollout window")
    errors = core.validate(_manifest([_row("1", "o/r#1", gate=gate)]))
    assert any("names its own ref" in e for e in errors)


def test_the_erasure_a_self_blocking_gate_would_cause_if_it_loaded():
    # The negative half: this is what validate is preventing. All three readers agree the gate is
    # not there, and ready_set announces the gated row.
    gate = _gate("o/r#1", kind="decision", blocked_by="needs Noah to choose the rollout window")
    m = _manifest([_row("1", "o/r#1", gate=gate)])
    assert [e for e in core.derive_edges(m) if e["kind"] == "blocks"] == []
    assert core.unmapped_gates(m) == []
    assert core.ready_set(m, {"o/r#1": "open"}) == ["o/r#1"]
    assert core.validate(m), "which is exactly why it must never load"


def test_blocked_by_ref_is_optional():
    assert core.validate(_manifest([_row("1", "o/r#2", gate=_gate())])) == []


def test_a_full_blocked_by_ref_naming_another_row_is_valid():
    # The positive pair for both gate.blocked_by_ref checks: a full ref that is not this row's own
    # is the whole point of the field, and validate must let it through untouched.
    assert core.validate(_manifest([_row("1", "o/r#2", gate=_gate("o/r#9"))])) == []
    assert core.validate(_manifest([_row("1", "o/r#2", gate=_gate("other/repo#99"))])) == []


def test_an_after_entry_becomes_a_stacked_edge():
    # Emitted as `stacked`, not a fourth kind: levels() and ready_set() treat lane adjacency and
    # `after` identically, and a fourth kind would force every consumer to learn a distinction with
    # no behavioral difference.
    m = _manifest([_row("1", "o/r#1", "a"), _row("1", "o/r#2", "b", after=["o/r#1"])])
    stacked = [e for e in core.derive_edges(m) if e["kind"] == "stacked"]
    assert stacked == [{"parent": "o/r#1", "child": "o/r#2", "kind": "stacked", "source": "declared"}]


def test_a_fork_gives_two_children_one_shared_parent():
    m = _manifest(
        [
            _row("1", "o/r#1", "a"),
            _row("1", "o/r#2", "b", after=["o/r#1"]),
            _row("1", "o/r#3", "c", after=["o/r#1"]),
        ]
    )
    stacked = {(e["parent"], e["child"]) for e in core.derive_edges(m) if e["kind"] == "stacked"}
    assert stacked == {("o/r#1", "o/r#2"), ("o/r#1", "o/r#3")}


def _intra_lane_fork():
    """Rows 1, 2, 3 in ONE lane where row 3 declares its only parent is row 1.

    THE shape AC4 adds `after` for, and the one no other test covers: every existing fork case puts
    each branch in a SEPARATE lane, where there is no lane adjacency to override and the rule is
    therefore never exercised. SCHEMA.md:259-261 records the derivation rule for the field --
    "explicit `after` overrides consecutive-row inference within the lane" -- and unioning the two
    instead leaves the inferred 2->3 edge alive, which renders a fork as a straight chain.
    """
    return _manifest(
        [
            _row("1", "o/r#1", "main"),
            _row("2", "o/r#2", "main"),
            _row("3", "o/r#3", "main", after=["o/r#1"]),
        ]
    )


def test_after_overrides_lane_adjacency_so_an_intra_lane_fork_is_a_fork():
    stacked = {(e["parent"], e["child"]) for e in core.derive_edges(_intra_lane_fork()) if e["kind"] == "stacked"}
    assert stacked == {("o/r#1", "o/r#2"), ("o/r#1", "o/r#3")}


def test_an_intra_lane_fork_puts_both_children_on_one_level():
    m = _intra_lane_fork()
    assert core.levels(core.declared_refs(m), core.derive_edges(m)) == [["o/r#1"], ["o/r#2", "o/r#3"]]


def test_an_intra_lane_fork_announces_both_children_ready_at_once():
    # The user-visible half: under the union rule this announced ONE next thing when two were
    # startable -- under-announcing READY, which AC4 defines as "all READY nodes are next
    # simultaneously".
    states = {"o/r#1": "merged", "o/r#2": "open", "o/r#3": "open"}
    assert core.ready_set(_intra_lane_fork(), states) == ["o/r#2", "o/r#3"]


def test_the_same_lane_without_after_is_still_a_chain():
    # The negative pair: the override must be caused by `after`, not by the lane shape.
    m = _manifest([_row("1", "o/r#1", "main"), _row("2", "o/r#2", "main"), _row("3", "o/r#3", "main")])
    assert core.levels(core.declared_refs(m), core.derive_edges(m)) == [["o/r#1"], ["o/r#2"], ["o/r#3"]]
    assert core.ready_set(m, {"o/r#1": "merged", "o/r#2": "open", "o/r#3": "open"}) == ["o/r#2"]


@pytest.mark.parametrize("after", [[], [7], ["   "], ["o/r#2"]], ids=["empty", "non-string", "blank", "self"])
def test_an_after_that_supplies_no_usable_parent_leaves_the_row_on_its_lane(after):
    # The override is keyed on edges ACTUALLY PRODUCED, not on the presence of an `after` key: an
    # empty or wholly unusable list must not orphan a row from a chain it never opted out of.
    m = _manifest([_row("1", "o/r#1", "main"), _row("2", "o/r#2", "main", after=after)])
    stacked = [(e["parent"], e["child"]) for e in core.derive_edges(m) if e["kind"] == "stacked"]
    assert stacked == [("o/r#1", "o/r#2")]


def test_after_restating_a_lane_adjacency_collapses_to_one_edge():
    # Without the dedup, one declared ordering would count TWICE in any indegree computation.
    m = _manifest([_row("1", "o/r#1", "a"), _row("2", "o/r#2", "a", after=["o/r#1"])])
    assert len([e for e in core.derive_edges(m) if e["kind"] == "stacked"]) == 1


def test_a_non_string_after_entry_produces_no_edge():
    m = _manifest([_row("1", "o/r#1", after=[7, None])])
    assert core.derive_edges(m) == []


def test_a_row_naming_itself_in_after_is_skipped_without_losing_its_siblings():
    # validate rejects the self-reference, but derive_edges runs on whatever it is handed and must
    # drop only the offending entry.
    m = _manifest([_row("1", "o/r#1", "a"), _row("1", "o/r#2", "b", after=["o/r#2", "", "o/r#1"])])
    stacked = [e for e in core.derive_edges(m) if e["kind"] == "stacked"]
    assert stacked == [{"parent": "o/r#1", "child": "o/r#2", "kind": "stacked", "source": "declared"}]


def test_two_consecutive_rows_with_the_same_ref_yield_no_self_edge():
    # validate rejects a duplicate ref, but lanes() is tolerant and derive_edges must not manufacture
    # a row that is its own prerequisite.
    m = _manifest([_row("1", "o/r#1", "a"), _row("2", "o/r#1", "a"), _row("3", "o/r#2", "a")])
    stacked = [(e["parent"], e["child"]) for e in core.derive_edges(m) if e["kind"] == "stacked"]
    assert stacked == [("o/r#1", "o/r#2")]


# ── unmapped_gates ───────────────────────────────────────────────────────────


def test_a_prose_blocker_is_reported_not_turned_into_an_edge():
    edges = core.derive_edges(_fixture())
    assert not any("colleague" in e["parent"] for e in edges)
    # A LIST, not a set: the documented "sorted by ref" ordering is a public property of the return
    # value, and a set comparison leaves the sort undiscriminated -- reversing it kept every test
    # green while silently changing the order a consumer renders.
    assert [g["ref"] for g in core.unmapped_gates(_fixture())] == ["acme/platform#834", "acme/warehouse#293"]


def test_gate_kind_is_carried_so_verification_is_distinguishable():
    # A verification with declared outcomes is never a blocker on a PERSON -- anyone can run it.
    kinds = {g["ref"]: g["kind"] for g in core.unmapped_gates(_fixture())}
    assert kinds["acme/platform#834"] == "decision"
    assert kinds["acme/warehouse#293"] == "verification"


def test_an_unmapped_gate_carries_exactly_four_keys():
    assert set(core.unmapped_gates(_fixture())[0]) == {"ref", "kind", "blocked_by", "resolved_by"}


def test_rows_without_gates_are_not_reported():
    assert core.unmapped_gates(_manifest([_row("1", "o/r#1")])) == []


def test_a_gate_with_a_ref_is_mapped_not_unmapped():
    # A gate carrying blocked_by_ref IS expressible as an edge; counting it here too would inflate a
    # user-visible number by double-reporting it.
    m = _manifest(
        [
            _row("1", "o/r#1", gate=_gate("o/r#9", blocked_by="depends on o/r#9")),
            _row("2", "o/r#2", gate=_gate(blocked_by="waiting on Kelly", kind="decision")),
        ]
    )
    assert [g["ref"] for g in core.unmapped_gates(m)] == ["o/r#2"]


def test_a_gate_with_no_prose_blocker_is_not_reported():
    assert core.unmapped_gates(_manifest([_row("1", "o/r#1", gate={"kind": "decision"})])) == []


# ── gates (AC4's total routing source) ───────────────────────────────────────


def test_gates_returns_every_gate_including_the_ref_mapped_ones():
    # THE reason this function exists. AC4 routes yours-vs-mine off `gate.kind`, and the only
    # kind-bearing function used to be unmapped_gates, which deliberately EXCLUDES every gate
    # carrying a blocked_by_ref -- so a consumer reaching for it dropped exactly the human decisions
    # that were careful enough to name their blocker. The plan's named risk ("a mis-set gate routes
    # a human decision to an agent silently") reached with nothing mis-set at all.
    m = _manifest(
        [
            _row("1", "o/r#1", gate=_gate("o/r#9", kind="decision", blocked_by="Kelly must approve the schema")),
            _row("2", "o/r#2", gate=_gate(kind="verification", blocked_by="staging load test")),
        ]
    )
    assert [g["ref"] for g in core.unmapped_gates(m)] == ["o/r#2"], "the decision is invisible here, by design"
    assert [(g["ref"], g["kind"]) for g in core.gates(m)] == [
        ("o/r#1", "decision"),
        ("o/r#2", "verification"),
    ]


def test_a_gate_carries_five_keys_including_its_blocked_by_ref():
    m = _manifest([_row("1", "o/r#1", gate=_gate("o/r#9"))])
    assert core.gates(m) == [
        {
            "ref": "o/r#1",
            "kind": "verification",
            "blocked_by": "prose",
            "blocked_by_ref": "o/r#9",
            "resolved_by": "it merges",
        }
    ]


def test_gates_is_sorted_by_ref_and_unmapped_gates_is_a_subset_of_it():
    m = _fixture()
    assert [g["ref"] for g in core.gates(m)] == ["acme/platform#834", "acme/warehouse#293"]
    assert [g["ref"] for g in core.unmapped_gates(m)] == [g["ref"] for g in core.gates(m)]


def test_rows_without_gates_contribute_nothing_to_gates():
    assert core.gates(_manifest([_row("1", "o/r#1")])) == []
    assert core.gates({"rows": "nope"}) == []
    assert core.gates(_manifest([_row("1", "o/r#1", gate="prose")])) == []


# ── looks_like_manifest ──────────────────────────────────────────────────────


@pytest.mark.parametrize(
    "doc,expected",
    [
        ({"rows": []}, True),
        ({"rows": [{"order": "1", "ref": "o/r#1"}]}, True),
        ({"rows": "nope"}, False),
        ({"projects": {}}, False),
        ([], False),
        ("string", False),
        (None, False),
    ],
    ids=["empty-rows", "real-rows", "rows-string", "no-rows", "bare-list", "bare-string", "none"],
)
def test_looks_like_manifest_requires_a_rows_list(doc, expected):
    # The isinstance(dict) guard is load-bearing: a top-level JSON list would raise on .get.
    assert core.looks_like_manifest(doc) is expected


# ── parse_ref / ref_slug ─────────────────────────────────────────────────────


def test_parse_ref_returns_owner_name_and_number_as_exact_substrings():
    assert core.parse_ref("stillpoint-labs/ingle#42") == ("stillpoint-labs", "ingle", "42")


def test_parse_ref_preserves_case_exactly():
    # recon's dedup keys on the raw string, so a case fold would report a slug for a ref that can
    # never match any item.
    assert core.parse_ref("Owner/Repo#12") == ("Owner", "Repo", "12")


def test_parse_ref_preserves_leading_zeros_in_the_number():
    # Returning int 7 would rewrite the ref; the number stays literal digits.
    assert core.parse_ref("o/r#007") == ("o", "r", "007")


@pytest.mark.parametrize(
    "ref",
    [
        "repo#12",
        "PROJ-123",
        "",
        "   ",
        " o/r#1 ",
        "o/r#1\n",
        "o/r",
        "o/r#",
        "o/r#abc",
        "a/b/c#1",
        "/r#1",
        "o/#1",
        "o r/x#1",
        None,
        7,
        ["o/r#1"],
    ],
    ids=[
        "bare-repo",
        "jira-key",
        "empty",
        "whitespace",
        "padded",
        "trailing-newline",
        "no-number",
        "empty-number",
        "non-numeric",
        "two-slashes",
        "leading-slash",
        "empty-name",
        "space-in-owner",
        "none",
        "int",
        "list",
    ],
)
def test_parse_ref_returns_none_rather_than_a_half_parsed_value(ref):
    assert core.parse_ref(ref) is None


def test_ref_slug_rebuilds_the_owner_repo_pair_byte_identically():
    assert core.ref_slug("stillpoint-labs/ingle#42") == "stillpoint-labs/ingle"


def test_ref_slug_is_empty_for_anything_that_is_not_a_full_ref():
    assert core.ref_slug("ingle#42") == ""
    assert core.ref_slug("") == ""


# ── slug_from_remote ─────────────────────────────────────────────────────────


@pytest.mark.parametrize(
    "remote,expected",
    [
        ("git@github.com:owner/repo.git", "owner/repo"),
        ("https://github.com/owner/repo.git", "owner/repo"),
        ("https://github.com/owner/repo", "owner/repo"),
        ("ssh://git@github.com/owner/repo.git", "owner/repo"),
        ("git://github.com/owner/repo.git", "owner/repo"),
        ("https://x-access-token:gho_LIVE_TOKEN@github.com/owner/repo.git", "owner/repo"),
        ("git@github.com:Owner/Repo.git", "Owner/Repo"),
        ("git@github.com:owner/repo.name.git", "owner/repo.name"),
        ("git@github.com:owner/repo.git.git", "owner/repo.git"),
        ("git@github.com:owner/my-repo_2.git", "owner/my-repo_2"),
        ("git@gitlab.com:owner/repo.git", ""),
        ("https://bitbucket.org/owner/repo.git", ""),
        ("../sibling", ""),
        ("mirrors/repo.git", ""),
        ("githubXcom/o", ""),
        ("git@github.com:owner/repo/extra.git", ""),
        ("git@github.com:/repo.git", ""),
        ("git@github.com:owner/.git", ""),
        ("https://github.com/owner/re po.git", ""),
        ("https://github.com/owner", ""),
        ("https://github.com/owner/repo\n", ""),
        ("https://github.com/owner/repo  ", ""),
        (" https://github.com/owner/repo", "owner/repo"),
        ("", ""),
    ],
    ids=[
        "ssh-scp",
        "https-dotgit",
        "https-plain",
        "ssh-url",
        "git-protocol",
        "credentialed",
        "case-preserved",
        "dot-in-name",
        "double-dotgit",
        "dash-and-underscore",
        "gitlab",
        "bitbucket",
        "relative-parent",
        "relative-plain",
        "host-lookalike",
        "too-many-slashes",
        "empty-owner",
        "empty-name",
        "space-in-name",
        "no-slash",
        "trailing-newline",
        "trailing-space",
        "leading-space-is-absorbed-by-the-host-strip",
        "empty",
    ],
)
def test_slug_from_remote_mirrors_the_adapters_rules(remote, expected):
    # A PURE rule table. It used to live in test_shell.py, where each of these cases spawned
    # `git init` + `git remote add` + `git remote get-url` to assert a string->string mapping. The
    # credentialed case is the one that leaked a live token out of the adapter in 2026-08.
    #
    # `relative-parent` and `relative-plain` are the pair that discriminates the github.com host
    # test from the character-class test: `.`, `/` and `-` are all inside GitHub's class and both
    # have exactly one slash, so with the host check deleted they are reported as real slugs --
    # a repository with a relative remote would then select whatever manifest declares
    # `mirrors/repo#N`. `gitlab` and `bitbucket` do NOT discriminate it: their unmatched host
    # prefixes leave `@` and `:` behind, so the character class rejects them either way.
    #
    # `trailing-space` is the case that pins shell._git_origin_url's `rstrip("\n")` against a
    # `.strip()`: trailing whitespace has to SURVIVE the read so the character class can reject it,
    # matching `$(...)` + the adapter's `case`. A LEADING space is a different story and is asserted
    # as accepted, not rejected -- the greedy `^.*github\.com[:/]` strip absorbs it exactly as the
    # adapter's identical sed does, so the two sides agree and neither reads it as a defect.
    assert core.slug_from_remote(remote) == expected


def test_a_slug_from_a_remote_is_the_same_string_a_ref_carries():
    # The two halves of the wire have to agree byte for byte or selection matches nothing.
    assert core.slug_from_remote("git@github.com:stillpoint-labs/ingle.git") == core.ref_slug(
        "stillpoint-labs/ingle#42"
    )


# ── declared_refs ────────────────────────────────────────────────────────────


def test_declared_refs_covers_rows_gates_after_and_the_apex():
    m = _manifest(
        [
            _row("1", "o/a#1", gate=_gate("o/b#2")),
            _row("2", "o/c#3", after=["o/d#4"]),
        ],
        apex={"ref": "o/e#5"},
    )
    assert core.declared_refs(m) == ["o/a#1", "o/b#2", "o/c#3", "o/d#4", "o/e#5"]


def test_declared_refs_includes_after_refs_that_name_no_row_here():
    # This is the case AC3's targeted fetch exists for; leaving it out would mean ready_set could
    # never learn such a parent's state and every forked row would be permanently not-ready.
    m = _manifest([_row("1", "o/a#1", after=["other/repo#99"])])
    assert "other/repo#99" in core.declared_refs(m)


def test_declared_refs_deduplicates_and_sorts():
    m = _manifest([_row("1", "o/b#2"), _row("2", "o/a#1", after=["o/b#2"])])
    assert core.declared_refs(m) == ["o/a#1", "o/b#2"]


def test_declared_refs_does_not_fold_case():
    m = _manifest([_row("1", "Owner/Repo#1"), _row("2", "owner/repo#1")])
    assert core.declared_refs(m) == ["Owner/Repo#1", "owner/repo#1"]


def test_declared_refs_keeps_refs_that_are_not_full_refs():
    # Exactness beats tidiness: a malformed ref is surfaced verbatim, not repaired and not dropped.
    assert core.declared_refs(_manifest([_row("1", "PROJ-123")])) == ["PROJ-123"]


def test_declared_refs_drops_blanks_and_tolerates_a_malformed_manifest():
    assert core.declared_refs(_manifest([_row("1", ""), _row("2", "   ")])) == []
    assert core.declared_refs({"rows": "nope"}) == []
    assert core.declared_refs({"rows": [{"ref": "o/a#1"}], "apex": "not-an-object"}) == ["o/a#1"]


# ── select_for_repository ────────────────────────────────────────────────────


def test_select_for_repository_keeps_a_manifest_that_declares_the_slug():
    m = _manifest([_row("1", "stillpoint-labs/ingle#1")])
    assert core.select_for_repository([m], "stillpoint-labs/ingle") == [m]


def test_select_for_repository_does_not_prefix_match_a_longer_repository_name():
    # THE false positive. `stillpoint-labs/stillpoint-web#1` starts with `stillpoint-labs/stillpoint`,
    # so a raw string-prefix test would render the web repository's manifest under `stillpoint`.
    m = _manifest([_row("1", "stillpoint-labs/stillpoint-web#1")])
    assert core.select_for_repository([m], "stillpoint-labs/stillpoint") == []


def test_select_for_repository_does_not_match_a_different_owner():
    m = _manifest([_row("1", "other-owner/ingle#1")])
    assert core.select_for_repository([m], "stillpoint-labs/ingle") == []


def test_select_for_repository_matches_a_member_repository_not_only_the_host_one():
    # The multi-repository shape: refs span four repositories, so all four select it.
    m = _manifest(
        [
            _row("1", "stillpoint-labs/stillpoint#1", "cutover"),
            _row("2", "stillpoint-labs/ingle#2", "cutover"),
            _row("3", "stillpoint-labs/reveal#3", "cutover"),
            _row("4", "stillpoint-labs/troth#4", "cutover"),
        ]
    )
    for slug in ("stillpoint-labs/stillpoint", "stillpoint-labs/ingle", "stillpoint-labs/reveal"):
        assert core.select_for_repository([m], slug) == [m]


def test_hosting_a_tracker_or_a_blocker_does_not_select_another_projects_grid():
    # The hardened spec binds selection to `rows[].ref`. Scoping on declared_refs instead meant that
    # a repository which merely HOSTS another project's tracker issue -- or is named by one
    # cross-project blocker -- rendered that project's entire grid, none of whose rows belong to it,
    # under a focus header naming it. That is B3's failure class: a wrong answer, not a missing one.
    apex_only = _manifest([_row("1", "o/a#1")], apex={"ref": "o/tracker#9"})
    blocker_only = _manifest([_row("1", "o/a#1", gate=_gate("o/blocker#5"))])
    after_only = _manifest([_row("1", "o/a#1", after=["o/elsewhere#3"])])
    assert core.select_for_repository([apex_only], "o/tracker") == []
    assert core.select_for_repository([blocker_only], "o/blocker") == []
    assert core.select_for_repository([after_only], "o/elsewhere") == []
    # ... and each one still selects from the repository whose rows it actually declares.
    for m in (apex_only, blocker_only, after_only):
        assert core.select_for_repository([m], "o/a") == [m]


def test_the_wider_declaration_set_is_still_what_the_fetch_reads():
    # Narrowing SELECTION must not narrow the FETCH: declared_refs stays the union, because AC3
    # resolves a tracker and an out-of-manifest parent exactly like a row.
    m = _manifest([_row("1", "o/a#1", gate=_gate("o/blocker#5"), after=["o/elsewhere#3"])], apex={"ref": "o/tracker#9"})
    assert core.row_refs(m) == ["o/a#1"]
    assert core.declared_refs(m) == ["o/a#1", "o/blocker#5", "o/elsewhere#3", "o/tracker#9"]


def test_row_refs_deduplicates_sorts_and_drops_blanks():
    m = _manifest([_row("1", "o/b#2"), _row("2", "o/a#1"), _row("3", ""), _row("4", "   ")])
    assert core.row_refs(m) == ["o/a#1", "o/b#2"]
    assert core.row_refs({"rows": "nope"}) == []


def test_select_for_repository_returns_nothing_for_an_empty_slug():
    # A repository with no GitHub origin must render an empty grid, not every manifest borg knows.
    #
    # The manifest's ref is DELIBERATELY unparseable. With a parseable ref, ref_slug can never
    # return "" and the empty-slug guard is never the reason the result is empty -- the test passes
    # with the guard deleted. `PROJ-123` makes ref_slug("") == "" == slug, so only the guard stops it.
    m = _manifest([_row("1", "PROJ-123")])
    assert core.ref_slug("PROJ-123") == "", "the precondition that makes this test discriminate"
    assert core.select_for_repository([m], "") == []
    assert core.select_for_repository([_manifest([_row("1", "o/a#1")])], "") == []


def test_select_for_repository_preserves_input_order_and_object_identity():
    a = _manifest([_row("1", "o/a#1")])
    b = _manifest([_row("1", "o/a#2")])
    selected = core.select_for_repository([a, b], "o/a")
    assert selected == [a, b]
    assert selected[0] is a and selected[1] is b


def test_select_for_repository_ignores_refs_that_do_not_parse():
    m = _manifest([_row("1", "PROJ-123")])
    assert core.select_for_repository([m], "PROJ-123") == []
    assert core.select_for_repository([], "o/a") == []


# ── levels ───────────────────────────────────────────────────────────────────


def _stacked(*pairs):
    return [{"parent": p, "child": c, "kind": "stacked", "source": "declared"} for p, c in pairs]


def test_levels_index_is_the_level_and_a_chain_descends_one_per_step():
    # Rank is the ROW index, deliberately the transpose of render_graph.py's layout(), which puts
    # rank on X. AC2 needs time to flow DOWN.
    assert core.levels(["a", "b", "c"], _stacked(("a", "b"), ("b", "c"))) == [["a"], ["b"], ["c"]]


def test_levels_uses_the_longest_path_not_the_shortest():
    # `a` reaches `c` directly and through `b`; `c` belongs below the LONGER chain.
    edges = _stacked(("a", "b"), ("b", "c"), ("a", "c"))
    assert core.levels(["a", "b", "c"], edges) == [["a"], ["b"], ["c"]]


def test_levels_puts_a_fork_s_two_children_on_the_same_row():
    assert core.levels(["a", "b", "c"], _stacked(("a", "b"), ("a", "c"))) == [["a"], ["b", "c"]]


def test_levels_with_no_edges_is_one_level():
    assert core.levels(["c", "a", "b"], []) == [["a", "b", "c"]]


def test_levels_counts_blocks_edges_as_ordering():
    edges = [{"parent": "a", "child": "b", "kind": "blocks", "source": "declared"}]
    assert core.levels(["a", "b"], edges) == [["a"], ["b"]]


def test_apex_edges_do_not_contribute_to_ranking():
    # An apex points at EVERY row. Counting it would collapse a whole chain into level 1 under the
    # tracker, which is the single most damaging way this could be wrong.
    chain = _stacked(("a", "b"), ("b", "c"))
    apex = [{"parent": "t", "child": r, "kind": "apex", "source": "declared"} for r in ("a", "b", "c")]
    assert core.levels(["t", "a", "b", "c"], chain + apex) == [["a", "t"], ["b"], ["c"]]


def test_an_edge_with_no_kind_contributes_nothing():
    assert core.levels(["a", "b"], [{"parent": "a", "child": "b"}]) == [["a", "b"]]


def test_an_edge_endpoint_outside_refs_invents_no_node():
    levels = core.levels(["b"], _stacked(("a", "b")))
    assert levels == [["b"]]
    assert "a" not in [n for level in levels for n in level]


def test_within_level_ordering_is_ascending_ref_and_deterministic():
    # Deliberate divergence from render_graph.py:670, which sorts by DESCENDING urgency first;
    # urgency is per-item recon state and this function is pure over (refs, edges).
    assert core.levels(["z", "m", "a"], []) == [["a", "m", "z"]]
    assert core.levels(["a", "m", "z"], []) == core.levels(["z", "m", "a"], [])


def test_duplicate_edges_do_not_corrupt_the_indegree_count():
    edges = _stacked(("a", "b")) + _stacked(("a", "b"))
    assert core.levels(["a", "b"], edges) == [["a"], ["b"]]


def test_duplicate_and_blank_refs_are_collapsed():
    assert core.levels(["a", "a", "", "  ", "b"], []) == [["a", "b"]]


def test_levels_of_nothing_is_an_empty_list():
    assert core.levels([], _stacked(("a", "b"))) == []


def test_a_two_node_cycle_terminates_and_places_both_nodes():
    # No hang, no dropped node, and NOT everything parked at level 0 (which is what
    # render_graph.py:659-672 silently does: it computes the Kahn cycle counter and never reads it).
    levels = core.levels(["a", "b"], _stacked(("a", "b"), ("b", "a")))
    assert levels == [["a"], ["b"]]


def test_a_three_node_cycle_with_a_tail_places_every_node_exactly_once():
    edges = _stacked(("a", "b"), ("b", "c"), ("c", "a"), ("c", "d"))
    levels = core.levels(["a", "b", "c", "d"], edges)
    placed = [node for level in levels for node in level]
    assert sorted(placed) == ["a", "b", "c", "d"]
    assert len(placed) == len(set(placed))
    assert len(levels) > 1


def test_a_self_edge_does_not_park_a_node_forever():
    assert core.levels(["a", "b"], _stacked(("a", "a"), ("a", "b"))) == [["a"], ["b"]]


def test_a_cycle_ranking_is_deterministic_across_ref_orderings():
    edges = _stacked(("a", "b"), ("b", "a"))
    assert core.levels(["a", "b"], edges) == core.levels(["b", "a"], edges)


def test_levels_composes_with_derive_edges_over_a_forked_manifest():
    m = _manifest(
        [
            _row("1", "o/r#1", "a"),
            _row("1", "o/r#2", "b", after=["o/r#1"]),
            _row("1", "o/r#3", "c", after=["o/r#1"]),
            _row("2", "o/r#4", "c", after=["o/r#2", "o/r#3"]),
        ]
    )
    assert core.levels(core.declared_refs(m), core.derive_edges(m)) == [
        ["o/r#1"],
        ["o/r#2", "o/r#3"],
        ["o/r#4"],
    ]


# ── ready_set ────────────────────────────────────────────────────────────────


def test_a_row_is_ready_when_it_is_open_and_every_parent_merged():
    m = _manifest([_row("1", "o/r#1"), _row("2", "o/r#2")])
    assert core.ready_set(m, {"o/r#1": "merged", "o/r#2": "open"}) == ["o/r#2"]


def test_a_row_with_no_parents_is_ready_as_soon_as_it_is_open():
    m = _manifest([_row("1", "o/r#1")])
    assert core.ready_set(m, {"o/r#1": "open"}) == ["o/r#1"]


def test_a_row_whose_parent_is_still_open_is_not_ready():
    m = _manifest([_row("1", "o/r#1"), _row("2", "o/r#2")])
    assert core.ready_set(m, {"o/r#1": "open", "o/r#2": "open"}) == ["o/r#1"]


def test_a_row_whose_parent_is_closed_but_not_merged_is_not_ready():
    m = _manifest([_row("1", "o/r#1"), _row("2", "o/r#2")])
    assert core.ready_set(m, {"o/r#1": "closed", "o/r#2": "open"}) == []


def test_an_unknown_parent_state_is_not_merged():
    # Unknown is not merged -- announcing work as startable on the strength of never having looked
    # is exactly the wrong answer AC3 exists to remove.
    m = _manifest([_row("1", "o/r#1"), _row("2", "o/r#2")])
    assert core.ready_set(m, {"o/r#2": "open"}) == []


def test_a_row_with_no_known_state_is_not_ready():
    m = _manifest([_row("1", "o/r#1")])
    assert core.ready_set(m, {}) == []
    assert core.ready_set(m, {"o/r#1": None}) == []


def test_a_merged_row_is_not_ready_because_ready_means_open():
    m = _manifest([_row("1", "o/r#1")])
    assert core.ready_set(m, {"o/r#1": "merged"}) == []


def test_a_parent_outside_this_manifest_still_gates_the_row():
    m = _manifest([_row("1", "o/r#2", after=["other/repo#99"])])
    assert core.ready_set(m, {"o/r#2": "open"}) == []
    assert core.ready_set(m, {"o/r#2": "open", "other/repo#99": "open"}) == []
    assert core.ready_set(m, {"o/r#2": "open", "other/repo#99": "merged"}) == ["o/r#2"]


def test_a_declared_blocker_gates_the_row_the_same_way_a_lane_parent_does():
    m = _manifest([_row("1", "o/r#2", gate=_gate("o/r#9"))])
    assert core.ready_set(m, {"o/r#2": "open"}) == []
    assert core.ready_set(m, {"o/r#2": "open", "o/r#9": "merged"}) == ["o/r#2"]


def test_an_apex_parent_does_not_gate_a_row():
    # apex is not an ordering kind; if it gated, no row would ever be ready under a tracker.
    m = _manifest([_row("1", "o/r#1")], apex={"ref": "o/tracker#9"})
    assert core.ready_set(m, {"o/r#1": "open", "o/tracker#9": "open"}) == ["o/r#1"]


def test_a_fork_announces_both_children_at_once():
    m = _manifest(
        [
            _row("1", "o/r#1", "a"),
            _row("1", "o/r#2", "b", after=["o/r#1"]),
            _row("1", "o/r#3", "c", after=["o/r#1"]),
        ]
    )
    states = {"o/r#1": "merged", "o/r#2": "open", "o/r#3": "open"}
    assert core.ready_set(m, states) == ["o/r#2", "o/r#3"]


def test_ready_set_tolerates_the_raw_graphql_enum_casing():
    # The adapter downcases at :179; this only guards a caller handing over the raw enum. It adds no
    # token the adapter cannot emit.
    m = _manifest([_row("1", "o/r#1"), _row("2", "o/r#2")])
    assert core.ready_set(m, {"o/r#1": "MERGED", "o/r#2": "OPEN"}) == ["o/r#2"]


def test_ready_set_of_an_empty_manifest_is_empty():
    assert core.ready_set({"rows": []}, {"o/r#1": "open"}) == []
