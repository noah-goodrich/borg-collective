"""Tests for programs.py — borg-native program manifests and the declared edges they carry.

The load-bearing test in this file is `test_a_lane_spanning_three_repos_becomes_one_workstream`. Every
other edge source in the pipeline is repo-local by construction, so if that one passes vacuously the
whole directive is unmet.
"""

from __future__ import annotations

import json
import os
import re

import programs


FIXTURE = os.path.join(os.path.dirname(__file__), "fixtures", "programs", "three-repo-program.json")


def _fixture() -> dict:
    with open(FIXTURE) as fh:
        return json.load(fh)


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


def _write(tmp_path, project, name, doc):
    d = tmp_path / project / ".borg" / "programs"
    d.mkdir(parents=True, exist_ok=True)
    (d / name).write_text(doc if isinstance(doc, str) else json.dumps(doc))
    return str(tmp_path / project)


class TestValidate:
    def test_a_minimal_manifest_is_valid(self):
        assert programs.validate(_manifest([_row("1", "r#1")])) == []

    def test_missing_rows_is_reported_and_stops_further_checks(self):
        assert programs.validate({}) == ["rows: missing or not a list"]

    def test_every_offending_row_is_reported_in_one_pass(self):
        # The whole point of validate returning a list: a manifest with three problems is fixed in one
        # edit, not three runs.
        errors = programs.validate(
            _manifest([_row("1", ""), {"ref": "r#2"}, _row("3", "r#3", gate={"kind": "nope"})])
        )
        assert len(errors) >= 4
        assert any("rows[0]" in e for e in errors)
        assert any("rows[1]" in e and "order" in e for e in errors)
        assert any("rows[2]" in e and "gate.kind" in e for e in errors)

    def test_a_duplicate_ref_is_rejected(self):
        # Two chain positions for one item would make the derived edge set order-dependent.
        errors = programs.validate(_manifest([_row("1", "r#1"), _row("2", "r#1")]))
        assert any("duplicate ref r#1" in e for e in errors)

    def test_gate_kind_is_closed_to_decision_and_verification(self):
        for kind in ("decision", "verification"):
            gate = {"kind": kind, "blocked_by": "x", "resolved_by": "y"}
            assert programs.validate(_manifest([_row("1", "r#1", gate=gate)])) == []
        bad = {"kind": "blocked", "blocked_by": "x", "resolved_by": "y"}
        assert programs.validate(_manifest([_row("1", "r#1", gate=bad)]))

    def test_a_gate_must_name_what_settles_it(self):
        # A blocker with no pointer at its resolution is the defect the field exists to prevent.
        gate = {"kind": "decision", "blocked_by": "waiting on someone"}
        errors = programs.validate(_manifest([_row("1", "r#1", gate=gate)]))
        assert any("gate.resolved_by is required" in e for e in errors)

    def test_a_row_without_a_gate_is_fine(self):
        assert programs.validate(_manifest([_row("1", "r#1")])) == []

    def test_an_apex_without_a_ref_is_rejected(self):
        assert any("apex" in e for e in programs.validate(_manifest([_row("1", "r#1")], apex={})))

    def test_no_apex_at_all_is_valid(self):
        # Core-rule exception: a small single-ticket program legitimately has no tracker.
        assert programs.validate(_manifest([_row("1", "r#1")])) == []

    def test_the_shipped_fixture_is_valid(self):
        assert programs.validate(_fixture()) == []


