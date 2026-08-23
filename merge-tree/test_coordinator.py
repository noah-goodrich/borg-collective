"""Tests for coordinator.py — `borg program`, the PM6/PM7 sync coordinator.

Two load-bearing tests: `test_coordinator_never_names_the_external_schema` (PM6, "no gh call, no
PR-body template, no external-schema field names") and `test_three_way_audit_never_mutates_anything`
(PM7, "never silently reconcile" — the audit is read-only by construction, not by discipline).
"""

from __future__ import annotations

import json
import os
import stat

import pytest

import coordinator
import programs


def _row(order, ref, status="stacked", **extra):
    return {"order": order, "ref": ref, "status": status, **extra}


def _manifest(program, rows):
    return {"program": program, "rows": rows}


def _write_manifest_dir(tmp_path, project, program, rows):
    d = tmp_path / project / ".borg" / "programs"
    d.mkdir(parents=True, exist_ok=True)
    (d / f"{program}.json").write_text(json.dumps(_manifest(program, rows)))
    return str(tmp_path / project)


def _make_target(tmp_path, name, script):
    d = tmp_path / "targets"
    d.mkdir(parents=True, exist_ok=True)
    path = d / f"borg-sync-target-{name}"
    path.write_text(script)
    path.chmod(path.stat().st_mode | stat.S_IEXEC)
    return str(d)


class TestDiscoverSyncTarget:
    def test_no_target_configured_is_not_an_error(self, tmp_path):
        assert coordinator.discover_sync_target([str(tmp_path / "nowhere")]) is None

    def test_finds_an_executable_named_by_convention(self, tmp_path):
        d = _make_target(tmp_path, "stacked-pr", "#!/bin/sh\necho '{}'\n")
        assert coordinator.discover_sync_target([d]).endswith("borg-sync-target-stacked-pr")

    def test_a_non_executable_file_is_not_discovered(self, tmp_path):
        d = tmp_path / "targets"
        d.mkdir()
        (d / "borg-sync-target-nope").write_text("not executable")
        assert coordinator.discover_sync_target([str(d)]) is None

    def test_an_unrelated_file_in_the_directory_is_skipped(self, tmp_path):
        d = tmp_path / "targets"
        d.mkdir()
        (d / "README.md").write_text("notes")
        assert coordinator.discover_sync_target([str(d)]) is None

    def test_first_on_path_wins(self, tmp_path):
        first = _make_target(tmp_path / "a", "x", "#!/bin/sh\necho '{}'\n")
        (tmp_path / "b").mkdir()
        second = tmp_path / "b" / "borg-sync-target-x"
        second.write_text("#!/bin/sh\necho '{}'\n")
        second.chmod(second.stat().st_mode | stat.S_IEXEC)
        assert coordinator.discover_sync_target([first, str(tmp_path / "b")]) == os.path.join(
            first, "borg-sync-target-x"
        )


class TestSyncTargetSearchDirs:
    def test_defaults_when_no_env_override(self):
        assert coordinator.sync_target_search_dirs({}) == [coordinator.DEFAULT_SEARCH_DIR]

    def test_env_override_is_colon_separated(self):
        env = {coordinator.ENV_VAR: "/a:/b"}
        assert coordinator.sync_target_search_dirs(env) == ["/a", "/b"]


class TestRunTarget:
    def test_a_well_behaved_target_returns_its_json(self, tmp_path):
        d = _make_target(
            tmp_path,
            "ok",
            '#!/bin/sh\ncat <<\'EOF\'\n{"ok": true, "rows": [{"ref": "r#1", "status": "merged"}]}\nEOF\n',
        )
        target = os.path.join(d, "borg-sync-target-ok")
        result = coordinator.run_target(target, "plan", [])
        assert result == {"ok": True, "rows": [{"ref": "r#1", "status": "merged"}]}

    def test_a_nonzero_exit_is_reported_not_raised(self, tmp_path):
        d = _make_target(tmp_path, "bad", "#!/bin/sh\necho 'boom' >&2\nexit 1\n")
        target = os.path.join(d, "borg-sync-target-bad")
        result = coordinator.run_target(target, "plan", [])
        assert result["ok"] is False and "boom" in result["error"]

    def test_malformed_stdout_is_reported_not_raised(self, tmp_path):
        d = _make_target(tmp_path, "garbled", "#!/bin/sh\necho 'not json'\n")
        target = os.path.join(d, "borg-sync-target-garbled")
        result = coordinator.run_target(target, "plan", [])
        assert result["ok"] is False and "malformed" in result["error"]

    def test_a_missing_binary_is_reported_not_raised(self, tmp_path):
        result = coordinator.run_target(str(tmp_path / "nope"), "plan", [])
        assert result["ok"] is False

    def test_non_object_json_output_is_reported_not_raised(self, tmp_path):
        d = _make_target(tmp_path, "array", "#!/bin/sh\necho '[1, 2, 3]'\n")
        target = os.path.join(d, "borg-sync-target-array")
        result = coordinator.run_target(target, "plan", [])
        assert result["ok"] is False and "not a JSON object" in result["error"]


