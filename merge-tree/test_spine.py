"""Tests for spine.py — the story.json skeleton generator (viz-2, S1/S2/S3/S5).

These are NOT characterization tests. spine.py is new code and story.json previously had no
generator at all, so there is no prior behavior to lock in — these assert intended behavior.
"""

from __future__ import annotations

import json
from pathlib import Path

from spine import (
    apply_overlay,
    derive_blocked_by,
    derive_state,
    find_orphans,
    generate_skeleton,
    slugify,
    workstream_key,
)

FIXTURES = Path(__file__).parent / "fixtures"


def _gather():
    return json.loads((FIXTURES / "gather.raw.json").read_text())


def _item(ref, project="p", state="OPEN", blocked=False):
    return {"ref": ref, "project": project, "state": state, "blocked": blocked}


class TestSlugify:
    def test_prose_project_name_becomes_a_stable_slug(self):
        assert slugify("WHP - Keypair migration") == "whp-keypair-migration"

    def test_collapses_runs_of_separators_and_trims(self):
        assert slugify("dbt - models & pipelines (misc)") == "dbt-models-pipelines-misc"

    def test_is_idempotent_so_reslugging_a_slug_is_a_no_op(self):
        # Load-bearing: the overlay is keyed by slug, so slug(slug(x)) drifting would orphan
        # judgment on the second regeneration.
        once = slugify("WHP - team-token provisioning")
        assert slugify(once) == once

    def test_handles_empty_and_none(self):
        assert slugify("") == ""
        assert slugify(None) == ""


class TestWorkstreamGrouping:
    def test_chain_edges_group_items_into_one_workstream(self):
        gather = {
            "items": [_item("r#1"), _item("r#2"), _item("r#3")],
            "edges": [{"parent": "r#1", "child": "r#2", "kind": "stacked"}],
        }
        wss = generate_skeleton(gather)["projects"][0]["workstreams"]
        groups = sorted([sorted(ws["items"]) for ws in wss], key=len, reverse=True)
        assert groups[0] == ["r#1", "r#2"]
        assert groups[1] == ["r#3"]

    def test_blocks_edges_do_NOT_merge_workstreams(self):
        # A blocking edge is a dependency BETWEEN workstreams. Merging them would lose the
        # dependency and collapse a blocker into its own victim.
        gather = {
            "items": [_item("r#1"), _item("r#2")],
            "edges": [{"parent": "r#1", "child": "r#2", "kind": "blocks"}],
        }
        wss = generate_skeleton(gather)["projects"][0]["workstreams"]
        assert len(wss) == 2

    def test_unconnected_item_is_its_own_single_item_workstream(self):
        gather = {"items": [_item("r#9")], "edges": []}
        wss = generate_skeleton(gather)["projects"][0]["workstreams"]
        assert wss == [
            {"key": "r#9", "state": "in-flight", "blocked_by": [], "items": ["r#9"]}
        ]

    def test_output_is_byte_stable_across_runs(self):
        # A spine that reorders every regeneration is undiffable, which defeats generating it.
        a = generate_skeleton(_gather())
        b = generate_skeleton(_gather())
        del a["meta"]["generated_at"], b["meta"]["generated_at"]
        assert json.dumps(a, sort_keys=True) == json.dumps(b, sort_keys=True)


