"""Tests for gather.py — the recon → raw-gather bridge that did not exist."""

from __future__ import annotations

import json

from gather import (
    assemble,
    derive_stacked_edges,
    flatten_items,
    repo_of,
)


def _pr(ref, head="", base="", repo=None, project="p"):
    it = {"ref": ref, "project": project, "head_ref": head, "base_ref": base}
    if repo is not None:
        it["repo"] = repo
    return it


def _reconciled(items, sources=None, generated="2026-08-14T10:00:00Z"):
    by_project: dict[str, list] = {}
    for it in items:
        by_project.setdefault(it.get("project", "p"), []).append(it)
    return {
        "generated_at": generated,
        "sources": sources if sources is not None else [{"source": "github", "ok": True}],
        "items_by_project": by_project,
    }


class TestRepoOf:
    def test_prefers_the_explicit_repo_field(self):
        assert repo_of({"repo": "org/dbt", "ref": "dbt#1"}) == "org/dbt"

    def test_falls_back_to_the_ref_prefix(self):
        # Matters for adapters that predate the repo field — e.g. a machine-local Ontra layer this
        # repo never sees and cannot require fields from.
        assert repo_of({"ref": "dbt#1145"}) == "dbt"

    def test_returns_empty_for_a_ref_with_no_repo_part(self):
        assert repo_of({"ref": "DE-1881"}) == ""
        assert repo_of({}) == ""


class TestFlatten:
    def test_flattens_items_by_project_into_one_list(self):
        rec = _reconciled([_pr("a#2", project="x"), _pr("a#1", project="y")])
        assert [it["ref"] for it in flatten_items(rec)] == ["a#1", "a#2"]

    def test_output_is_ref_sorted_for_byte_stability(self):
        rec = _reconciled([_pr("a#9"), _pr("a#1"), _pr("a#5")])
        refs = [it["ref"] for it in flatten_items(rec)]
        assert refs == sorted(refs)

    def test_items_without_a_ref_are_dropped(self):
        rec = _reconciled([_pr("a#1"), {"project": "p", "title": "no ref"}])
        assert len(flatten_items(rec)) == 1

    def test_empty_document_yields_no_items(self):
        assert flatten_items({}) == []


class TestStackedEdgeDerivation:
    def test_a_pr_based_on_another_prs_head_is_stacked_on_it(self):
        items = [_pr("r#1", head="feat/a", base="main"), _pr("r#2", head="feat/b", base="feat/a")]
        assert derive_stacked_edges(items) == [
            {"parent": "r#1", "child": "r#2", "kind": "stacked"}
        ]

    def test_a_pr_based_on_main_produces_no_edge(self):
        # The overwhelmingly common case. Guessing here would fire on almost every PR.
        items = [_pr("r#1", head="feat/a", base="main"), _pr("r#2", head="feat/b", base="main")]
        assert derive_stacked_edges(items) == []

    def test_branches_in_different_repos_do_not_link(self):
        # Two unrelated repos both having `feat/a` must not produce a spurious cross-repo edge.
        items = [
            _pr("a#1", head="feat/a", base="main", repo="org/a"),
            _pr("b#1", head="feat/b", base="feat/a", repo="org/b"),
        ]
        assert derive_stacked_edges(items) == []

    def test_a_three_deep_stack_produces_two_edges(self):
        items = [
            _pr("r#1", head="feat/a", base="main"),
            _pr("r#2", head="feat/b", base="feat/a"),
            _pr("r#3", head="feat/c", base="feat/b"),
        ]
        assert derive_stacked_edges(items) == [
            {"parent": "r#1", "child": "r#2", "kind": "stacked"},
            {"parent": "r#2", "child": "r#3", "kind": "stacked"},
        ]

    def test_a_self_referencing_branch_produces_no_edge(self):
        assert derive_stacked_edges([_pr("r#1", head="feat/a", base="feat/a")]) == []

    def test_missing_branch_fields_are_ignored_not_crashed(self):
        assert derive_stacked_edges([_pr("r#1"), {"ref": "r#2"}]) == []

    def test_output_is_deterministic_regardless_of_input_order(self):
        a = [_pr("r#1", head="f/a", base="main"), _pr("r#2", head="f/b", base="f/a")]
        assert derive_stacked_edges(a) == derive_stacked_edges(list(reversed(a)))