class TestFlattenRows:
    def test_flattens_across_manifests_sorted_by_ref(self):
        rows = coordinator.flatten_rows(
            [_manifest("a", [_row("1", "z#1")]), _manifest("b", [_row("1", "a#1")])]
        )
        assert [r["ref"] for r in rows] == ["a#1", "z#1"]


class TestMergedButOpen:
    def test_flags_a_copy_marking_merged_when_recon_says_open(self):
        rows = [{"program": "p", "ref": "r#1", "status": "merged"}]
        findings = coordinator.merged_but_open(rows, {"r#1": "OPEN"}, "borg's copy")
        assert len(findings) == 1 and findings[0]["kind"] == "merged_but_open"

    def test_says_nothing_when_recon_agrees(self):
        rows = [{"program": "p", "ref": "r#1", "status": "merged"}]
        assert coordinator.merged_but_open(rows, {"r#1": "MERGED"}, "borg's copy") == []

    def test_says_nothing_when_recon_has_no_opinion(self):
        rows = [{"program": "p", "ref": "r#1", "status": "merged"}]
        assert coordinator.merged_but_open(rows, {}, "borg's copy") == []


class TestThreeWayAudit:
    def test_no_target_skips_the_two_copy_comparisons(self):
        borg_rows = [{"program": "p", "ref": "r#1", "status": "stacked"}]
        findings = coordinator.three_way_audit(borg_rows, target_report=None, recon_states={})
        assert findings == []

    def test_target_unreachable_is_its_own_finding(self):
        borg_rows = [{"program": "p", "ref": "r#1", "status": "stacked"}]
        findings = coordinator.three_way_audit(
            borg_rows, target_report={"ok": False, "error": "timeout"}, recon_states={}
        )
        assert findings == [
            {"kind": "target_unreachable", "ref": "", "copy_says": "", "reality_says": "timeout"}
        ]

    def test_present_only_in_one_copy_is_named_on_both_sides(self):
        borg_rows = [
            {"program": "p", "ref": "r#1", "status": "stacked"},
            {"program": "p", "ref": "r#2", "status": "stacked"},
        ]
        target_report = {"ok": True, "rows": [{"ref": "r#1", "status": "stacked"}, {"ref": "r#3", "status": "stacked"}]}
        findings = coordinator.three_way_audit(borg_rows, target_report, recon_states={})
        kinds = {(f["kind"], f["ref"]) for f in findings}
        assert ("present_only_in_borg", "r#2") in kinds
        assert ("present_only_in_target", "r#3") in kinds

    def test_status_disagreement_between_the_two_copies_is_reported(self):
        borg_rows = [{"program": "p", "ref": "r#1", "status": "stacked"}]
        target_report = {"ok": True, "rows": [{"ref": "r#1", "status": "review"}]}
        findings = coordinator.three_way_audit(borg_rows, target_report, recon_states={})
        assert any(f["kind"] == "status_disagreement" and f["ref"] == "r#1" for f in findings)

    def test_agreement_produces_no_findings(self):
        borg_rows = [{"program": "p", "ref": "r#1", "status": "stacked"}]
        target_report = {"ok": True, "rows": [{"ref": "r#1", "status": "stacked"}]}
        assert coordinator.three_way_audit(borg_rows, target_report, recon_states={}) == []

    def test_three_way_audit_never_mutates_anything(self, tmp_path):
        """PM7: 'never silently reconcile'. Running the audit must not touch the filesystem."""
        before = sorted(tmp_path.rglob("*"))
        borg_rows = [{"program": "p", "ref": "r#1", "status": "stacked"}]
        target_report = {"ok": True, "rows": [{"ref": "r#1", "status": "review"}]}
        coordinator.three_way_audit(borg_rows, target_report, recon_states={"r#1": "OPEN"})
        assert sorted(tmp_path.rglob("*")) == before