class TestLaneOrdering:
    def test_rows_sort_by_declared_order_not_file_order(self):
        m = _manifest([_row("E3", "r#3", "eval"), _row("E1", "r#1", "eval"), _row("E2", "r#2", "eval")])
        assert [r["ref"] for r in programs.lanes(m)["eval"]] == ["r#1", "r#2", "r#3"]

    def test_prerequisites_sort_ahead_of_numbered_rows_in_file_order(self):
        m = _manifest([_row("E1", "r#9", "eval"), _row("–", "r#1", "eval"), _row("–", "r#2", "eval")])
        assert [r["ref"] for r in programs.lanes(m)["eval"]] == ["r#1", "r#2", "r#9"]

    def test_double_digit_order_sorts_numerically_not_lexically(self):
        m = _manifest([_row("E10", "r#10", "eval"), _row("E2", "r#2", "eval")])
        assert [r["ref"] for r in programs.lanes(m)["eval"]] == ["r#2", "r#10"]

    def test_rows_with_no_lane_form_one_default_lane(self):
        m = _manifest([_row("1", "r#1"), _row("2", "r#2")])
        assert list(programs.lanes(m)) == [programs.DEFAULT_LANE]

    def test_refless_rows_are_excluded_from_lanes(self):
        assert programs.lanes(_manifest([_row("1", "")])) == {}


class TestDeriveEdges:
    def test_consecutive_rows_in_a_lane_are_stacked(self):
        m = _manifest([_row("1", "r#1"), _row("2", "r#2"), _row("3", "r#3")])
        stacked = [e for e in programs.derive_edges(m) if e["kind"] == "stacked"]
        assert stacked == [
            {"parent": "r#1", "child": "r#2", "kind": "stacked", "source": "declared"},
            {"parent": "r#2", "child": "r#3", "kind": "stacked", "source": "declared"},
        ]

    def test_separate_lanes_do_not_link_to_each_other(self):
        # Lane ids are deliberately prefixed so cross-lane rows imply no total order. An edge between
        # lanes would invent a dependency nobody declared.
        m = _manifest([_row("E1", "r#1", "eval"), _row("K1", "r#2", "keypair")])
        assert [e for e in programs.derive_edges(m) if e["kind"] == "stacked"] == []

    def test_a_lane_spanning_three_repos_yields_cross_repo_edges(self):
        # THE criterion (PM3). Branch topology cannot produce these: a base branch is a repo-local
        # name, so every derived edge is repo-local. Only a declaration crosses repos.
        edges = programs.derive_edges(_fixture())
        stacked = {(e["parent"], e["child"]) for e in edges if e["kind"] == "stacked"}
        assert ("acme/platform#834", "acme/warehouse#302") in stacked
        assert ("acme/warehouse#302", "acme/pipelines#301") in stacked
        repos = {r.split("#")[0] for pair in stacked for r in pair}
        assert len(repos) >= 3

    def test_the_merged_prerequisite_anchors_the_chain(self):
        stacked = {
            (e["parent"], e["child"])
            for e in programs.derive_edges(_fixture())
            if e["kind"] == "stacked"
        }
        assert ("acme/platform#801", "acme/platform#834") in stacked

    def test_every_row_gets_an_apex_edge_when_an_apex_exists(self):
        apex = [e for e in programs.derive_edges(_fixture()) if e["kind"] == "apex"]
        assert len(apex) == len(_fixture()["rows"])
        assert {e["parent"] for e in apex} == {"acme/platform#900"}

    def test_no_apex_means_no_apex_edges(self):
        m = _manifest([_row("1", "r#1"), _row("2", "r#2")])
        assert [e for e in programs.derive_edges(m) if e["kind"] == "apex"] == []

    def test_a_row_that_is_the_apex_gets_no_self_edge(self):
        m = _manifest([_row("1", "r#1")], apex={"ref": "r#1"})
        assert [e for e in programs.derive_edges(m) if e["kind"] == "apex"] == []

    def test_every_edge_carries_declared_provenance(self):
        # PM5: provenance is what makes a wrong edge falsifiable.
        assert all(e["source"] == "declared" for e in programs.derive_edges(_fixture()))

    def test_output_is_deterministic_regardless_of_row_order(self):
        rows = [_row("1", "r#1"), _row("2", "r#2"), _row("3", "r#3")]
        assert programs.derive_edges(_manifest(rows)) == programs.derive_edges(
            _manifest(list(reversed(rows)))
        )

    def test_an_empty_manifest_yields_no_edges(self):
        assert programs.derive_edges({"rows": []}) == []