class TestAssemble:
    def test_produces_the_four_keys_the_gather_contract_requires(self):
        got = assemble(_reconciled([_pr("r#1")]))
        assert set(got) == {"meta", "items", "edges", "actions"}

    def test_output_validates_against_the_shape_curate_and_spine_consume(self):
        # The whole point: this must be loadable by both downstream stages.
        import curate
        import spine

        rec = _reconciled(
            [
                _pr("r#1", head="feat/a", base="main"),
                _pr("r#2", head="feat/b", base="feat/a"),
            ]
        )
        gather = assemble(rec)
        curated = curate.curate(gather)
        assert len(curated["items"]) == 2
        skeleton = spine.generate_skeleton(gather)
        # The two PRs are one stack, so they must land in ONE workstream — which is only possible
        # because the edge was derived. Before this module existed, edges were hand-written and this
        # was structurally impossible on real data.
        wss = skeleton["projects"][0]["workstreams"]
        assert len(wss) == 1
        assert sorted(wss[0]["items"]) == ["r#1", "r#2"]

    def test_repos_are_collected_and_sorted(self):
        rec = _reconciled([_pr("b#1", repo="org/b"), _pr("a#1", repo="org/a")])
        assert assemble(rec)["meta"]["repos"] == ["org/a", "org/b"]

    def test_generated_at_is_carried_through_as_gathered_at(self):
        got = assemble(_reconciled([_pr("r#1")], generated="2026-08-14T10:00:00Z"))
        assert got["meta"]["gathered_at"] == "2026-08-14T10:00:00Z"
        assert got["meta"]["today"] == "2026-08-14"

    def test_a_failed_source_becomes_a_down_health_row(self):
        # A degraded source silently shrinking the item count is the failure mode this whole
        # session kept finding. It must stay visible.
        rec = _reconciled(
            [_pr("r#1")],
            sources=[{"source": "github", "ok": True, "summary": "fine"},
                     {"source": "jira", "ok": False, "summary": "auth failed"}],
        )
        health = assemble(rec)["meta"]["health"]
        statuses = {h["check"]: h["status"] for h in health}
        assert statuses == {"recon:github": "ok", "recon:jira": "down"}

    def test_actions_is_empty_because_it_is_judgment_not_a_gathered_fact(self):
        assert assemble(_reconciled([_pr("r#1")]))["actions"] == {}

    def test_an_empty_recon_document_yields_a_valid_empty_gather(self):
        got = assemble({})
        assert got["items"] == [] and got["edges"] == [] and got["meta"]["repos"] == []


class TestMainCLI:
    """Thin smoke coverage of the CLI wrapper, matching the convention in test_curate.py."""

    def test_main_reads_stdin_and_writes_a_gather(self, tmp_path, capsys, monkeypatch):
        import gather as gather_module

        dst = tmp_path / "gather.raw.json"
        rec = _reconciled([_pr("r#1", head="f/a", base="main"), _pr("r#2", head="f/b", base="f/a")])
        monkeypatch.setattr("sys.stdin", __import__("io").StringIO(json.dumps(rec)))
        monkeypatch.setattr("sys.argv", ["gather.py", "--out", str(dst)])

        assert gather_module.main() == 0
        written = json.loads(dst.read_text())
        assert len(written["items"]) == 2
        assert len(written["edges"]) == 1
        assert "wrote" in capsys.readouterr().out

    def test_main_warns_loudly_when_no_edges_were_derived(self, tmp_path, capsys, monkeypatch):
        import gather as gather_module

        rec = _reconciled([_pr("r#1", head="f/a", base="main")])
        monkeypatch.setattr("sys.stdin", __import__("io").StringIO(json.dumps(rec)))
        monkeypatch.setattr("sys.argv", ["gather.py", "--out", str(tmp_path / "g.json")])
        assert gather_module.main() == 0
        assert "every workstream will be a singleton" in capsys.readouterr().err

    def test_main_returns_1_on_an_unparseable_document(self, tmp_path, capsys, monkeypatch):
        import gather as gather_module

        bad = tmp_path / "bad.json"
        bad.write_text("not json")
        monkeypatch.setattr("sys.argv", ["gather.py", "--in", str(bad), "--out", str(tmp_path / "g.json")])
        assert gather_module.main() == 1
        assert "cannot read a recon document" in capsys.readouterr().err
