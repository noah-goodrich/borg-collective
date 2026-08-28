"""Tests for AC2's pure picture module: columns, connectors, glyphs, hyperlinks and width.

THE ORACLES ARE HAND-AUTHORED AND PREDATE THE CODE. `tests/fixtures/link/picture-fork.expected` is
transcribed from the approved mock at ~/.local/state/borg/merge-tree/chains-dag-mock.md, and
`picture-crossing.expected` was computed by hand from the connector rules before this module ran
once. NEITHER IS WRITABLE BY BORG_UPDATE_GOLDEN, deliberately: the whole reason they exist is that
the rail rule shipped into this repo's spec with a defect (it counted a boundary's downward strokes
over jogging segments only, which renders the mock's own fan-out as `└┬┐` instead of `├┬┐`), and a
regenerable fixture would simply re-freeze the next such defect as its own oracle.

Every case names the MUTATION that turns it red, because the carried-forward finding from
2026-08-26 is that a check pointed at the wrong thing does not fail -- it reads as a pass.
"""

from __future__ import annotations

import ast
import re
from pathlib import Path

from borg_core.link import grid as link_grid
from borg_core.link import picture
from borg_core.manifest import core as manifest_core

FIXTURES = Path(__file__).resolve().parents[2] / "tests" / "fixtures" / "link"

_ESCAPES = re.compile(r"\033\]8;;[^\033]*\033\\|\033\[[0-9;]*m")


def plain(text: str) -> str:
    """`text` with every SGR and OSC-8 sequence removed -- what actually prints."""
    return _ESCAPES.sub("", text)


def swept(manifest: dict) -> dict[str, dict]:
    """Every row's OWN declared state, handed back as though the sweep had answered it.

    THE TOPOLOGY ORACLES NEED THIS AND IT IS NOT A CHEAT. `picture-fork.expected` and
    `picture-crossing.expected` are hand-authored to pin the COLUMN ALGORITHM and the connector/rail
    rules. Built with `{}, {}` every node resolves `declared` or `unknown`, so AC4's precondition
    stamps `?` in the cell's second slot and both oracles fail for a reason that has nothing to do
    with what they were authored to check. This holds the PROVENANCE axis constant so the TOPOLOGY
    axis is what is being measured.

    MIRRORS `status` RATHER THAN FLATTENING IT. An earlier version answered every ref `open`, which
    resolved provenance and simultaneously destroyed the states the oracles encode -- `picture-fork
    .expected`'s first cell is `✔`, because the mock's trunk row declares `status="merged"`. Echoing
    each row's own token changes the SOURCE and nothing else, which is exactly the isolation wanted.

    Provenance itself is measured directly, on its own fixtures, by the AC4-precondition cases below.
    """
    return {row["ref"]: {"state": row["status"]} for row in manifest.get("rows") or [] if row.get("status")}


def render(manifest: dict) -> list[str]:
    """One manifest all the way to picture rows, escapes stripped. The whole pipeline, no CLI."""
    block = link_grid.grid_manifest(manifest, swept(manifest), {})
    columns = picture.assign_columns(block)
    ids = picture.node_ids([block], [columns])
    return [plain(row) for row in picture.picture(block, ids, columns)]


def columns_of(manifest: dict) -> dict[str, int]:
    return picture.assign_columns(link_grid.grid_manifest(manifest, swept(manifest), {}))


def _row(order: int, ref: str, **extra) -> dict:
    row = {"order": str(order), "ref": ref, "lane": "L"}
    row.update(extra)
    return row


def fork_manifest() -> dict:
    """The approved mock, as a manifest. One trunk, three branches, a three-parent join.

    `infra#12` (the third branch) has no intermediate row, so its edge to the join SKIPS a level --
    which is what puts a lone pass-through `│` beside the n5/n6 row in the mock and here.
    """
    return {
        "program": "auth-hardening",
        "desc": "Rotate every service onto scoped keypair auth, then flip enforcement on in one release.",
        "rows": [
            _row(1, "acme/platform#400", status="merged", why="base migration"),
            _row(2, "acme/platform#420", after=["acme/platform#400"], status="open", why="add auth scopes"),
            _row(3, "acme/warehouse#87", after=["acme/platform#400"], status="open", why="rotate the keypair"),
            _row(4, "acme/infra#12", after=["acme/platform#400"], status="open", why="inventory services"),
            _row(5, "acme/platform#431", after=["acme/platform#420"], status="open", why="enforce scopes"),
            _row(6, "acme/warehouse#93", after=["acme/warehouse#87"], status="open", why="cut consumers over"),
            _row(
                7,
                "acme/infra#77",
                after=["acme/platform#431", "acme/warehouse#93", "acme/infra#12"],
                status="open",
                why="flip enforcement flag",
                gate={
                    "kind": "verification",
                    "blocked_by": "staged rollout run must pass",
                    "resolved_by": "canary deploy green for 24h",
                },
            ),
        ],
    }


def crossing_manifest() -> dict:
    """A pass-through INTERIOR to a rail's span -- the one shape a pure 4-bit mask gets wrong.

    `q#3` forks off the trunk with the others but joins at the LAST node, so its column sits between
    the two endpoints of the `p#2 -> z#5` rail at the level that rail is drawn. It merges into
    nothing there, and drawing it as a junction would assert a dependency that does not exist.
    """
    return {
        "program": "crossing",
        "rows": [
            _row(1, "a/r#1", status="merged", why="the trunk"),
            _row(2, "a/p#2", after=["a/r#1"], status="open", why="left branch"),
            _row(3, "a/q#3", after=["a/r#1"], status="open", why="the pass-through"),
            _row(4, "a/s#4", after=["a/r#1"], status="open", why="right branch"),
            _row(5, "a/z#5", after=["a/p#2", "a/s#4"], status="open", why="first join"),
            _row(6, "a/w#6", after=["a/z#5", "a/q#3"], status="open", why="last join"),
        ],
    }


# ── columns ───────────────────────────────────────────────────────────────────────────────────────


def test_a_linear_chain_is_one_column():
    """P1. MUTATION: replace inheritance with "smallest free column" -- still passes here, which is
    why P2 exists; but drop the reservation and a chain still holds column 0, so this case pins the
    floor rather than the interesting property."""
    manifest = {"rows": [_row(i, f"o/r#{i}", after=[f"o/r#{i - 1}"] if i > 1 else None) for i in range(1, 5)]}
    for row in manifest["rows"]:
        if row.get("after") is None:
            row.pop("after", None)
    assert set(columns_of(manifest).values()) == {0}