class TestLocalAudit:
    def test_runs_with_no_target_and_no_subprocess(self):
        manifests = [_manifest("p", [_row("1", "r#1", status="merged")])]
        findings = coordinator.local_audit(manifests, {"r#1": "OPEN"})
        assert findings == [
            {
                "kind": "merged_but_open",
                "ref": "r#1",
                "copy_says": "borg's copy marks it merged",
                "reality_says": "recon reports OPEN",
            }
        ]


class TestReconStatesFrom:
    def test_first_occurrence_wins(self):
        items = [{"ref": "r#1", "state": "OPEN"}, {"ref": "r#1", "state": "MERGED"}]
        assert coordinator.recon_states_from(items) == {"r#1": "OPEN"}

    def test_items_without_a_ref_or_state_are_skipped(self):
        assert coordinator.recon_states_from([{"ref": "r#1"}, {"state": "OPEN"}]) == {}


class TestLoadReconItems:
    def test_accepts_a_bare_items_list(self, tmp_path):
        p = tmp_path / "items.json"
        p.write_text(json.dumps([{"ref": "r#1"}]))
        assert coordinator.load_recon_items(str(p)) == [{"ref": "r#1"}]

    def test_accepts_a_full_gather_doc(self, tmp_path):
        p = tmp_path / "gather.json"
        p.write_text(json.dumps({"items": [{"ref": "r#1"}]}))
        assert coordinator.load_recon_items(str(p)) == [{"ref": "r#1"}]

    def test_accepts_a_reconciled_recon_doc(self, tmp_path):
        p = tmp_path / "recon.json"
        p.write_text(json.dumps({"items_by_project": {"proj": [{"ref": "r#1"}]}}))
        assert coordinator.load_recon_items(str(p)) == [{"ref": "r#1"}]

    def test_none_path_yields_no_items(self):
        assert coordinator.load_recon_items(None) == []


class TestSyncBorg:
    def _discovered(self, project_dir, program="prog-a"):
        programs.write_manifest(str(project_dir), program, _manifest(program, [_row("1", "r#1")]))
        manifests, _ = programs.discover([str(project_dir)])
        return manifests

    def test_writes_each_manifest_via_the_native_writer(self, tmp_path):
        manifests = self._discovered(tmp_path / "proj")
        written, warnings = coordinator.sync_borg(manifests)
        assert len(written) == 1
        assert warnings == []
        assert os.path.exists(written[0])

    def test_a_manifest_with_no_path_stamp_is_skipped_not_raised(self):
        manifests = [_manifest("prog-a", [_row("1", "r#1")])]
        assert coordinator.sync_borg(manifests) == ([], [])

    def test_a_manifest_whose_filename_differs_from_its_program_rewrites_in_place(self, tmp_path):
        # Opus round 2, finding 1: writing back via a program-derived name spawned a SECOND file
        # (three-repo-program.json declaring program auth-hardening -> a new auth-hardening.json),
        # two copies of one program that then diverge silently. Sync must rewrite the source file.
        import json as _json

        pdir = tmp_path / "proj" / ".borg" / "programs"
        pdir.mkdir(parents=True)
        m = _manifest("auth-hardening", [_row("1", "r#1")])
        (pdir / "three-repo-program.json").write_text(_json.dumps(m))
        manifests, _ = programs.discover([str(tmp_path / "proj")])
        written, warnings = coordinator.sync_borg(manifests)
        assert written == [str(pdir / "three-repo-program.json")]
        assert sorted(f.name for f in pdir.iterdir()) == ["three-repo-program.json"]
        assert warnings == []

    def test_two_files_declaring_one_program_in_one_project_both_survive_with_a_warning(self, tmp_path):
        # The same-project half of the blocker: b.json and z.json both declaring program "b" must
        # not overwrite each other, and the contention is named.
        import json as _json

        pdir = tmp_path / "proj" / ".borg" / "programs"
        pdir.mkdir(parents=True)
        (pdir / "b.json").write_text(_json.dumps(_manifest("b", [_row("1", "r#1")])))
        (pdir / "z.json").write_text(_json.dumps(_manifest("b", [_row("1", "r#2")])))
        manifests, _ = programs.discover([str(tmp_path / "proj")])
        written, warnings = coordinator.sync_borg(manifests)
        assert len(written) == 2
        assert sorted(f.name for f in pdir.iterdir()) == ["b.json", "z.json"]
        assert _json.loads((pdir / "b.json").read_text())["rows"][0]["ref"] == "r#1"
        assert _json.loads((pdir / "z.json").read_text())["rows"][0]["ref"] == "r#2"
        assert len(warnings) == 1 and '"b"' in warnings[0].replace("'", '"')

    def test_same_program_in_two_projects_writes_each_to_its_own_home(self, tmp_path):
        # Opus review MERGE-BLOCKER: the old program-keyed map wrote the loser's manifest into
        # the OTHER project's .borg/programs/. Each manifest must land in its own project root,
        # and the duplicate-name condition is warned, not silently resolved.
        dir_a, dir_b = tmp_path / "reveal", tmp_path / "ingle"
        manifests = self._discovered(dir_a, "shared-prog") + self._discovered(dir_b, "shared-prog")
        written, warnings = coordinator.sync_borg(manifests)
        assert len(written) == 2
        assert written[0].startswith(str(dir_a)) and written[1].startswith(str(dir_b))
        assert len(warnings) == 1 and "shared-prog" in warnings[0]


