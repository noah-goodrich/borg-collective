"""Characterization tests for Dataset.lens() and Dataset.portfolio_lens() in graph.py.

These tests pin CURRENT behavior before an extract-method refactor (ruff C901 complexity fixes).
Fixtures are small, hand-authored story.json/data.json-shaped dicts — never the real corpus files.
"""

from __future__ import annotations

from graph import Dataset


def make_item(ref: str, **overrides: object) -> dict:
    item = {
        "ref": ref,
        "title": f"title-{ref}",
        "state": "OPEN",
        "bucket": "",
        "project": "",
        "repo": "",
        "url": "",
        "blocked": False,
        "action_needed": "",
    }
    item.update(overrides)
    return item


def make_edge(parent: str, child: str, kind: str = "blocks") -> dict:
    return {"parent": parent, "child": child, "kind": kind}


# ---------------------------------------------------------------------------
# lens() fixtures + tests
# ---------------------------------------------------------------------------


def simple_dataset() -> Dataset:
    """root -> out1 (blocks), in1 -> root (stacked)."""
    items = [make_item("root"), make_item("out1"), make_item("in1")]
    edges = [
        make_edge("root", "out1", "blocks"),
        make_edge("in1", "root", "stacked"),
    ]
    data = {"items": items, "edges": edges, "actions": {}}
    story: dict = {"projects": []}
    return Dataset(story, data)


def test_lens_portfolio_dispatch():
    ds = simple_dataset()
    result = ds.lens("portfolio")
    assert result["root"] == "portfolio"


def test_lens_both_direction_includes_in_and_out():
    ds = simple_dataset()
    result = ds.lens("root", radius=1, direction="both")
    node_refs = {n["ref"] for n in result["nodes"]}
    assert node_refs == {"root", "out1", "in1"}
    edge_pairs = {(e["source"], e["target"]) for e in result["edges"]}
    assert ("root", "out1") in edge_pairs
    assert ("in1", "root") in edge_pairs


def test_lens_direction_out_excludes_in_edges():
    ds = simple_dataset()
    result = ds.lens("root", radius=1, direction="out")
    node_refs = {n["ref"] for n in result["nodes"]}
    assert "out1" in node_refs
    assert "in1" not in node_refs
    edge_pairs = {(e["source"], e["target"]) for e in result["edges"]}
    assert ("in1", "root") not in edge_pairs


def test_lens_direction_in_excludes_out_edges():
    """Use a non-"blocks" out-edge so the direction-independent blocking closure doesn't mask it."""
    items = [make_item("root"), make_item("out1"), make_item("in1")]
    edges = [
        make_edge("root", "out1", "stacked"),
        make_edge("in1", "root", "stacked"),
    ]
    ds = Dataset({"projects": []}, {"items": items, "edges": edges, "actions": {}})
    result = ds.lens("root", radius=1, direction="in")
    node_refs = {n["ref"] for n in result["nodes"]}
    assert "in1" in node_refs
    assert "out1" not in node_refs
    edge_pairs = {(e["source"], e["target"]) for e in result["edges"]}
    assert ("root", "out1") not in edge_pairs


def test_lens_radius_zero_no_neighborhood_expansion():
    ds = simple_dataset()
    result = ds.lens("root", radius=0, direction="both")
    node_refs = {n["ref"] for n in result["nodes"]}
    # No 1-hop neighborhood expansion, but the root's own blocking closure still applies
    # (root -> out1 is a "blocks" edge, so out1 survives via the closure step, not the walk).
    assert "root" in node_refs
    assert "out1" in node_refs
    # in1 is only reachable via a non-blocks ("stacked") edge, so with radius=0 it must NOT appear.
    assert "in1" not in node_refs


def chain_dataset() -> Dataset:
    """root -> a -> b -> c, all "blocks" edges (linear chain, 3 hops from root)."""
    items = [make_item(r) for r in ("root", "a", "b", "c")]
    edges = [
        make_edge("root", "a", "blocks"),
        make_edge("a", "b", "blocks"),
        make_edge("b", "c", "blocks"),
    ]
    data = {"items": items, "edges": edges, "actions": {}}
    story: dict = {"projects": []}
    return Dataset(story, data)


def test_lens_radius_two_expands_two_hops_not_three():
    ds = chain_dataset()
    result = ds.lens("root", radius=2, direction="out")
    node_refs = {n["ref"] for n in result["nodes"]}
    # Because these are "blocks" edges, the transitive blocking closure (independent of radius)
    # also pulls in the full chain, so we need a non-blocks 3rd hop to truly test radius bounding.
    assert {"root", "a", "b"} <= node_refs