def interleaved_lanes_manifest() -> dict:
    """The live `ingle-t1-cutover` level structure, reduced and checked in.

    TRANSCRIBED FROM THE REAL FILE, not invented: two lanes of six and eight rows whose refs
    interleave across levels under ascending-ref ordering. Measured on
    /Users/noah/dev/stillpoint/.borg/programs/ingle-t1-cutover.json, `levels()` yields
    `[stillpoint#37, stillpoint#54]` at level 0 (cutover first) but `[ingle#341, stillpoint#39]` at
    level 2 and `[reveal#59, stillpoint#40]` at level 3 (contract first), swapping back at level 4 --
    four crossings in an eight-level picture with no edge crossing anything.

    CHECKED IN RATHER THAN READ FROM DISK. The first version of this case read the live path and
    called `pytest.skip` when it was absent, which means the single measurement justifying `seq`
    silently stopped running on CI, on any second machine, and the day that file moves. A skip is a
    pass. It is also the only thing in borg_core/ that would have opened a file outside the repo.
    """
    cutover = [
        "stillpoint#37",
        "stillpoint#33",
        "stillpoint#39",
        "stillpoint#40",
        "stillpoint#50",
        "stillpoint#48",
        "stillpoint#58",
        "ingle#330",
    ]
    contract = ["stillpoint#54", "stillpoint#55", "ingle#341", "reveal#59", "troth#83", "stillpoint#57"]
    rows = []
    for lane, refs in (("cutover", cutover), ("contract", contract)):
        for index, ref in enumerate(refs):
            rows.append({"order": str(index + 1), "ref": f"stillpoint-labs/{ref}", "lane": lane})
    return {"program": "ingle-t1-cutover", "rows": rows}


def test_two_lanes_never_swap_columns_when_refs_sort_across_them():
    """P2. The reason `seq` exists at all.

    MUTATION: place by within-level index (ascending ref) instead of by `seq`. The lanes then swap
    columns at four of the eight levels, and a reader following one workstream down the page has to
    change columns four times for no declared reason.
    """
    block = link_grid.grid_manifest(interleaved_lanes_manifest(), {}, {})
    columns = picture.assign_columns(block)

    # The premise, asserted rather than assumed: ascending-ref order really does interleave the two
    # lanes. Without this, the case would still pass on a fixture where the two orders agree -- and
    # would therefore prove nothing about `seq`.
    lane_of = {ref: node["lane"] for ref, node in block["nodes"].items()}
    per_level = [[lane_of[ref] for ref in refs] for refs in block["levels"]]
    assert [level[0] for level in per_level[:5]] == ["cutover", "cutover", "contract", "contract", "cutover"]

    by_lane: dict[str, set[int]] = {}
    for ref, node in block["nodes"].items():
        by_lane.setdefault(node["lane"], set()).add(columns[ref])
    assert by_lane == {"contract": {0}, "cutover": {1}}, "each lane must hold exactly one column"


def test_a_fork_whose_children_are_all_leaves_still_spreads():
    """P3. MUTATION: `range(L, span_end(n))` without the `max(..., L + 1)`.

    `span_end` of a childless node is its own level, so the naive range is EMPTY for a leaf and never
    marks the leaf's own column used at its own level -- both children then take column 0 and two
    nodes occupy one cell. Neither live manifest nor the approved mock reaches this, because every
    one of the mock's fork children has a child of its own.
    """
    manifest = {
        "rows": [
            _row(1, "o/r#1"),
            _row(2, "o/r#2", after=["o/r#1"]),
            _row(3, "o/r#3", after=["o/r#1"]),
        ]
    }
    columns = columns_of(manifest)
    assert columns["o/r#2"] != columns["o/r#3"], "two leaf children may not share a column"
    assert sorted([columns["o/r#2"], columns["o/r#3"]]) == [0, 1]


def assert_nothing_sits_on_a_wire(manifest: dict) -> int:
    """NOTHING MAY OCCUPY A COLUMN A SKIP-LEVEL EDGE IS TRAVELLING DOWN. Returns how many it checked.

    THE invariant behind column reservation, asserted directly rather than through a proxy. An edge
    spanning more than one boundary holds its parent's column straight down and jogs only at the last
    boundary (`_segments`), so any node placed in that column at an intermediate level has a
    connector drawn through its cell -- a picture that reads as a dependency nobody declared.

    Written as a general property over EVERY skip-level edge rather than as an assertion about one
    hand-picked pair: the first version of this test compared two refs that differed under the
    mutation as well as without it, so it stayed green with the reservation deleted.
    """
    block = link_grid.grid_manifest(manifest, {}, {})
    columns = picture.assign_columns(block)
    ranks = picture.level_of(block)

    spanning = [(p, c) for p, c in picture.ordering_pairs(block) if ranks[c] - ranks[p] >= 2]
    for parent, child in spanning:
        for ref, rank in ranks.items():
            if ranks[parent] < rank < ranks[child]:
                assert columns[ref] != columns[parent], f"{ref} sits on the {parent} -> {child} wire"
    return len(spanning)


def test_a_skip_level_edge_reserves_its_column_through_the_gap():
    """P4. MUTATION: reserve only the node's own level (`range(L, L + 1)`).

    The fixture's trunk has BOTH a near child and a child three levels down, which is what makes the
    reservation load-bearing: without it the near child inherits the trunk's column and the long edge
    is drawn straight through its cell. The approved mock does NOT exercise this -- its skip-level
    edge leaves a node whose column nothing else competes for -- so the mock golden alone would have
    let the mutation through, which is exactly what it did.
    """
    manifest = {
        "rows": [
            _row(1, "o/r#1"),
            _row(2, "o/r#2", after=["o/r#1"]),
            _row(3, "o/r#3", after=["o/r#2"]),
            _row(4, "o/r#4", after=["o/r#3", "o/r#1"]),
            _row(5, "o/r#9", after=["o/r#2"]),
        ]
    }
    assert assert_nothing_sits_on_a_wire(manifest) >= 1, "the fixture must contain a skip-level edge"

    # And the same property must hold for both hand-authored fixtures, which carry skip-level edges
    # of their own -- so the invariant is checked on the shapes the goldens pin, not only here.
    assert assert_nothing_sits_on_a_wire(fork_manifest()) >= 1
    # The return value is the guard against vacuous success -- if a fixture ever loses its
    # skip-level edge, `spanning` is empty, the loop body never runs, and the call asserts NOTHING
    # while still reading as a check. Every call site must therefore assert the count.
    assert assert_nothing_sits_on_a_wire(crossing_manifest()) >= 1