class TestDerivedFields:
    def test_any_blocked_member_makes_the_workstream_blocked(self):
        by_ref = {"a": _item("a", blocked=True), "b": _item("b")}
        assert derive_state(["a", "b"], by_ref) == "blocked"

    def test_all_terminal_members_make_it_done(self):
        by_ref = {"a": _item("a", state="MERGED"), "b": _item("b", state="CLOSED")}
        assert derive_state(["a", "b"], by_ref) == "done"

    def test_any_open_member_makes_it_in_flight(self):
        by_ref = {"a": _item("a", state="MERGED"), "b": _item("b", state="OPEN")}
        assert derive_state(["a", "b"], by_ref) == "in-flight"

    def test_no_known_members_is_pending_not_a_crash(self):
        assert derive_state(["ghost"], {}) == "pending"

    def test_blocked_by_comes_from_blocks_edges_and_excludes_own_members(self):
        edges = [
            {"parent": "x#1", "child": "r#2", "kind": "blocks"},
            {"parent": "r#1", "child": "r#2", "kind": "blocks"},
            {"parent": "z#9", "child": "r#2", "kind": "stacked"},
        ]
        # r#1 is a member, so it is not its own blocker; z#9 is a chain edge, not a blocker.
        assert derive_blocked_by(["r#1", "r#2"], edges) == ["x#1"]

    def test_cross_repo_blocking_edge_is_derived_from_the_real_fixture(self):
        # The capability this whole directive exists for: warehouse-permissions#301 is blocked by
        # infrastructure#2334, across repos, derived rather than hand-authored.
        spine = generate_skeleton(_gather())
        found = [
            ws
            for pr in spine["projects"]
            for ws in pr["workstreams"]
            if "warehouse-permissions#301" in ws["items"]
        ]
        assert found and found[0]["blocked_by"] == ["infrastructure#2334"]


class TestSkeletonFromRealFixture:
    def test_every_project_in_the_gather_appears_in_the_spine(self):
        gather = _gather()
        expected = {slugify(it["project"]) for it in gather["items"] if it.get("project")}
        got = {pr["id"] for pr in generate_skeleton(gather)["projects"]}
        assert got == expected

    def test_every_item_in_the_gather_lands_in_exactly_one_workstream(self):
        gather = _gather()
        placed = [
            ref
            for pr in generate_skeleton(gather)["projects"]
            for ws in pr["workstreams"]
            for ref in ws["items"]
        ]
        assert sorted(placed) == sorted(it["ref"] for it in gather["items"])
        assert len(placed) == len(set(placed)), "an item was placed in two workstreams"

    def test_the_pat_trio_groups_as_one_workstream(self):
        # #339/#340/#341 — the work that went unsurfaced on 2026-08-10.
        spine = generate_skeleton(_gather())
        groups = [set(ws["items"]) for pr in spine["projects"] for ws in pr["workstreams"]]
        trio = {
            "warehouse-permissions#339",
            "warehouse-permissions#340",
            "warehouse-permissions#341",
        }
        assert trio in groups

    def test_gather_name_is_retained_as_provenance(self):
        spine = generate_skeleton(_gather())
        by_id = {pr["id"]: pr for pr in spine["projects"]}
        assert by_id["whp-keypair-migration"]["gather_name"] == "WHP - Keypair migration"