def test_lens_radius_bounds_non_blocking_walk():
    """Use a non-"blocks" kind so the closure step doesn't mask the radius bound."""
    items = [make_item(r) for r in ("root", "a", "b", "c")]
    edges = [
        make_edge("root", "a", "stacked"),
        make_edge("a", "b", "stacked"),
        make_edge("b", "c", "stacked"),
    ]
    data = {"items": items, "edges": edges, "actions": {}}
    ds = Dataset({"projects": []}, data)
    result = ds.lens("root", radius=2, direction="out")
    node_refs = {n["ref"] for n in result["nodes"]}
    assert node_refs == {"root", "a", "b"}
    assert "c" not in node_refs


def test_lens_blocking_closure_ignores_radius():
    """A "blocks" chain extending 3+ hops beyond a radius=1 request must still fully appear."""
    items = [make_item(r) for r in ("root", "a", "b", "c", "d")]
    edges = [
        make_edge("root", "a", "blocks"),
        make_edge("a", "b", "blocks"),
        make_edge("b", "c", "blocks"),
        make_edge("c", "d", "blocks"),
    ]
    data = {"items": items, "edges": edges, "actions": {}}
    ds = Dataset({"projects": []}, data)
    result = ds.lens("root", radius=1, direction="out")
    node_refs = {n["ref"] for n in result["nodes"]}
    assert node_refs == {"root", "a", "b", "c", "d"}


def test_lens_edge_dedup_across_walk_and_closure():
    """The same edge discoverable via both the neighborhood walk and the closure walk appears once."""
    ds = simple_dataset()  # root -> out1 is a "blocks" edge, reachable by both paths.
    result = ds.lens("root", radius=1, direction="both")
    matching = [e for e in result["edges"] if e["source"] == "root" and e["target"] == "out1"]
    assert len(matching) == 1


def test_lens_capping_truncates_and_always_includes_root():
    items = [make_item("root")] + [make_item(f"n{i}") for i in range(50)]
    edges = [make_edge("root", f"n{i}", "blocks") for i in range(50)]
    data = {"items": items, "edges": edges, "actions": {}}
    ds = Dataset({"projects": []}, data)
    result = ds.lens("root", radius=1, direction="out")
    assert result["truncated"] > 0
    assert len(result["nodes"]) == 40
    node_refs = {n["ref"] for n in result["nodes"]}
    assert "root" in node_refs


def test_lens_edges_only_reference_surviving_capped_nodes():
    items = [make_item("root")] + [make_item(f"n{i}") for i in range(50)]
    edges = [make_edge("root", f"n{i}", "blocks") for i in range(50)]
    data = {"items": items, "edges": edges, "actions": {}}
    ds = Dataset({"projects": []}, data)
    result = ds.lens("root", radius=1, direction="out")
    node_refs = {n["ref"] for n in result["nodes"]}
    for e in result["edges"]:
        assert e["source"] in node_refs
        assert e["target"] in node_refs


# ---------------------------------------------------------------------------
# portfolio_lens() fixtures + tests
# ---------------------------------------------------------------------------


def portfolio_story(proj_a_workstreams=None, proj_b_workstreams=None, proj_c_workstreams=None):
    return {
        "projects": [
            {
                "id": "proj-a",
                "name": "Project Alpha",
                "workstreams": proj_a_workstreams or [{"title": "ws-a1", "items": ["a1"], "state": "ready"}],
            },
            {
                "id": "proj-b",
                "name": "Project Beta",
                "workstreams": proj_b_workstreams or [{"title": "ws-b1", "items": ["b1"], "state": "ready"}],
            },
            {
                "id": "proj-c",
                "name": "Project Gamma",
                "workstreams": proj_c_workstreams or [{"title": "ws-c1", "items": ["c1"], "state": "ready"}],
            },
        ]
    }


def test_portfolio_cross_project_edge_from_blocks_edge():
    story = portfolio_story()
    items = [make_item("a1"), make_item("b1"), make_item("c1")]
    edges = [make_edge("a1", "b1", "blocks")]
    ds = Dataset(story, {"items": items, "edges": edges, "actions": {}})
    result = ds.portfolio_lens()
    edge_pairs = {(e["source"], e["target"]) for e in result["edges"]}
    assert ("proj-a", "proj-b") in edge_pairs


def test_portfolio_same_project_blocks_edge_not_cross_project():
    story = portfolio_story(proj_a_workstreams=[{"title": "ws-a1", "items": ["a1", "a2"], "state": "ready"}])
    items = [make_item("a1"), make_item("a2"), make_item("b1"), make_item("c1")]
    edges = [make_edge("a1", "a2", "blocks")]
    ds = Dataset(story, {"items": items, "edges": edges, "actions": {}})
    result = ds.portfolio_lens()
    assert result["edges"] == []