def test_a_join_lands_on_the_median_of_its_parents():
    """P5. MUTATION: `min(parent_columns)` -- the join then hugs the left edge instead of centring.

    THREE parents at columns 0/1/2 put the join at 1, which is the approved mock's own geometry. The
    TWO-parent case is pinned as well because `len // 2` takes the UPPER of two central columns and
    the phrase "lower median" was attached to that formula in the spec; the formula is what ships and
    this is what stops it drifting on a reading of the prose.
    """
    three = {
        "rows": [
            _row(1, "o/r#1"),
            _row(2, "o/r#2", after=["o/r#1"]),
            _row(3, "o/r#3", after=["o/r#1"]),
            _row(4, "o/r#4", after=["o/r#1"]),
            _row(5, "o/r#5", after=["o/r#2", "o/r#3", "o/r#4"]),
        ]
    }
    columns = columns_of(three)
    assert sorted([columns["o/r#2"], columns["o/r#3"], columns["o/r#4"]]) == [0, 1, 2]
    assert columns["o/r#5"] == 1

    two = {
        "rows": [
            _row(1, "o/r#1"),
            _row(2, "o/r#2", after=["o/r#1"]),
            _row(3, "o/r#3", after=["o/r#1"]),
            _row(4, "o/r#4", after=["o/r#2", "o/r#3"]),
        ]
    }
    assert columns_of(two)["o/r#4"] == 1


def test_declaration_order_breaks_within_level_ties_not_ascending_ref():
    """P6. MUTATION: tie-break on `ref`. The mock's fork order inverts to infra, platform, warehouse.

    Asserted on the APPROVED MOCK's own refs, where ascending ref and declaration order genuinely
    disagree: `acme/infra#12` is declared third and sorts first.
    """
    columns = columns_of(fork_manifest())
    assert columns["acme/platform#420"] == 0
    assert columns["acme/warehouse#87"] == 1
    assert columns["acme/infra#12"] == 2


def test_a_level_never_mixes_parentless_and_inheriting_nodes():
    """The invariant that lets `_level_plan` drop its inheritor-before-orphan grouping term.

    Longest-path ranking puts every node with no descending parent at rank 0, and a node at rank
    L > 0 got there by relaxation from a parent at a lower rank -- a descending parent by definition.
    So a level is homogeneous: all orphans (level 0) or all inheritors (below it).

    MUTATION: none in `picture.py` -- this pins `manifest_core.levels()`. A ranking change that
    seated a parentless node below level 0 would make placement order matter again, and the
    grouping term this documents the removal of would have to come back. Checked across an acyclic
    fork, two independent lane heads, and a CYCLE (where the broken edge leaves a node whose only
    declared parent is not drawn), because the cycle case is the one that looks like it should
    produce a mixed level and does not.
    """
    cases = {
        "fork": {"rows": [_row(1, "o/a#1"), _row(2, "o/b#2", after=["o/a#1"]), _row(3, "o/c#3", after=["o/a#1"])]},
        "two lane heads": {
            "rows": [
                {"order": "1", "ref": "o/a#1", "lane": "A"},
                {"order": "1", "ref": "o/b#2", "lane": "B"},
                {"order": "2", "ref": "o/c#3", "lane": "A", "after": ["o/a#1"]},
            ]
        },
        "cycle beside a chain": {
            "rows": [
                {"order": "1", "ref": "o/a#1", "lane": "A", "after": ["o/c#3"]},
                {"order": "2", "ref": "o/b#2", "lane": "A", "after": ["o/a#1"]},
                {"order": "3", "ref": "o/c#3", "lane": "A", "after": ["o/b#2"]},
                {"order": "1", "ref": "o/x#9", "lane": "B"},
                {"order": "2", "ref": "o/y#8", "lane": "B", "after": ["o/x#9"]},
            ]
        },
    }
    saw_cycle = False
    for name, manifest in cases.items():
        block = link_grid.grid_manifest(manifest, {}, {})
        _, _, parents_of, _ = picture._forward(block)
        saw_cycle = saw_cycle or bool(picture.back_edges(block))
        for index, refs in enumerate(block["levels"]):
            kinds = {bool(parents_of.get(ref)) for ref in refs}
            assert len(kinds) == 1, f"{name}: level {index} mixes parentless and inheriting nodes"
            assert kinds == {index > 0}, f"{name}: level {index} is on the wrong side of the rank-0 rule"
    assert saw_cycle, "one case must actually be cyclic, or the hardest arm went untested"


def test_a_cycle_broken_graph_places_every_node_and_draws_no_back_edge():
    """P7. MUTATION: raise on a back edge instead of excluding it.

    manifest_core._rank_nodes breaks a cycle by admitting the smallest remaining ref rather than
    raising, so a cyclic manifest still ranks -- and one edge necessarily fails to descend. Every
    node must still get a column, and the non-descending edge must not be drawn.
    """
    manifest = {
        "rows": [
            _row(1, "o/r#1", after=["o/r#3"]),
            _row(2, "o/r#2", after=["o/r#1"]),
            _row(3, "o/r#3", after=["o/r#2"]),
        ]
    }
    block = link_grid.grid_manifest(manifest, {}, {})
    columns = picture.assign_columns(block)

    assert set(columns) == {"o/r#1", "o/r#2", "o/r#3"}, "no node may be dropped"
    assert picture.back_edges(block), "the fixture must actually contain a cycle"
    ranks = picture.level_of(block)
    for parent, child in picture.ordering_pairs(block):
        assert ranks[parent] < ranks[child], "a drawn edge must descend"
    assert render(manifest), "a cyclic manifest still renders"


# ── connectors ────────────────────────────────────────────────────────────────────────────────────


def test_the_approved_mock_fork_and_join_rows():
    """P8. The whole picture, byte for byte, against the hand-transcribed mock.

    MUTATION: any `_BOX` entry, any offset constant, or the jogging-only stroke rule the spec was
    written with -- which renders this fan-out as `└┬┐` and this join as `└┬┘`.
    """
    expected = FIXTURES.joinpath("picture-fork.expected").read_text(encoding="utf-8").rstrip("\n").split("\n")
    assert render(fork_manifest()) == expected


