"""Tests for backfill.py — recovering declared edges from a historical data.json.

The load-bearing test is `test_a_blocked_singleton_still_produces_a_manifest`. The first working
version of this module silently discarded the ONLY cross-repo edge in the real source data, because a
`blocks` edge does not merge components and the blocked item therefore landed in a component of one
that the two-or-more filter dropped. The stats line reported the source count as though it proved
preservation. That is the regression this file exists to prevent.
"""

from __future__ import annotations

import json

import backfill
import programs


def _item(ref, project="P", state="OPEN", **over):
    return {"ref": ref, "project": project, "state": state, "title": f"t {ref}", **over}


def _edge(parent, child, kind="stacked"):
    return {"parent": parent, "child": child, "kind": kind}


def _data(items, edges):
    return {"meta": {"gathered_at": "2026-07-30T00:00:00Z"}, "items": items, "edges": edges}


class TestComponents:
    def test_chain_edges_group_refs(self):
        got = backfill.components(["a", "b", "c"], [_edge("a", "b")])
        assert got == [["a", "b"], ["c"]]

    def test_blocks_edges_do_not_group(self):
        # The whole reason blocked singletons need special handling downstream.
        assert backfill.components(["a", "b"], [_edge("a", "b", "blocks")]) == [["a"], ["b"]]

    def test_apex_edges_group(self):
        assert backfill.components(["a", "b"], [_edge("a", "b", "apex")]) == [["a", "b"]]


class TestChainOrder:
    def test_a_linear_stack_comes_out_in_merge_order(self):
        edges = [_edge("r#1", "r#2"), _edge("r#2", "r#3")]
        assert backfill.chain_order(["r#3", "r#1", "r#2"], edges) == ["r#1", "r#2", "r#3"]

    def test_members_in_no_stacked_edge_sort_after_the_chain(self):
        # An unchained member has no DECLARED position; inventing one would be a guess presented as a
        # declaration.
        edges = [_edge("r#1", "r#2")]
        assert backfill.chain_order(["r#1", "r#2", "r#9"], edges) == ["r#1", "r#2", "r#9"]

    def test_output_is_deterministic_regardless_of_input_order(self):
        edges = [_edge("r#1", "r#2"), _edge("r#1", "r#3")]
        a = backfill.chain_order(["r#1", "r#2", "r#3"], edges)
        assert a == backfill.chain_order(["r#3", "r#2", "r#1"], edges)

    def test_a_cycle_does_not_drop_members_or_hang(self):
        edges = [_edge("r#1", "r#2"), _edge("r#2", "r#1")]
        assert sorted(backfill.chain_order(["r#1", "r#2"], edges)) == ["r#1", "r#2"]


class TestApexOf:
    def test_the_apex_is_the_parent_that_is_no_ones_child(self):
        edges = [_edge("x#1", "r#1", "apex"), _edge("x#1", "r#2", "apex")]
        assert backfill.apex_of(["x#1", "r#1", "r#2"], edges) == "x#1"

    def test_no_apex_edges_means_no_apex(self):
        assert backfill.apex_of(["r#1", "r#2"], [_edge("r#1", "r#2")]) == ""