def test_portfolio_non_blocks_edge_never_produces_edge():
    story = portfolio_story()
    items = [make_item("a1"), make_item("b1"), make_item("c1")]
    edges = [make_edge("a1", "b1", "stacked")]
    ds = Dataset(story, {"items": items, "edges": edges, "actions": {}})
    result = ds.portfolio_lens()
    assert result["edges"] == []


def test_portfolio_cross_project_edge_from_prose_id_substring():
    story = portfolio_story(
        proj_b_workstreams=[
            {"title": "ws-b1", "items": ["b1"], "state": "ready", "blocked_by": ["waiting on proj-a to ship"]}
        ]
    )
    items = [make_item("a1"), make_item("b1"), make_item("c1")]
    ds = Dataset(story, {"items": items, "edges": [], "actions": {}})
    result = ds.portfolio_lens()
    edge_pairs = {(e["source"], e["target"]) for e in result["edges"]}
    assert ("proj-a", "proj-b") in edge_pairs


def test_portfolio_cross_project_edge_from_prose_name_substring():
    story = portfolio_story(
        proj_b_workstreams=[
            {"title": "ws-b1", "items": ["b1"], "state": "ready", "blocked_by": ["waiting on Project Alpha to ship"]}
        ]
    )
    items = [make_item("a1"), make_item("b1"), make_item("c1")]
    ds = Dataset(story, {"items": items, "edges": [], "actions": {}})
    result = ds.portfolio_lens()
    edge_pairs = {(e["source"], e["target"]) for e in result["edges"]}
    assert ("proj-a", "proj-b") in edge_pairs


def test_portfolio_self_reference_prose_does_not_self_edge():
    story = portfolio_story(
        proj_a_workstreams=[
            {"title": "ws-a1", "items": ["a1"], "state": "ready", "blocked_by": ["blocked internally by proj-a"]}
        ]
    )
    items = [make_item("a1"), make_item("b1"), make_item("c1")]
    ds = Dataset(story, {"items": items, "edges": [], "actions": {}})
    result = ds.portfolio_lens()
    edge_pairs = {(e["source"], e["target"]) for e in result["edges"]}
    assert ("proj-a", "proj-a") not in edge_pairs
    assert result["edges"] == []


def test_portfolio_rollup_state_priority_order():
    story = portfolio_story(
        proj_a_workstreams=[
            {"title": "ws1", "items": [], "state": "ready"},
            {"title": "ws2", "items": [], "state": "blocked"},
            {"title": "ws3", "items": [], "state": "in-flight"},
        ]
    )
    ds = Dataset(story, {"items": [], "edges": [], "actions": {}})
    result = ds.portfolio_lens()
    node_a = next(n for n in result["nodes"] if n["ref"] == "proj-a")
    assert node_a["state"] == "blocked"


def test_portfolio_rollup_state_in_flight_over_done_and_ready():
    story = portfolio_story(
        proj_a_workstreams=[
            {"title": "ws1", "items": [], "state": "done"},
            {"title": "ws2", "items": [], "state": "in-flight"},
            {"title": "ws3", "items": [], "state": "ready"},
        ]
    )
    ds = Dataset(story, {"items": [], "edges": [], "actions": {}})
    result = ds.portfolio_lens()
    node_a = next(n for n in result["nodes"] if n["ref"] == "proj-a")
    assert node_a["state"] == "in-flight"


def test_portfolio_rollup_state_all_done():
    story = portfolio_story(proj_a_workstreams=[{"title": "ws1", "items": [], "state": "done"}])
    ds = Dataset(story, {"items": [], "edges": [], "actions": {}})
    result = ds.portfolio_lens()
    node_a = next(n for n in result["nodes"] if n["ref"] == "proj-a")
    assert node_a["state"] == "done"


def test_portfolio_rollup_state_ready_over_pending():
    story = portfolio_story(
        proj_a_workstreams=[
            {"title": "ws1", "items": [], "state": "pending"},
            {"title": "ws2", "items": [], "state": "ready"},
        ]
    )
    ds = Dataset(story, {"items": [], "edges": [], "actions": {}})
    result = ds.portfolio_lens()
    node_a = next(n for n in result["nodes"] if n["ref"] == "proj-a")
    assert node_a["state"] == "ready"


def test_portfolio_node_bucket_and_has_action_always_empty_false():
    story = portfolio_story()
    items = [make_item("a1"), make_item("b1"), make_item("c1")]
    ds = Dataset(story, {"items": items, "edges": [], "actions": {"a1": "some-action"}})
    result = ds.portfolio_lens()
    for node in result["nodes"]:
        assert node["bucket"] == ""
        assert node["has_action"] is False