def test_a_pass_through_interior_to_a_rail_is_not_drawn_as_a_join():
    """P9. MUTATION: drop the `crossing` arm (the column renders `─`, severing the wire), or widen
    `involved` to every segment rather than the jogging ones (it renders `┼`, asserting a merge that
    does not happen). Both are wrong in different directions and both turn this red.
    """
    expected = FIXTURES.joinpath("picture-crossing.expected").read_text(encoding="utf-8").rstrip("\n").split("\n")
    rows = render(crossing_manifest())
    assert rows == expected

    rail = next(row for row in rows if "└" in row and "┤" in row)
    assert "│" in rail, "the pass-through keeps its own vertical stroke"
    assert "┼" not in rail, "a pass-through is not a junction"


def test_the_pre_rail_stem_carries_parents_and_the_post_rail_stem_carries_children():
    """P10. MUTATION: use one column set for both stem rows.

    Above a fan-out there is exactly ONE edge, so the upper stem is a single `│`; below it there are
    three. Sharing a set renders `│ │ │` above the fan-out, which claims three parents.
    """
    rows = render(fork_manifest())
    assert rows[1] == "    │", "one stem above the fan-out"
    assert rows[3].count("│") == 3, "three stems below it"


# ── vocabulary ────────────────────────────────────────────────────────────────────────────────────


def test_open_is_open_without_ready_and_ready_with_it():
    """P11. MUTATION: delete the `node.get("ready") is True` branch.

    `ready` is AC4's field and grid.py does not emit it, so the `●` branch ships DEAD -- covered here
    with the field present so the coverage floor holds and AC4 flips data rather than code.
    """
    assert picture.state_glyph({"state": "open"}) == picture.GLYPH_OPEN
    assert picture.state_glyph({"state": "open", "ready": True}) == picture.GLYPH_READY
    # A JSON `false` and the string "true" must both read as "not ready" -- the jq `//` trap.
    assert picture.state_glyph({"state": "open", "ready": False}) == picture.GLYPH_OPEN
    assert picture.state_glyph({"state": "open", "ready": "true"}) == picture.GLYPH_OPEN


def test_draft_lights_up_from_an_absent_field():
    """P12. MUTATION: delete the `draft` branch. Also dead in AC2; `isDraft` is selected by the fetch
    query already, so emitting it later is a one-line change with no renderer edit."""
    assert picture.state_glyph({"state": "open", "draft": True}) == picture.GLYPH_DRAFT
    assert picture.state_glyph({"state": "open"}) != picture.GLYPH_DRAFT


def test_a_state_token_nobody_recognizes_takes_the_default_arm():
    """P13. MUTATION: replace the default arm with a dict lookup -> KeyError.

    Three live tokens, not one hypothetical: the grid's own unresolved token, an injected adapter's
    vocabulary (`resolve_state` passes a swept token through verbatim), and `stacked`, which the LIVE
    viz manifest declares on every row.
    """
    # `state_source` IS SUPPLIED ON EVERY NODE HERE, and it is load-bearing rather than noise. AC4's
    # precondition makes `state_word` return "" for unresolved provenance, so without a resolved
    # source the `== ""` assertions below would pass for the WRONG REASON — proving the provenance
    # gate fires, not that the token took the default arm — and the two `!= ""` assertions would fail.
    # That is the "a check pointed at the wrong thing reads as a pass" trap this module's docstring
    # names, arriving from one module over.
    for token in (link_grid.GRID_STATE_UNKNOWN, "in_progress", "stacked", "", None):
        node = {"state": token, "state_source": link_grid.STATE_SOURCE_SWEPT}
        assert picture.state_glyph(node) == picture.GLYPH_OPEN
        assert picture.state_word(node) == ""
    assert picture.state_word({"state": "merged", "state_source": link_grid.STATE_SOURCE_SWEPT}) == "MERGED"
    assert picture.state_word({"state": "closed", "state_source": link_grid.STATE_SOURCE_FETCHED}) == "CLOSED"


def test_the_state_sentence_names_a_condition_and_never_an_adapter():
    """MUTATION: write "from the github sweep" (or any adapter name) into `_STATE_SENTENCE`.

    `swept_items` merges every adapter's items first-writer-wins with NO back-pointer to which
    adapter supplied one, and the injected employer layer (Slack/Jira/Notion) is a live source of items
    on the work machine. Naming an adapter would therefore be FABRICATED PROVENANCE on the single
    line whose entire job is provenance -- and it would be fabricated in the direction of sounding
    more authoritative, which is the worst direction. The module docstring asserts this in prose;
    this is what makes it hold.
    """
    sentences = [
        picture.state_line({"state_source": source})
        for source in (
            link_grid.STATE_SOURCE_SWEPT,
            link_grid.STATE_SOURCE_FETCHED,
            link_grid.STATE_SOURCE_DECLARED,
            link_grid.STATE_SOURCE_UNKNOWN,
        )
    ]
    assert len(set(sentences)) == 4, "each rung of the ladder reads differently"
    # WORD BOUNDARIES, not substrings. A bare `"gh" in sentence` matches "through", "right",
    # "highest" and "eight" -- the current wording survives it by luck, and the first rewording that
    # said "the answer came through the sweep" would turn this red for no reason.
    for sentence in sentences:
        for name in ("github", "gh", "slack", "jira", "notion", "adapter"):
            assert not re.search(rf"\b{name}\b", sentence.lower()), (name, sentence)

    # An absent or unrecognized state_source degrades to the honest sentence, never to a swept one.
    assert picture.state_line({}) == picture.state_line({"state_source": link_grid.STATE_SOURCE_UNKNOWN})
    assert picture.state_line({"state_source": "invented"}) == sentences[3]


def test_a_merged_child_under_an_unmerged_parent_carries_the_drift_mark():
    """P14. MUTATION: delete `drift_parents`.

    A merged child ranked below an unmerged parent means the declaration and reality disagree. The
    picture cannot say that with position -- ranking reads the declaration -- so without the mark it
    silently contradicts the states printed inside it.
    """
    nodes = {
        "o/r#1": {"ref": "o/r#1", "state": "open", "parents": [], "children": ["o/r#2"]},
        "o/r#2": {"ref": "o/r#2", "state": "merged", "parents": ["o/r#1"], "children": []},
    }
    assert picture.drift_parents(nodes["o/r#2"], nodes) == ["o/r#1"]
    assert picture.drift_parents(nodes["o/r#1"], nodes) == []

    # A parent nobody resolved is NOT drift -- `unknown` is not `open`, and treating it as one would
    # stamp `!` across every `--local` render, where by construction nothing was looked up.
    nodes["o/r#1"]["state"] = link_grid.GRID_STATE_UNKNOWN
    assert picture.drift_parents(nodes["o/r#2"], nodes) == []

    block = picture.detail_block(nodes["o/r#2"], "n2", nodes, {})
    nodes["o/r#1"]["state"] = "open"
    drifted = picture.detail_block(nodes["o/r#2"], "n2", nodes, {})
    assert not any("drift:" in plain(line) for line in block)
    assert any("drift:" in plain(line) for line in drifted)