class TestProjectDirOf:
    def test_recovers_project_root_from_the_discover_stamped_path(self, tmp_path):
        project_dir = str(tmp_path / "proj")
        path = programs.write_manifest(project_dir, "prog-a", _manifest("prog-a", [_row("1", "r#1")]))
        manifests, _ = programs.discover([project_dir])
        assert manifests[0]["_path"] == path
        assert coordinator._project_dir_of(manifests[0]) == project_dir


class _Args:
    def __init__(self, programs_dir, recon=None):
        self.programs_dir = programs_dir
        self.recon = recon


class TestCmdList:
    def test_reports_programs_and_row_counts(self, tmp_path, capsys):
        d = _write_manifest_dir(tmp_path, "proj", "a", [_row("1", "r#1")])
        assert coordinator.cmd_list(_Args([d])) == 0
        out = capsys.readouterr().out
        assert "a: 1 row(s)" in out and "1 program(s), 0 skipped" in out

    def test_names_a_skipped_manifest_but_still_succeeds(self, tmp_path, capsys):
        d = tmp_path / "proj" / ".borg" / "programs"
        d.mkdir(parents=True)
        (d / "bad.json").write_text("{not json")
        assert coordinator.cmd_list(_Args([str(tmp_path / "proj")])) == 0
        err = capsys.readouterr().err
        assert "MANIFEST SKIPPED" in err


class TestCmdPlan:
    def test_exits_nonzero_on_malformed_input(self, tmp_path, capsys, monkeypatch):
        monkeypatch.setenv(coordinator.ENV_VAR, str(tmp_path / "no-target"))
        d = tmp_path / "proj" / ".borg" / "programs"
        d.mkdir(parents=True)
        (d / "bad.json").write_text("{not json")
        assert coordinator.cmd_plan(_Args([str(tmp_path / "proj")])) == 1

    def test_reports_findings_without_writing_anything(self, tmp_path, capsys, monkeypatch):
        monkeypatch.setenv(coordinator.ENV_VAR, str(tmp_path / "no-target"))
        d = _write_manifest_dir(tmp_path, "proj", "a", [_row("1", "r#1", status="merged")])
        before = sorted((tmp_path / "proj").rglob("*"))
        rc = coordinator.cmd_plan(_Args([d]))
        assert rc == 0
        out, err = capsys.readouterr()
        assert "no publish target found" in err
        assert "plan: 1 program(s), 1 row(s)" in out
        # PM7: plan is read-only — running it must not add or change any file under the project.
        assert sorted((tmp_path / "proj").rglob("*")) == before

    def test_checks_reality_against_a_recon_doc(self, tmp_path, capsys, monkeypatch):
        monkeypatch.setenv(coordinator.ENV_VAR, str(tmp_path / "no-target"))
        d = _write_manifest_dir(tmp_path, "proj", "a", [_row("1", "r#1", status="merged")])
        recon_path = tmp_path / "recon.json"
        recon_path.write_text(json.dumps({"items": [{"ref": "r#1", "state": "OPEN"}]}))
        rc = coordinator.cmd_plan(_Args([d], recon=str(recon_path)))
        assert rc == 0
        out = capsys.readouterr().out
        assert "merged_but_open: r#1" in out