class TestOverlayRoundTrip:
    """S2 — judgment must survive regeneration."""

    def _overlay(self):
        return {
            "projects": {
                "whp-keypair-migration": {
                    "name": "Keypair Migration",
                    "priority": 1,
                    "summary": "Hand-written prose that must survive.",
                    "summary_authored_at": "2026-07-28T16:15:00Z",
                    "workstreams": {
                        "warehouse-permissions#292": {
                            "title": "Land the linchpin",
                            "next_action": "Merge #292 first.",
                        }
                    },
                }
            }
        }

    def test_judgment_is_applied_onto_the_skeleton(self):
        spine = apply_overlay(generate_skeleton(_gather()), self._overlay())
        pr = next(p for p in spine["projects"] if p["id"] == "whp-keypair-migration")
        assert pr["name"] == "Keypair Migration"
        assert pr["priority"] == 1
        assert pr["summary"] == "Hand-written prose that must survive."
        ws = next(w for w in pr["workstreams"] if w["key"] == "warehouse-permissions#292")
        assert ws["title"] == "Land the linchpin"
        assert ws["next_action"] == "Merge #292 first."

    def test_regenerating_twice_does_not_lose_judgment(self):
        overlay = self._overlay()
        first = apply_overlay(generate_skeleton(_gather()), overlay)
        second = apply_overlay(generate_skeleton(_gather()), overlay)
        def summary_of(spine):
            return next(
                p["summary"] for p in spine["projects"] if p["id"] == "whp-keypair-migration"
            )

        assert summary_of(first) == summary_of(second) == "Hand-written prose that must survive."

    def test_skeleton_wins_on_structure_even_when_the_overlay_is_stale(self):
        # The overlay must never be able to resurrect a workstream the gather no longer supports.
        overlay = self._overlay()
        overlay["projects"]["whp-keypair-migration"]["workstreams"]["ghost#1"] = {"title": "Gone"}
        spine = apply_overlay(generate_skeleton(_gather()), overlay)
        pr = next(p for p in spine["projects"] if p["id"] == "whp-keypair-migration")
        assert "ghost#1" not in [w["key"] for w in pr["workstreams"]]

    def test_missing_overlay_yields_blank_judgment_not_a_crash(self):
        spine = apply_overlay(generate_skeleton(_gather()), {})
        assert all(p["summary"] == "" for p in spine["projects"])
        assert all(p["priority"] is None for p in spine["projects"])

    def test_unprioritised_projects_sort_last_but_remain_present(self):
        spine = apply_overlay(generate_skeleton(_gather()), self._overlay())
        assert spine["projects"][0]["id"] == "whp-keypair-migration"
        assert len(spine["projects"]) == 7, "an unprioritised project was dropped"

    def test_name_falls_back_to_the_gather_name_when_unjudged(self):
        spine = apply_overlay(generate_skeleton(_gather()), {})
        by_id = {p["id"]: p for p in spine["projects"]}
        assert by_id["whp-snowpipe"]["name"] == "WHP - Snowpipe"


class TestSeparateAging:
    """S3 — structured state and narrative prose age independently."""

    def test_skeleton_carries_its_own_generated_at(self):
        meta = generate_skeleton(_gather())["meta"]
        assert meta["generated_at"].endswith("Z")
        assert meta["source"] == "spine.py"

    def test_gathered_at_is_carried_through_as_upstream_provenance(self):
        gather = _gather()
        gather["meta"] = {"gathered_at": "2026-07-27T22:35:24Z"}
        assert generate_skeleton(gather)["meta"]["gathered_at"] == "2026-07-27T22:35:24Z"

    def test_a_summary_older_than_the_skeleton_is_detectable(self):
        # The whole point of S3: a fresh skeleton wrapped around two-week-old prose must be
        # distinguishable from a genuinely fresh spine.
        overlay = {
            "projects": {
                "whp-snowpipe": {
                    "summary": "written a while ago",
                    "summary_authored_at": "2026-07-28T16:15:00Z",
                }
            }
        }
        spine = apply_overlay(generate_skeleton(_gather()), overlay)
        pr = next(p for p in spine["projects"] if p["id"] == "whp-snowpipe")
        assert pr["summary_authored_at"] < spine["meta"]["generated_at"]


class TestOrphanDetection:
    """S5 — structure without judgment, and judgment without structure."""

    def test_projects_the_overlay_has_never_seen_are_reported(self):
        skeleton = generate_skeleton(_gather())
        orphans = find_orphans(skeleton, {})
        assert "whp-keypair-migration" in orphans["unknown_projects"]
        assert len(orphans["unknown_projects"]) == 7

    def test_a_new_workstream_inside_a_known_project_is_reported(self):
        skeleton = generate_skeleton(_gather())
        overlay = {"projects": {"whp-snowpipe": {"workstreams": {}}}}
        orphans = find_orphans(skeleton, overlay)
        assert any(o.startswith("whp-snowpipe/") for o in orphans["unknown_workstreams"])
        assert "whp-snowpipe" not in orphans["unknown_projects"]

    def test_judgment_whose_anchor_is_gone_is_reported_as_stale(self):
        skeleton = generate_skeleton(_gather())
        overlay = {"projects": {"retired-project": {"summary": "orphaned prose"}}}
        assert find_orphans(skeleton, overlay)["stale_projects"] == ["retired-project"]

    def test_stale_workstream_judgment_is_reported(self):
        skeleton = generate_skeleton(_gather())
        overlay = {"projects": {"whp-snowpipe": {"workstreams": {"ghost#1": {"title": "Gone"}}}}}
        assert "whp-snowpipe/ghost#1" in find_orphans(skeleton, overlay)["stale_workstreams"]

    def test_a_fully_judged_spine_reports_no_orphans(self):
        skeleton = generate_skeleton(_gather())
        overlay = {
            "projects": {
                pr["id"]: {"workstreams": {ws["key"]: {} for ws in pr["workstreams"]}}
                for pr in skeleton["projects"]
            }
        }
        assert all(v == [] for v in find_orphans(skeleton, overlay).values())