# ── hyperlinks ────────────────────────────────────────────────────────────────────────────────────


def test_the_url_is_always_the_issues_form():
    """P15. MUTATION: `/pull/`. GitHub redirects /issues/<n> to /pull/<n> for a PR but not the
    reverse, so the issues form is correct for both and the renderer never has to know which."""
    assert picture.ref_url("acme/platform#400") == "https://github.com/acme/platform/issues/400"
    assert "/pull/" not in picture.ref_url("acme/platform#400")


def test_the_sequence_terminates_with_st_not_bel():
    """P16. MUTATION: `\\a`. BEL is widely tolerated but would put a literal 0x07 into two goldens,
    invisible in a diff and audible on every `cat`."""
    linked = picture.osc8("https://example.test/x", "text")
    assert linked == "\033]8;;https://example.test/x\033\\text\033]8;;\033\\"
    assert "\a" not in linked


def test_a_ref_parse_ref_rejects_renders_as_plain_text():
    """P17. MUTATION: fabricate a URL from the raw string -- which silently links to the wrong
    repository, strictly worse than not linking. Also the escape-injection gate: an OSC-8 payload is
    interpreted by the emulator, so an unvalidated ref would be terminal control input."""
    for bad in ("ingle#12", "not a ref", "", "a/b/c#1", "o/r#abc", 'x";evil'):
        assert picture.ref_url(bad) == ""
        assert picture.link_ref(bad, "cell") == "cell"
    assert manifest_core.parse_ref("acme/platform#400") is not None
    assert picture.link_ref("acme/platform#400", "cell") != "cell"


# ── purity, width and the unresolved token ────────────────────────────────────────────────────────


def test_neither_picture_nor_its_helpers_name_the_grid_unresolved_token():
    """P18 (structural). MUTATION: write `if node["state"] == "unknown"` anywhere in picture.py.

    AC3 landed before AC2 so the renderer could be written against an already-truthful document. The
    token is compared through `grid.STATE_SOURCE_UNKNOWN` where it must be compared at all, so the
    two modules cannot drift and this grep stays meaningful. (render.py's own half of this rule
    arrives with AC2/S3, which introduces the named constant for its five jq-parity fallbacks.)
    """
    source = Path(picture.__file__).read_text(encoding="utf-8")
    body = "\n".join(line for line in source.split("\n") if not line.strip().startswith("#"))
    docstringless = re.sub(r'""".*?"""', "", body, flags=re.DOTALL)
    assert '"unknown"' not in docstringless
    assert "'unknown'" not in docstringless


def test_a_node_nobody_answered_for_still_renders_its_id_and_names_the_condition():
    """P19 (behavioural). MUTATION: drop the node instead of naming the condition.

    The structural test above passes just as well if the renderer builds the string by concatenation;
    this one passes only if the node survives to the page AND the sentence explains it. `--local`
    (the fzf preview, `drone status`, `borg watch`) opts down from both network rungs, so this is the
    hot path, not an edge case.
    """
    node = {
        "ref": "o/r#1",
        "state": link_grid.GRID_STATE_UNKNOWN,
        "state_source": link_grid.STATE_SOURCE_UNKNOWN,
        "parents": [],
        "children": [],
    }
    lines = [plain(line) for line in picture.detail_block(node, "n1", {"o/r#1": node}, {})]
    assert any("n1" in line for line in lines)
    assert any("o/r#1" in line for line in lines)
    assert any("nobody has an answer" in line for line in lines)
    assert not any("unknown" in line.lower() for line in lines)