class TestBackfill:
    def test_a_stacked_pair_becomes_one_manifest_in_merge_order(self):
        data = _data([_item("r#1"), _item("r#2")], [_edge("r#1", "r#2")])
        manifests, stats = backfill.backfill(data)
        assert len(manifests) == 1
        assert [r["ref"] for r in manifests[0]["rows"]] == ["r#1", "r#2"]
        assert stats["programs"] == 1

    def test_output_manifests_validate_against_the_schema(self):
        # A backfill that emits invalid manifests would be discarded by discover() with a warning —
        # i.e. silently useless.
        data = _data(
            [_item("r#1"), _item("r#2"), _item("x#1")],
            [_edge("r#1", "r#2"), _edge("x#1", "r#1", "apex"), _edge("r#9", "r#2", "blocks")],
        )
        manifests, _ = backfill.backfill(data)
        for m in manifests:
            assert programs.validate(m) == [], m

    def test_a_merged_item_is_recorded_as_a_prerequisite(self):
        data = _data([_item("r#1", state="MERGED"), _item("r#2")], [_edge("r#1", "r#2")])
        rows = {r["ref"]: r for r in backfill.backfill(data)[0][0]["rows"]}
        assert rows["r#1"]["order"] == "–" and rows["r#1"]["status"] == "merged"
        assert rows["r#2"]["order"] == "1"

    def test_an_apex_becomes_the_manifest_apex_and_not_a_row(self):
        data = _data(
            [_item("x#1"), _item("r#1"), _item("r#2")],
            [_edge("x#1", "r#1", "apex"), _edge("x#1", "r#2", "apex")],
        )
        m = backfill.backfill(data)[0][0]
        assert m["apex"]["ref"] == "x#1"
        assert "x#1" not in [r["ref"] for r in m["rows"]]

    def test_a_blocks_edge_becomes_a_gate_with_a_ref(self):
        data = _data(
            [_item("r#1"), _item("r#2"), _item("r#9")],
            [_edge("r#1", "r#2"), _edge("r#9", "r#2", "blocks")],
        )
        rows = {r["ref"]: r for r in backfill.backfill(data)[0][0]["rows"]}
        assert rows["r#2"]["gate"]["blocked_by_ref"] == "r#9"
        assert rows["r#2"]["status"] == "stacked"

    def test_a_blocked_singleton_still_produces_a_manifest(self):
        # THE regression test. `r#2` is in no chain, so it is a component of one; the two-or-more
        # filter would drop it and the blocks edge with it.
        data = _data([_item("r#2"), _item("r#9")], [_edge("r#9", "r#2", "blocks")])
        manifests, stats = backfill.backfill(data)
        assert stats["blocks_kept"] == 1 and stats["blocks_source"] == 1
        assert any(
            r["ref"] == "r#2" and r["gate"]["blocked_by_ref"] == "r#9"
            for m in manifests
            for r in m["rows"]
        )

    def test_a_cross_repo_blocks_edge_is_preserved_and_counted(self):
        data = _data(
            [_item("a/one#2"), _item("b/two#9")],
            [_edge("b/two#9", "a/one#2", "blocks")],
        )
        _, stats = backfill.backfill(data)
        assert stats["cross_repo_source"] == 1
        assert stats["cross_repo_kept"] == 1

    def test_every_blocks_edge_is_accounted_for(self):
        # The invariant: kept + dropped == source. Anything else means an edge went missing.
        data = _data(
            [_item(f"r#{n}") for n in range(1, 6)],
            [_edge("r#1", "r#2"), _edge("r#4", "r#3", "blocks"), _edge("r#5", "r#3", "blocks")],
        )
        _, stats = backfill.backfill(data)
        assert stats["blocks_kept"] + len(stats["dropped_blockers"]) == stats["blocks_source"]

    def test_a_second_blocker_on_one_row_is_reported_not_silently_dropped(self):
        data = _data(
            [_item("r#3"), _item("r#4"), _item("r#5")],
            [_edge("r#4", "r#3", "blocks"), _edge("r#5", "r#3", "blocks")],
        )
        _, stats = backfill.backfill(data)
        assert len(stats["dropped_blockers"]) == 1
        assert "also blocked by" in stats["dropped_blockers"][0]

    def test_unlinked_items_produce_no_manifest(self):
        # A component of one with no edges declares nothing that could not be derived.
        data = _data([_item("r#1"), _item("r#2")], [])
        manifests, stats = backfill.backfill(data)
        assert manifests == [] and stats["programs"] == 0

    def test_edges_referencing_unknown_items_are_ignored(self):
        data = _data([_item("r#1")], [_edge("r#1", "ghost#9")])
        assert backfill.backfill(data)[0] == []

    def test_an_empty_data_document_yields_nothing(self):
        manifests, stats = backfill.backfill({})
        assert manifests == [] and stats["source_edges"] == 0

    def test_program_ids_are_slugs_anchored_on_the_first_ref(self):
        data = _data(
            [_item("r#1", project="WHP - Keypair"), _item("r#2", project="WHP - Keypair")],
            [_edge("r#1", "r#2")],
        )
        assert backfill.backfill(data)[0][0]["program"] == "sfp-keypair-1"


class TestEndToEnd:
    def test_backfilled_manifests_round_trip_into_the_expected_edges(self, tmp_path):
        """Backfill -> disk -> discover -> edges, which is the real path."""
        data = _data(
            [_item("r#1"), _item("r#2"), _item("r#9")],
            [_edge("r#1", "r#2"), _edge("r#9", "r#2", "blocks")],
        )
        manifests, _ = backfill.backfill(data)

        d = tmp_path / "proj" / ".borg" / "programs"
        d.mkdir(parents=True)
        for m in manifests:
            (d / f"{m['program']}.json").write_text(json.dumps(m))

        found, warnings = programs.discover([str(tmp_path / "proj")])
        assert warnings == []
        edges = programs.edges_from(found)
        kinds = {(e["kind"], e["parent"], e["child"]) for e in edges}
        assert ("stacked", "r#1", "r#2") in kinds
        assert ("blocks", "r#9", "r#2") in kinds


class TestMainCLI:
    def test_dry_run_writes_nothing(self, tmp_path, capsys):
        import sys

        src = tmp_path / "data.json"
        src.write_text(json.dumps(_data([_item("r#1"), _item("r#2")], [_edge("r#1", "r#2")])))
        out = tmp_path / "out"
        argv = ["backfill.py", "--data", str(src), "--out-dir", str(out), "--dry-run"]
        old, sys.argv = sys.argv, argv
        try:
            assert backfill.main() == 0
        finally:
            sys.argv = old
        assert not out.exists()
        assert "DRY: would write" in capsys.readouterr().out

    def test_writes_manifests(self, tmp_path):
        import sys

        src = tmp_path / "data.json"
        src.write_text(json.dumps(_data([_item("r#1"), _item("r#2")], [_edge("r#1", "r#2")])))
        out = tmp_path / "out"
        argv = ["backfill.py", "--data", str(src), "--out-dir", str(out)]
        old, sys.argv = sys.argv, argv
        try:
            assert backfill.main() == 0
        finally:
            sys.argv = old
        assert len(list(out.glob("*.json"))) == 1

    def test_returns_1_on_an_unreadable_source(self, tmp_path, capsys):
        import sys

        argv = ["backfill.py", "--data", str(tmp_path / "nope.json"), "--out-dir", str(tmp_path)]
        old, sys.argv = sys.argv, argv
        try:
            assert backfill.main() == 1
        finally:
            sys.argv = old
        assert "cannot read" in capsys.readouterr().err