class TestWorkstreamKey:
    def test_key_is_the_smallest_member_ref(self):
        assert workstream_key(["r#3", "r#1", "r#2"]) == "r#1"

    def test_key_survives_a_member_joining(self):
        # The common case: judgment must not be orphaned when a PR joins an existing chain.
        assert workstream_key(sorted(["r#1", "r#2"])) == workstream_key(sorted(["r#1", "r#2", "r#3"]))

    def test_empty_members_yields_an_empty_key_not_a_crash(self):
        assert workstream_key([]) == ""


class TestMainCLI:
    """Thin smoke coverage of the CLI wrapper (I/O), matching test_curate.py's convention."""

    def test_main_writes_a_spine_and_reports_counts(self, tmp_path, capsys, monkeypatch):
        import spine as spine_module

        src = tmp_path / "gather.json"
        dst = tmp_path / "story.json"
        src.write_text(
            json.dumps(
                {
                    "meta": {"gathered_at": "2026-08-13T00:00:00Z"},
                    "items": [_item("r#1", project="Proj One"), _item("r#2", project="Proj One")],
                    "edges": [{"parent": "r#1", "child": "r#2", "kind": "stacked"}],
                }
            )
        )
        monkeypatch.setattr(
            "sys.argv",
            ["spine.py", "--gather", str(src), "--overlay", str(tmp_path / "none.json"), "--out", str(dst)],
        )
        assert spine_module.main() == 0

        written = json.loads(dst.read_text())
        assert [p["id"] for p in written["projects"]] == ["proj-one"]
        assert written["projects"][0]["workstreams"][0]["items"] == ["r#1", "r#2"]
        out = capsys.readouterr().out
        assert "wrote" in out
        # S5: a first run has no overlay, so every project must be reported as unjudged rather than
        # rendered silently with blank prose.
        assert "unknown_projects: proj-one" in out

    def test_main_applies_an_overlay_when_present(self, tmp_path, capsys, monkeypatch):
        import spine as spine_module

        src = tmp_path / "gather.json"
        ovl = tmp_path / "overlay.json"
        dst = tmp_path / "story.json"
        src.write_text(json.dumps({"items": [_item("r#1", project="Proj One")], "edges": []}))
        ovl.write_text(
            json.dumps({"projects": {"proj-one": {"name": "Project One", "priority": 2}}})
        )
        monkeypatch.setattr(
            "sys.argv",
            ["spine.py", "--gather", str(src), "--overlay", str(ovl), "--out", str(dst)],
        )
        assert spine_module.main() == 0
        written = json.loads(dst.read_text())
        assert written["projects"][0]["name"] == "Project One"
        assert written["projects"][0]["priority"] == 2
        assert "unknown_projects" not in capsys.readouterr().out

    def test_main_returns_1_on_an_unreadable_gather(self, tmp_path, monkeypatch, capsys):
        import spine as spine_module

        monkeypatch.setattr(
            "sys.argv",
            [
                "spine.py",
                "--gather",
                str(tmp_path / "missing.json"),
                "--out",
                str(tmp_path / "out.json"),
            ],
        )
        assert spine_module.main() == 1
        assert "cannot read a gather" in capsys.readouterr().err