def test_picture_imports_no_impure_module():
    """P20. AST walk for os / subprocess / open / time / datetime / isatty.

    MUTATION: add `os.environ.get("COLUMNS")` to `assign_columns`. `make lint` alone does NOT catch
    that today unless "picture.py" is in pyproject's clean-arch Domain map -- the linter's import
    check returns early on an unclassified file, so this asserts the property directly rather than
    trusting the configuration to be right.
    """
    tree = ast.parse(Path(picture.__file__).read_text(encoding="utf-8"))
    imported: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            imported.update(alias.name.split(".")[0] for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.module:
            imported.add(node.module.split(".")[0])
    assert not imported & {"os", "subprocess", "time", "datetime", "pathlib", "shutil", "socket"}

    called = {n.func.id for n in ast.walk(tree) if isinstance(n, ast.Call) and isinstance(n.func, ast.Name)}
    assert "open" not in called
    attributes = {n.attr for n in ast.walk(tree) if isinstance(n, ast.Attribute)}
    assert "isatty" not in attributes


def test_visible_width_is_identical_with_and_without_hyperlinks():
    """P21. MUTATION: pad on the raw string.

    OSC-8 sequences are zero-width but they are BYTES, so padding with `len()` on the wrapped string
    shifts every later column right by the length of a URL -- invisible in a diff, obvious on screen.
    This is the single most likely alignment bug in the module.
    """
    bare = "platform#400"
    linked = picture.link_ref("acme/platform#400", bare)
    assert picture.visible_len(linked) == len(bare)
    assert len(linked) > len(bare)
    assert picture.visible_len(f"{picture.GREEN}✔{picture.NC} {linked}") == len(bare) + 2

    # And the property the padding actually depends on: every rendered row is aligned on VISIBLE
    # columns, so two rows of one picture agree on where each column starts.
    rows = render(fork_manifest())
    fork_row = next(row for row in rows if "n2" in row)
    assert fork_row.index("n3") - fork_row.index("n2") == fork_row.index("n4") - fork_row.index("n3")


def test_every_picture_row_in_both_fixture_manifests_fits_the_budget():
    """P22. MUTATION: raise a fixture ref past PICTURE_BUDGET.

    The budget is a CONSTANT checked against fixtures, not a terminal probe -- this module is pure.
    That is the honest boundary of the guarantee, and the manifest nobody has written yet is now
    covered by `max_row_width` plus the `--json`-side check in `cli._grid` (the case below), rather
    than left filed as a follow-up.
    """
    for manifest in (fork_manifest(), crossing_manifest()):
        block = link_grid.grid_manifest(manifest, {}, {})
        columns = picture.assign_columns(block)
        ids = picture.node_ids([block], [columns])
        for row in picture.picture(block, ids, columns):
            assert picture.visible_len(row) <= picture.PICTURE_BUDGET, row


def test_a_manifest_whose_refs_run_long_in_three_columns_exceeds_the_budget():
    """P22b. The measurement P22 could not make: a shape nobody has authored yet.

    MUTATION: measure `len(row)` instead of `visible_len(row)` inside `max_row_width`. Every row
    carries SGR bytes, so the helper then reports every manifest -- including the two P22 proves fit
    -- as over budget. The `fits` assertion below is what makes that mutation red rather than merely
    conservative; the `> BUDGET` one alone would go green under it.

    THE WIDTH IS PINNED AT 71, NOT ASSERTED AS "MORE THAN 68", so a silent change to the column pitch
    is a reviewable diff rather than a number nobody re-derives. A fan-out row is
    `INDENT + (N-1)*(pitch) + (W+7)` visible columns for N children of one parent; three children of
    `acme/warehouse#1000` with 14-character short refs comes to 71, three over.
    """
    wide = link_grid.grid_manifest(
        {
            "program": "over-budget",
            "rows": [
                _row(1, "acme/warehouse#1000"),
                _row(2, "acme/warehouse#1001", after=["acme/warehouse#1000"]),
                _row(3, "acme/warehouse#1002", after=["acme/warehouse#1000"]),
                _row(4, "acme/warehouse#1003", after=["acme/warehouse#1000"]),
            ],
        },
        {},
        {},
    )
    assert picture.max_row_width([wide]) == 71 > picture.PICTURE_BUDGET

    # ...and the shapes that DO exist stay under it, so the helper is not a constant `True`.
    fits = [link_grid.grid_manifest(m, {}, {}) for m in (fork_manifest(), crossing_manifest())]
    assert 0 < picture.max_row_width(fits) <= picture.PICTURE_BUDGET

    # An empty board has a picture zero columns wide, not an error.
    assert picture.max_row_width([]) == 0


def test_short_refs_fall_back_to_full_refs_when_two_owners_share_a_repo_name():
    """P23. MUTATION: drop the collision check -- two DIFFERENT pull requests then render as the same
    cell text, which is a wrong answer rather than an ugly one.

    All-or-nothing for the manifest rather than per-ref: shortening one and not the other would fix
    the ambiguity while leaving two cells whose widths no longer come from one rule, so the columns
    stop aligning.
    """
    clean = link_grid.grid_manifest({"rows": [_row(1, "acme/api#1"), _row(2, "acme/web#2")]}, {}, {})
    assert picture.short_refs(clean) == {"acme/api#1": "api#1", "acme/web#2": "web#2"}

    collided = link_grid.grid_manifest({"rows": [_row(1, "acme/api#1"), _row(2, "other/api#2")]}, {}, {})
    assert picture.short_refs(collided) == {"acme/api#1": "acme/api#1", "other/api#2": "other/api#2"}


# ── the surfaces AC2/S3 renders into the page ─────────────────────────────────────────────────────
#
# Everything below covers what the CHAINS section actually prints. It is here rather than deferred to
# S3 because S3 regenerates every golden in one commit: a broken gate line or a mis-ordered glance
# strip discovered THEN arrives as a golden diff among hundreds of other changed bytes, which is the
# worst possible place to notice it.


def test_the_glance_strip_is_one_glyph_per_node_in_id_order_with_no_ids():
    """MUTATION: order by ref, or include the ids.

    The ids are deliberately absent: every id must appear EXACTLY TWICE on the page (picture cell and
    detail heading) for `*` to work as a jump key, and a third occurrence in the strip breaks it.
    """
    block = link_grid.grid_manifest(fork_manifest(), {}, {})
    columns = picture.assign_columns(block)
    ids = picture.node_ids([block], [columns])
    strip = plain(picture.glance_row(block, ids))

    assert strip == "✔ ○ ○ ○ ○ ○ ○", "n1 merged, the other six open, in id order"
    assert "n1" not in strip and "n" not in strip


def test_a_detail_block_carries_title_why_join_gate_and_unparked():
    """The whole detail shape in one case. MUTATION: drop any of the five lines.

    Asserted on the approved mock's join node, which is the only one carrying all of them at once:
    three parents (so the join marker fires), a gate with both `blocked_by` and `resolved_by`, and a
    title that came off the wire rather than out of the manifest.
    """
    # Swept rather than `{}`: the `waits on:` line asserted at the bottom names each parent's state,
    # and AC4's precondition drops that word for an unverified node. Provenance is held constant here
    # for the same reason as in `swept()` above — this case measures the ORDER parents are listed in.
    items = swept(fork_manifest())
    items["acme/infra#77"] = {**items["acme/infra#77"], "title": "flip the flag"}
    block = link_grid.grid_manifest(fork_manifest(), items, {})
    columns = picture.assign_columns(block)
    ids = picture.node_ids([block], [columns])
    node = block["nodes"]["acme/infra#77"]
    lines = [plain(line) for line in picture.detail_block(node, ids[node["ref"]], block["nodes"], ids)]
    body = "\n".join(lines)

    assert lines[0].startswith("  n7    acme/infra#77")
    assert "(join: 3 parents)" in lines[0]
    assert "flip the flag" in body, "the wire title"
    assert "why:       flip enforcement flag" in body, "the author's sentence, distinct from the title"
    assert "unlocks:   nothing — end of the chain" in body
    assert "gate:      verification — staged rollout run must pass" in body
    assert "unparked:  canary deploy green for 24h" in body

    # Reading order: infra#12 is a LEVEL higher than the other two, so it is named first. (Note this
    # is NOT the order the approved mock's prose lists them in -- that is the row's `after` list as
    # typed, which is neither the wire order nor reading order.)
    assert "waits on:  acme/infra#12 (open) · acme/platform#431 (open) · acme/warehouse#93 (open)" in body

    # A node with one parent gets no join marker, and a gate without a resolver prints no unparked
    # line rather than an empty one.
    single = block["nodes"]["acme/platform#431"]
    assert "(join:" not in plain(picture.detail_block(single, "n5", block["nodes"], ids)[0])
    node["gate"] = {"kind": "decision", "blocked_by": "someone must choose", "resolved_by": ""}
    reduced = "\n".join(plain(line) for line in picture.detail_block(node, "n7", block["nodes"], ids))
    assert "gate:" in reduced and "unparked:" not in reduced


def test_a_detail_heading_puts_its_ref_in_the_same_column_past_n9():
    """MUTATION: replace the computed pad with four literal spaces -- aligned for n1..n9, ragged from
    n10 on, and invisible in every fixture with fewer than ten nodes.

    Found by reading a generated golden rather than by a test: the two-manifest orchestrator page
    reaches n11 and its last four headings each sat one column right of the first seven. The
    approved mock's own later render reaches n17.
    """
    block = link_grid.grid_manifest(fork_manifest(), {}, {})
    node = block["nodes"]["acme/infra#77"]
    columns = [
        len(plain(picture.detail_block(node, nid, block["nodes"], {})[0]).split("acme/")[0])
        for nid in ("n1", "n9", "n10", "n99", "n100", "n1000")
    ]
    assert len(set(columns)) == 1, dict(zip(("n1", "n9", "n10", "n99", "n100", "n1000"), columns))
    # ...and the id itself is never swallowed: an id longer than the field still gets one separator.
    assert plain(picture.detail_block(node, "n10000", block["nodes"], {})[0]).startswith("  n10000 acme/")


def test_neighbour_lists_follow_picture_reading_order_not_the_wire_order():
    """MUTATION: drop the `ids` sort in `_detail_refs` and read the wire's `(seq, ref)` order.

    The two orders come apart whenever DECLARATION order and TOPOLOGY disagree. `seq` follows
    `lanes()`' flattened order (lanes alphabetical, rows by `order`), so lane A's row is seq 0 -- but
    here lane A's row WAITS ON lane B's, so it ranks a level BELOW it. The wire therefore lists `a#1`
    first and the picture draws `b#2` a row higher.

    Three separate lanes deliberately: a single lane would add consecutive-row edges that fight the
    declared `after` edges and produce a CYCLE, whose cycle-breaker then picks the ranking by ref and
    destroys the very divergence this case is built on. (The first draft of this fixture did exactly
    that and ranked the wrong node first.)

    The approved mock does not discriminate this -- there the higher-level parent also happens to be
    declared first -- which is why this case exists separately rather than folded into it.
    """
    manifest = {
        "rows": [
            {"order": "1", "ref": "o/a#1", "lane": "A", "after": ["o/b#2"]},
            {"order": "1", "ref": "o/b#2", "lane": "B"},
            {"order": "1", "ref": "o/z#3", "lane": "C", "after": ["o/a#1", "o/b#2"]},
        ]
    }
    block = link_grid.grid_manifest(manifest, {}, {})
    columns = picture.assign_columns(block)
    ids = picture.node_ids([block], [columns])
    node = block["nodes"]["o/z#3"]

    assert not picture.back_edges(block), "the fixture must be acyclic, or the ranking is by ref"
    assert node["parents"] == ["o/a#1", "o/b#2"], "the wire is in declaration order"
    assert (ids["o/b#2"], ids["o/a#1"]) == ("n1", "n2"), "but b#2 is drawn a row higher"

    ordered = "\n".join(plain(line) for line in picture.detail_block(node, ids["o/z#3"], block["nodes"], ids))
    assert "waits on:  o/b#2" in ordered, "reading order names the higher node first"

    wire = "\n".join(plain(line) for line in picture.detail_block(node, "n3", block["nodes"], {}))
    assert "waits on:  o/a#1" in wire, "an empty id map is explicit wire order, not a crash"


def test_a_closed_node_is_distinguishable_from_a_merged_one():
    """MUTATION: fold `closed` into the default arm.

    The github adapter emits three tokens and the ratified glyph set covers two, so without `✗` an
    ABANDONED pull request renders identically to a shipped one -- a wrong answer on the command
    whose whole purpose is derived fact.
    """
    # Both nodes carry a RESOLVED source so the colour assertion measures state and not provenance:
    # AC4's precondition takes an unverified node to DIM whatever its state, which would make closed
    # and merged agree here and turn a real regression green.
    closed = {"state": "closed", "state_source": link_grid.STATE_SOURCE_SWEPT}
    merged = {"state": "merged", "state_source": link_grid.STATE_SOURCE_SWEPT}
    assert picture.state_glyph(closed) == picture.GLYPH_CLOSED
    assert picture.GLYPH_CLOSED not in (picture.GLYPH_MERGED, picture.GLYPH_OPEN, picture.GLYPH_READY)
    assert picture.glyph_color(closed) != picture.glyph_color(merged)


# ── AC4 PRECONDITION: the glyph is gated on PROVENANCE ────────────────────────────────────────────
# Measured on the live stillpoint/.borg/programs/ingle-t1-cutover.json: 12 nodes declared "merged",
# 2 unknown, and a glance strip of twelve green checkmarks asserting a project is essentially done
# entirely from a hand-typed field no sweep and no fetch ever saw. These cases pin all three sites
# the precondition names, because fixing one and missing another leaves the page contradicting
# itself -- which is precisely what `state_word` was doing before this change.


def _sourced(state: str, source: str, **extra) -> dict:
    node = {"ref": "o/a#1", "state": state, "state_source": source}
    node.update(extra)
    return node


def test_an_unverified_state_never_renders_as_a_verified_one():
    """The precondition in one case, across all three sites.

    MUTATION: delete any one of the three guards -- `resolved_provenance` in `cell_mark`, the DIM
    early return in `glyph_color`, or the `return ""` in `state_word`. Each turns one assertion red
    on its own, which is the point: they are three separate false claims about the same node.
    """
    declared = _sourced("merged", link_grid.STATE_SOURCE_DECLARED)
    swept_node = _sourced("merged", link_grid.STATE_SOURCE_SWEPT)

    # Same glyph -- the author's declaration is preserved, not discarded. That is what makes this
    # option (ii) rather than the rejected option (i), which collapsed every unverified cell to one
    # character and threw away what the manifest said.
    assert picture.state_glyph(declared) == picture.state_glyph(swept_node) == picture.GLYPH_MERGED

    # ...and every other signal says "nobody checked this".
    assert plain(picture.cell_mark(declared, drift=False)) == picture.PROVENANCE_MARK
    assert plain(picture.cell_mark(swept_node, drift=False)) == " "
    assert picture.glyph_color(declared) != picture.glyph_color(swept_node)
    assert picture.state_word(declared) == ""
    assert picture.state_word(swept_node) == "MERGED"


def test_an_unknown_state_source_is_unverified_too():
    """`unknown` is the bottom of the resolve ladder, not a fourth resolved rung.

    MUTATION: write the predicate as `!= STATE_SOURCE_DECLARED`. That reads naturally and is wrong --
    it would mark a hand-typed row and silently pass every ref nobody looked up at all, which is the
    MAJORITY case on any `--local` render (the fzf preview and `drone status` both opt down from both
    network rungs by design).
    """
    for source in (link_grid.STATE_SOURCE_DECLARED, link_grid.STATE_SOURCE_UNKNOWN, "", None):
        assert not picture.resolved_provenance(_sourced("merged", source))
    for source in link_grid.RESOLVED_STATE_SOURCES:
        assert picture.resolved_provenance(_sourced("merged", source))


def test_the_provenance_mark_beats_drift_when_both_apply():
    """One slot, two claims. MUTATION: swap the two arms of `cell_mark`.

    Contention was measured at 0 nodes on both live manifests, so no golden would catch the swap --
    only this case does. `?` wins because drift is a claim about the relationship between TWO states:
    if this node's own state was never verified, the contradiction is unverified too, and `!` is the
    loudest mark on the page.
    """
    unverified_drift = _sourced("merged", link_grid.STATE_SOURCE_DECLARED)
    verified_drift = _sourced("merged", link_grid.STATE_SOURCE_SWEPT)
    assert plain(picture.cell_mark(unverified_drift, drift=True)) == picture.PROVENANCE_MARK
    assert plain(picture.cell_mark(verified_drift, drift=True)) == picture.DRIFT_MARK
    assert picture.PROVENANCE_MARK != picture.DRIFT_MARK


def test_the_provenance_mark_survives_ansi_stripping():
    """The mark must be visible in a PLAIN-TEXT golden diff, not only on a colour terminal.

    MUTATION: implement the precondition as option (iii) -- dim the glyph and add no character. That
    renders identically under `plain()`, so every golden stays byte-for-byte green while the page
    quietly stops distinguishing verified from hand-typed. CLAUDE.md's "Learned" section catalogues
    that failure shape three times; this is the case that refuses it here.
    """
    declared = _sourced("merged", link_grid.STATE_SOURCE_DECLARED)
    cell = picture.node_cell(declared, "n1", "a#1", width=3, drift=False)
    assert picture.PROVENANCE_MARK in plain(cell)
    assert plain(cell).startswith(f"{picture.GLYPH_MERGED}{picture.PROVENANCE_MARK}n1")


def test_an_empty_manifest_renders_nothing_rather_than_raising():
    """The modal case's floor. MUTATION: index `levels[0]` without the guard.

    Only two manifests exist in the world and 18 of 20 registered repositories have none, so a
    renderer that raises on an empty grid takes out `borg link` for 90% of the board. The empty
    ROW helpers matter for the same reason: a level with no crossing edges must emit no connector.
    """
    empty = link_grid.grid_manifest({"rows": []}, {}, {})
    assert picture.picture(empty, {}, {}) == []
    assert picture.assign_columns(empty) == {}
    assert picture.node_ids([empty], [{}]) == {}
    assert picture.glance_row(empty, {}) == ""
    assert picture.short_refs(empty) == {}
    assert picture.ref_width({}) == 0
    # A rail with nothing jogging is not a rail, and a row with no cells is not a row.
    assert picture.rail_row([(0, 0), (1, 1)], 10) == ""
    assert picture.stem_row(set(), 10) == ""


def test_a_gap_inside_a_rail_span_is_filled_not_connected():
    """A column interior to a rail that carries NO segment renders `─`, not a junction and not a gap.

    MUTATION: emit a space, and the rail visibly breaks in two. Distinct from the pass-through case
    (P9), where the interior column DOES carry a segment and must therefore keep its own `│`.

    The fixture forks four ways and joins only the outer two, so columns 1 and 2 sit inside the span
    with nothing crossing there.
    """
    manifest = {
        "rows": [
            _row(1, "o/t#1"),
            _row(2, "o/a#2", after=["o/t#1"]),
            _row(3, "o/b#3", after=["o/t#1"]),
            _row(4, "o/c#4", after=["o/t#1"]),
            _row(5, "o/d#5", after=["o/t#1"]),
            _row(6, "o/z#6", after=["o/a#2", "o/d#5"]),
        ]
    }
    rows = render(manifest)
    joins = [row for row in rows if "└" in row]
    assert joins, "the fixture must produce a join rail"
    rail = joins[-1].strip()

    # A rail is ONE UNBROKEN RUN. A gap column emitting a space instead of `─` splits it in two,
    # which is what this catches -- without depending on which junction glyph the far end takes. It
    # is `┤` here and not `┘`, because the join column also carries a straight segment downward.
    assert " " not in rail, f"the rail must be solid, got {rail!r}"
    assert set(rail[1:-1]) == {"─"}, f"the span between the junctions must be fill, got {rail!r}"


def test_short_refs_keeps_a_ref_it_cannot_parse():
    """A ref parse_ref rejects still occupies a cell -- verbatim, never shortened, never dropped.

    MUTATION: skip it, and the node vanishes from the picture while keeping a detail block, which
    breaks the appears-exactly-twice rule the `*` jump depends on. Unreachable through the CLI
    (validate rejects such a manifest at load) and covered here so the function stays total.
    """
    block = link_grid.grid_manifest({"rows": [_row(1, "o/r#1"), {"order": "2", "ref": "not-a-ref"}]}, {}, {})
    short = picture.short_refs(block)
    assert short["not-a-ref"] == "not-a-ref"
    assert short["o/r#1"] == "r#1"
    assert picture.link_ref("not-a-ref", short["not-a-ref"]) == "not-a-ref"


def test_node_ids_are_global_across_manifests_and_appear_once_each():
    """The `*`-jump mechanism: every id appears exactly twice on a page -- picture cell and detail
    heading -- so two manifests numbering from n1 each would put four `n1`s on the page.

    MUTATION: number per manifest.
    """
    first = link_grid.grid_manifest(fork_manifest(), {}, {})
    second = link_grid.grid_manifest(crossing_manifest(), {}, {})
    blocks = [first, second]
    columns = [picture.assign_columns(b) for b in blocks]
    ids = picture.node_ids(blocks, columns)

    assert len(set(ids.values())) == len(ids) == 13
    assert ids["acme/platform#400"] == "n1"
    assert ids["a/r#1"] == "n8", "the second manifest continues the numbering"