class TestUnmappedGates:
    def test_a_prose_blocker_is_reported_not_turned_into_an_edge(self):
        # PM4. "waiting on a colleague's review" names a real blocker with no ref. Guessing at one
        # would manufacture a dependency on nothing.
        edges = programs.derive_edges(_fixture())
        assert not any("colleague" in e["parent"] for e in edges)
        gates = programs.unmapped_gates(_fixture())
        assert {g["ref"] for g in gates} == {"acme/platform#834", "acme/warehouse#293"}

    def test_gate_kind_is_carried_so_verification_is_distinguishable(self):
        # A verification with declared outcomes is never a blocker on a person — anyone can run it —
        # so the awaiting-you tier must be able to tell the two apart.
        kinds = {g["ref"]: g["kind"] for g in programs.unmapped_gates(_fixture())}
        assert kinds["acme/platform#834"] == "decision"
        assert kinds["acme/warehouse#293"] == "verification"

    def test_rows_without_gates_are_not_reported(self):
        assert programs.unmapped_gates(_manifest([_row("1", "r#1")])) == []


class TestLooksLikeManifest:
    def test_requires_a_rows_list(self):
        assert programs.looks_like_manifest({"rows": []})
        assert not programs.looks_like_manifest({"rows": "nope"})
        assert not programs.looks_like_manifest({"projects": {}})
        assert not programs.looks_like_manifest([])
        assert not programs.looks_like_manifest("string")


class TestDiscover:
    def test_loads_a_valid_manifest(self, tmp_path):
        p = _write(tmp_path, "proj", "a.json", _manifest([_row("1", "r#1")]))
        manifests, warnings = programs.discover([p])
        assert len(manifests) == 1 and warnings == []
        assert manifests[0]["program"] == "a"

    def test_a_project_with_no_programs_dir_is_silent(self, tmp_path):
        (tmp_path / "empty").mkdir()
        assert programs.discover([str(tmp_path / "empty")]) == ([], [])

    def test_a_nonexistent_project_dir_is_silent(self, tmp_path):
        assert programs.discover([str(tmp_path / "gone")]) == ([], [])

    def test_malformed_json_is_skipped_with_a_named_warning(self, tmp_path):
        # An unnamed skip is indistinguishable from a file that was never there.
        p = _write(tmp_path, "proj", "bad.json", "{not json")
        manifests, warnings = programs.discover([p])
        assert manifests == []
        assert len(warnings) == 1 and "bad.json" in warnings[0]

    def test_unrelated_json_is_skipped_as_not_a_manifest(self, tmp_path):
        p = _write(tmp_path, "proj", "settings.json", {"theme": "dark"})
        manifests, warnings = programs.discover([p])
        assert manifests == []
        assert "not a program manifest" in warnings[0]

    def test_an_invalid_manifest_is_skipped_with_its_errors_named(self, tmp_path):
        p = _write(tmp_path, "proj", "bad.json", _manifest([_row("1", "")]))
        manifests, warnings = programs.discover([p])
        assert manifests == []
        assert "invalid manifest" in warnings[0] and "missing ref" in warnings[0]

    def test_one_bad_manifest_does_not_suppress_a_good_one(self, tmp_path):
        # The failure this guards: a single malformed file blanking the whole spine.
        p = _write(tmp_path, "proj", "good.json", _manifest([_row("1", "r#1")]))
        _write(tmp_path, "proj", "bad.json", "{nope")
        manifests, warnings = programs.discover([p])
        assert len(manifests) == 1 and len(warnings) == 1

    def test_non_json_files_are_ignored(self, tmp_path):
        p = _write(tmp_path, "proj", "a.json", _manifest([_row("1", "r#1")]))
        (tmp_path / "proj" / ".borg" / "programs" / "README.md").write_text("notes")
        manifests, warnings = programs.discover([p])
        assert len(manifests) == 1 and warnings == []

    def test_manifests_carry_their_source_path(self, tmp_path):
        p = _write(tmp_path, "proj", "a.json", _manifest([_row("1", "r#1")]))
        assert programs.discover([p])[0][0]["_path"].endswith("a.json")

    def test_discovery_reads_only_from_borg_programs(self, tmp_path):
        # PM2: nothing outside a project's own .borg/programs is ever opened.
        p = tmp_path / "proj"
        (p / ".borg").mkdir(parents=True)
        (p / ".borg" / "elsewhere.json").write_text(json.dumps(_manifest([_row("1", "r#1")])))
        (p / "stack.json").write_text(json.dumps(_manifest([_row("1", "r#2")])))
        assert programs.discover([str(p)]) == ([], [])

    def test_multiple_projects_are_all_swept(self, tmp_path):
        a = _write(tmp_path, "a", "x.json", _manifest([_row("1", "a#1")]))
        b = _write(tmp_path, "b", "y.json", _manifest([_row("1", "b#1")]))
        manifests, _ = programs.discover([a, b])
        assert len(manifests) == 2