class TestCmdSync:
    def test_refuses_to_sync_malformed_input(self, tmp_path):
        d = tmp_path / "proj" / ".borg" / "programs"
        d.mkdir(parents=True)
        (d / "bad.json").write_text("{not json")
        assert coordinator.cmd_sync(_Args([str(tmp_path / "proj")])) == 1

    def test_writes_borgs_copy_and_reports_no_target(self, tmp_path, capsys, monkeypatch):
        monkeypatch.setenv(coordinator.ENV_VAR, str(tmp_path / "no-target"))
        d = _write_manifest_dir(tmp_path, "proj", "a", [_row("1", "r#1")])
        rc = coordinator.cmd_sync(_Args([d]))
        assert rc == 0
        out, err = capsys.readouterr()
        assert "wrote 1 manifest(s)" in out
        assert "no publish target found" in err

    def test_dispatches_to_a_discovered_target(self, tmp_path, capsys, monkeypatch):
        target_dir = _make_target(
            tmp_path,
            "ok",
            '#!/bin/sh\ncat <<\'EOF\'\n{"ok": true, "rows": [{"ref": "r#1", "status": "merged"}]}\nEOF\n',
        )
        monkeypatch.setenv(coordinator.ENV_VAR, target_dir)
        d = _write_manifest_dir(tmp_path, "proj", "a", [_row("1", "r#1")])
        rc = coordinator.cmd_sync(_Args([d]))
        assert rc == 0
        out = capsys.readouterr().out
        assert "dispatched to borg-sync-target-ok (1 row(s) reported)" in out

    def test_a_failed_target_dispatch_is_reported_and_nonzero(self, tmp_path, capsys, monkeypatch):
        target_dir = _make_target(tmp_path, "bad", "#!/bin/sh\nexit 1\n")
        monkeypatch.setenv(coordinator.ENV_VAR, target_dir)
        d = _write_manifest_dir(tmp_path, "proj", "a", [_row("1", "r#1")])
        rc = coordinator.cmd_sync(_Args([d]))
        assert rc == 1
        assert "target dispatch failed" in capsys.readouterr().err


class TestMain:
    def test_list_via_argv(self, tmp_path, capsys, monkeypatch):
        d = _write_manifest_dir(tmp_path, "proj", "a", [_row("1", "r#1")])
        monkeypatch.setattr("sys.argv", ["coordinator.py", "list", "--programs-dir", d])
        assert coordinator.main() == 0
        assert "1 program(s), 0 skipped" in capsys.readouterr().out

    def test_requires_a_subcommand(self, monkeypatch):
        monkeypatch.setattr("sys.argv", ["coordinator.py"])
        with pytest.raises(SystemExit):
            coordinator.main()


class TestIndependenceAndBoundary:
    """PM6/PM8: the coordinator delegates every write and knows nothing about the external schema."""

    FORBIDDEN_CALLS = ("subprocess.run([\"gh\"", "'gh pr", '"gh pr', "gh issue", "gh pr edit", "gh pr create")
    # PM6: "no external-schema field names" — the stacked-PR program's own key shape (SCHEMA.md's
    # "row key" table: `repo` + `number`, distinct from borg's `ref`) and its writer's name.
    FORBIDDEN_FIELDS = ("stamp_stack", "\"number\":", "'number':", "repo_number", "pr_body", "PR_BODY_TEMPLATE")

    def test_no_gh_invocation_anywhere_in_the_coordinator(self):
        with open(coordinator.__file__) as fh:
            body = fh.read()
        for token in self.FORBIDDEN_CALLS:
            assert token not in body, f"found a gh-shaped call: {token}"

    def test_no_external_schema_field_name_or_template(self):
        with open(coordinator.__file__) as fh:
            body = fh.read()
        for token in self.FORBIDDEN_FIELDS:
            assert token not in body, f"found an external-schema token: {token}"

    def test_no_module_or_fixture_references_an_external_plugin(self):
        offenders = []
        forbidden = ("ai-data-engineer", "stacked-pr-program", "stamp_stack")
        with open(coordinator.__file__) as fh:
            body = fh.read()
        for token in forbidden:
            if token in body:
                offenders.append(token)
        assert offenders == [], f"external-plugin references found: {offenders}"