class TestIndependence:
    """PM8. borg must work identically on a machine that has never heard of any other plugin.

    This is asserted mechanically rather than by review because the constraint was already violated
    once by design drift: an earlier draft of this work had borg reading manifests directly out of an
    external plugin's directory. A grep is cheap; remembering is not.
    """

    FORBIDDEN = ("ai-data-engineer", "stacked-pr-program", "stamp_stack")

    def _sources(self):
        here = os.path.dirname(__file__)
        paths = [os.path.join(here, "programs.py"), os.path.join(here, "gather.py"), __file__]
        fixtures = os.path.join(here, "fixtures", "programs")
        paths += [os.path.join(fixtures, n) for n in sorted(os.listdir(fixtures))]
        return paths

    def test_no_module_or_fixture_references_an_external_plugin(self):
        offenders = []
        for path in self._sources():
            with open(path) as fh:
                body = fh.read()
            for token in self.FORBIDDEN:
                # This file must be able to NAME what it forbids without tripping its own check.
                if token in body and os.path.basename(path) != os.path.basename(__file__):
                    offenders.append(f"{os.path.basename(path)}: {token}")
        assert offenders == [], f"external-plugin references found: {offenders}"

    def test_no_module_hardcodes_a_path_into_a_sibling_repo(self):
        """Only STRING LITERALS count — a docstring may legitimately show an example path.

        Checking whole lines instead flagged `gather.py`'s own usage example, which is documentation,
        not a dependency. The thing worth forbidding is a path baked into code.
        """
        offenders = []
        for path in self._sources():
            if os.path.basename(path) == os.path.basename(__file__):
                continue
            with open(path) as fh:
                for n, line in enumerate(fh, 1):
                    for literal in re.findall(r"""["']([^"']*)["']""", line):
                        # `~/.local/state/borg/...` is borg's OWN state dir and correct. What must
                        # never appear is a path into a sibling checkout under the dev root.
                        if "/dev/" in literal:
                            offenders.append(f"{os.path.basename(path)}:{n} -> {literal}")
        assert offenders == [], f"hardcoded sibling-repo paths: {offenders}"

    def test_discovery_of_an_absent_project_is_not_an_error(self, tmp_path):
        # The personal-machine case: nothing configured, nothing present, still succeeds.
        assert programs.discover([]) == ([], [])
        assert programs.discover([str(tmp_path / "never-existed")]) == ([], [])


class TestEdgesFrom:
    def test_unions_edges_across_manifests(self, tmp_path):
        a = _manifest([_row("1", "a#1"), _row("2", "a#2")])
        b = _manifest([_row("1", "b#1"), _row("2", "b#2")])
        edges = programs.edges_from([a, b])
        assert len(edges) == 2

    def test_the_same_dependency_declared_twice_collapses(self):
        # Two programs naming one shared dependency is normal, not an error.
        m = _manifest([_row("1", "r#1"), _row("2", "r#2")])
        assert programs.edges_from([m, dict(m)]) == programs.edges_from([m])

    def test_no_manifests_yields_no_edges(self):
        assert programs.edges_from([]) == []
