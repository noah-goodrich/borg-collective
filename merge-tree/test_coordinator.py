"""Tests for coordinator.py — `borg program`, the PM6/PM7 sync coordinator.

Two load-bearing tests: `test_coordinator_never_names_the_external_schema` (PM6, "no gh call, no
PR-body template, no external-schema field names") and `test_three_way_audit_never_mutates_anything`
(PM7, "never silently reconcile" — the audit is read-only by construction, not by discipline).
"""

from __future__ import annotations

import json
import os
import pathlib
import re
import stat

import pytest

import coordinator
from borg_core.manifest import shell


def _row(order, ref, status="stacked", **extra):
    return {"order": order, "ref": ref, "status": status, **extra}


REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _manifest(chain, rows):
    """An in-memory manifest shaped like `shell.discover` output: identity under `_id`, none declared."""
    return {"_id": chain, "rows": rows}


def _write_stacks(tmp_path, project, stem, rows, **declared):
    """The tool-neutral second root: `<project>/.stacks/<stem>.json`, no `program` key unless declared."""
    d = tmp_path / project / ".stacks"
    d.mkdir(parents=True, exist_ok=True)
    (d / f"{stem}.json").write_text(json.dumps({"rows": rows, **declared}))
    return str(tmp_path / project)


def _tree_bytes(root):
    """`{relative path: bytes}` for every file under `root`: the oracle for "nothing was written"."""
    return {str(p.relative_to(root)): p.read_bytes() for p in sorted(root.rglob("*")) if p.is_file()}


def _write_manifest_dir(tmp_path, project, stem, rows, directory="chains", **declared):
    """A project whose `.borg/<directory>/<stem>.json` declares `rows` and, by default, NO `program` key.

    The key is left out on purpose. Every fixture here used to set `program` itself, so the code under
    test never had to DERIVE the manifest's identity from the filename -- which is the one thing the
    borg_core reader does, and the reason a repoint that read `m.get("program")` would have passed all
    of them while syncing nothing. A test that needs a declared id passes `program=...` explicitly.
    """
    d = tmp_path / project / ".borg" / directory
    d.mkdir(parents=True, exist_ok=True)
    (d / f"{stem}.json").write_text(json.dumps({"rows": rows, **declared}))
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
            '#!/bin/sh\ncat <<\'EOF\'\n{"ok": true, "rows": [{"ref": "o/r#1", "status": "merged"}]}\nEOF\n',
        )
        target = os.path.join(d, "borg-sync-target-ok")
        result = coordinator.run_target(target, "plan", [])
        assert result == {"ok": True, "rows": [{"ref": "o/r#1", "status": "merged"}]}

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
            [_manifest("a", [_row("1", "o/z#1")]), _manifest("b", [_row("1", "o/a#1")])]
        )
        assert [r["ref"] for r in rows] == ["o/a#1", "o/z#1"]
        assert [r["chain"] for r in rows] == ["b", "a"]

    def test_identity_is_the_stamped_id_not_a_declared_program_key(self):
        manifest = {"_id": "from-the-reader", "program": "declared", "rows": [_row("1", "o/r#1")]}
        assert [r["chain"] for r in coordinator.flatten_rows([manifest])] == ["from-the-reader"]

    def test_a_dict_with_a_source_path_but_no_id_is_identified_by_its_filename_stem(self):
        manifest = {"_path": "/x/.borg/chains/stem-only.json", "rows": [_row("1", "o/r#1")]}
        assert [r["chain"] for r in coordinator.flatten_rows([manifest])] == ["stem-only"]


class TestMergedButOpen:
    def test_flags_a_copy_marking_merged_when_recon_says_open(self):
        rows = [{"chain": "p", "ref": "o/r#1", "status": "merged"}]
        findings = coordinator.merged_but_open(rows, {"o/r#1": "OPEN"}, "borg's copy")
        assert len(findings) == 1 and findings[0]["kind"] == "merged_but_open"

    def test_says_nothing_when_recon_agrees(self):
        rows = [{"chain": "p", "ref": "o/r#1", "status": "merged"}]
        assert coordinator.merged_but_open(rows, {"o/r#1": "MERGED"}, "borg's copy") == []

    def test_says_nothing_when_recon_has_no_opinion(self):
        rows = [{"chain": "p", "ref": "o/r#1", "status": "merged"}]
        assert coordinator.merged_but_open(rows, {}, "borg's copy") == []


class TestThreeWayAudit:
    def test_no_target_skips_the_two_copy_comparisons(self):
        borg_rows = [{"chain": "p", "ref": "o/r#1", "status": "stacked"}]
        findings = coordinator.three_way_audit(borg_rows, target_report=None, recon_states={})
        assert findings == []

    def test_target_unreachable_is_its_own_finding(self):
        borg_rows = [{"chain": "p", "ref": "o/r#1", "status": "stacked"}]
        findings = coordinator.three_way_audit(
            borg_rows, target_report={"ok": False, "error": "timeout"}, recon_states={}
        )
        assert findings == [
            {"kind": "target_unreachable", "ref": "", "copy_says": "", "reality_says": "timeout"}
        ]

    def test_present_only_in_one_copy_is_named_on_both_sides(self):
        borg_rows = [
            {"chain": "p", "ref": "o/r#1", "status": "stacked"},
            {"chain": "p", "ref": "o/r#2", "status": "stacked"},
        ]
        target_report = {"ok": True, "rows": [{"ref": "o/r#1", "status": "stacked"}, {"ref": "o/r#3", "status": "stacked"}]}
        findings = coordinator.three_way_audit(borg_rows, target_report, recon_states={})
        kinds = {(f["kind"], f["ref"]) for f in findings}
        assert ("present_only_in_borg", "o/r#2") in kinds
        assert ("present_only_in_target", "o/r#3") in kinds

    def test_status_disagreement_between_the_two_copies_is_reported(self):
        borg_rows = [{"chain": "p", "ref": "o/r#1", "status": "stacked"}]
        target_report = {"ok": True, "rows": [{"ref": "o/r#1", "status": "review"}]}
        findings = coordinator.three_way_audit(borg_rows, target_report, recon_states={})
        assert any(f["kind"] == "status_disagreement" and f["ref"] == "o/r#1" for f in findings)

    def test_agreement_produces_no_findings(self):
        borg_rows = [{"chain": "p", "ref": "o/r#1", "status": "stacked"}]
        target_report = {"ok": True, "rows": [{"ref": "o/r#1", "status": "stacked"}]}
        assert coordinator.three_way_audit(borg_rows, target_report, recon_states={}) == []

    def test_three_way_audit_never_mutates_anything(self, tmp_path):
        """PM7: 'never silently reconcile'. Running the audit must not touch the filesystem."""
        before = sorted(tmp_path.rglob("*"))
        borg_rows = [{"chain": "p", "ref": "o/r#1", "status": "stacked"}]
        target_report = {"ok": True, "rows": [{"ref": "o/r#1", "status": "review"}]}
        coordinator.three_way_audit(borg_rows, target_report, recon_states={"o/r#1": "OPEN"})
        assert sorted(tmp_path.rglob("*")) == before


class TestLocalAudit:
    def test_runs_with_no_target_and_no_subprocess(self):
        manifests = [_manifest("p", [_row("1", "o/r#1", status="merged")])]
        findings = coordinator.local_audit(manifests, {"o/r#1": "OPEN"})
        assert findings == [
            {
                "kind": "merged_but_open",
                "ref": "o/r#1",
                "copy_says": "borg's copy marks it merged",
                "reality_says": "recon reports OPEN",
            }
        ]


class TestReconStatesFrom:
    def test_first_occurrence_wins(self):
        items = [{"ref": "o/r#1", "state": "OPEN"}, {"ref": "o/r#1", "state": "MERGED"}]
        assert coordinator.recon_states_from(items) == {"o/r#1": "OPEN"}

    def test_items_without_a_ref_or_state_are_skipped(self):
        assert coordinator.recon_states_from([{"ref": "o/r#1"}, {"state": "OPEN"}]) == {}


class TestLoadReconItems:
    def test_accepts_a_bare_items_list(self, tmp_path):
        p = tmp_path / "items.json"
        p.write_text(json.dumps([{"ref": "o/r#1"}]))
        assert coordinator.load_recon_items(str(p)) == [{"ref": "o/r#1"}]

    def test_accepts_a_full_gather_doc(self, tmp_path):
        p = tmp_path / "gather.json"
        p.write_text(json.dumps({"items": [{"ref": "o/r#1"}]}))
        assert coordinator.load_recon_items(str(p)) == [{"ref": "o/r#1"}]

    def test_accepts_a_reconciled_recon_doc(self, tmp_path):
        p = tmp_path / "recon.json"
        p.write_text(json.dumps({"items_by_project": {"proj": [{"ref": "o/r#1"}]}}))
        assert coordinator.load_recon_items(str(p)) == [{"ref": "o/r#1"}]

    def test_none_path_yields_no_items(self):
        assert coordinator.load_recon_items(None) == []


class TestSyncBorg:
    def _discovered(self, project_dir, stem="prog-a"):
        _write_manifest_dir(project_dir.parent, project_dir.name, stem, [_row("1", "o/r#1")])
        manifests, _ = shell.discover([str(project_dir)])
        return manifests

    def test_writes_each_manifest_via_the_native_writer(self, tmp_path):
        manifests = self._discovered(tmp_path / "proj")
        written, warnings = coordinator.sync_borg(manifests)
        assert len(written) == 1
        assert warnings == []
        assert os.path.exists(written[0])

    def test_a_manifest_with_no_path_stamp_is_skipped_not_raised(self):
        manifests = [_manifest("prog-a", [_row("1", "o/r#1")])]
        assert coordinator.sync_borg(manifests) == ([], [])

    def test_a_manifest_whose_filename_differs_from_its_program_rewrites_in_place(self, tmp_path):
        # Opus round 2, finding 1: writing back via a program-derived name spawned a SECOND file
        # (three-repo-program.json declaring program auth-hardening -> a new auth-hardening.json),
        # two copies of one program that then diverge silently. Sync must rewrite the source file.
        import json as _json

        pdir = tmp_path / "proj" / ".borg" / "chains"
        pdir.mkdir(parents=True)
        m = {"program": "auth-hardening", "rows": [_row("1", "o/r#1")]}
        (pdir / "three-repo-program.json").write_text(_json.dumps(m))
        manifests, _ = shell.discover([str(tmp_path / "proj")])
        written, warnings = coordinator.sync_borg(manifests)
        assert written == [str(pdir / "three-repo-program.json")]
        assert sorted(f.name for f in pdir.iterdir()) == ["three-repo-program.json"]
        assert warnings == []

    def test_two_files_declaring_one_program_in_one_project_both_survive_with_a_warning(self, tmp_path):
        # The same-project half of the blocker: b.json and z.json both declaring program "b" must
        # not overwrite each other, and the contention is named.
        import json as _json

        pdir = tmp_path / "proj" / ".borg" / "chains"
        pdir.mkdir(parents=True)
        (pdir / "b.json").write_text(_json.dumps({"program": "b", "rows": [_row("1", "o/r#1")]}))
        (pdir / "z.json").write_text(_json.dumps({"program": "b", "rows": [_row("1", "o/r#2")]}))
        manifests, _ = shell.discover([str(tmp_path / "proj")])
        written, warnings = coordinator.sync_borg(manifests)
        assert len(written) == 2
        assert sorted(f.name for f in pdir.iterdir()) == ["b.json", "z.json"]
        assert _json.loads((pdir / "b.json").read_text())["rows"][0]["ref"] == "o/r#1"
        assert _json.loads((pdir / "z.json").read_text())["rows"][0]["ref"] == "o/r#2"
        assert len(warnings) == 1 and '"b"' in warnings[0].replace("'", '"')

    def test_a_manifest_that_declares_no_program_is_written_and_listed_by_its_stem(self, tmp_path, capsys):
        # THE TEST A NAIVE REPOINT TURNS RED. A file with no `program` key reaches sync_borg carrying an
        # identity derived from its filename (`_id`, from shell.discover). A coordinator that reads the
        # retired `program` key instead sees "" for every such
        # file and `continue`s past it with no warning -- zero files written, exit 0. Written to disk
        # with NO program key, so nothing in the fixture supplies the identity production must derive.
        d = _write_manifest_dir(tmp_path, "proj", "stem-only", [_row("1", "o/r#1")])
        manifests, _ = shell.discover([d])
        written, warnings = coordinator.sync_borg(manifests)
        assert written == [str(tmp_path / "proj" / ".borg" / "chains" / "stem-only.json")]
        assert warnings == []
        assert coordinator.cmd_list(_Args([d])) == 0
        out = capsys.readouterr().out
        assert "stem-only: 1 row(s)" in out and "None" not in out

    def test_the_legacy_programs_directory_is_still_read_and_rewritten_in_place(self, tmp_path):
        # One legacy case kept deliberately: `.borg/programs` is the pre-AC7 spelling and still resolves
        # until the contract phase drops it. Sync must rewrite the file where it LIVES, not migrate it.
        d = _write_manifest_dir(tmp_path, "proj", "old", [_row("1", "o/r#1")], directory="programs")
        manifests, _ = shell.discover([d])
        written, warnings = coordinator.sync_borg(manifests)
        legacy = tmp_path / "proj" / ".borg" / "programs"
        assert written == [str(legacy / "old.json")] and warnings == []
        assert not (tmp_path / "proj" / ".borg" / "chains").exists()

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
        project_dir = _write_manifest_dir(tmp_path, "proj", "prog-a", [_row("1", "o/r#1")])
        path = str(tmp_path / "proj" / ".borg" / "chains" / "prog-a.json")
        manifests, _ = shell.discover([project_dir])
        assert manifests[0]["_path"] == path
        assert coordinator._project_dir_of(manifests[0]) == project_dir


class _Args:
    def __init__(self, chains_dir, recon=None):
        self.chains_dir = chains_dir
        self.recon = recon


class TestCmdList:
    def test_reports_programs_and_row_counts(self, tmp_path, capsys):
        d = _write_manifest_dir(tmp_path, "proj", "a", [_row("1", "o/r#1")])
        assert coordinator.cmd_list(_Args([d])) == 0
        out = capsys.readouterr().out
        assert "a: 1 row(s)" in out and "1 chain(s), 0 skipped" in out

    def test_names_a_skipped_manifest_but_still_succeeds(self, tmp_path, capsys):
        d = tmp_path / "proj" / ".borg" / "chains"
        d.mkdir(parents=True)
        (d / "bad.json").write_text("{not json")
        assert coordinator.cmd_list(_Args([str(tmp_path / "proj")])) == 0
        err = capsys.readouterr().err
        assert "MANIFEST SKIPPED" in err


class TestCmdPlan:
    def test_exits_nonzero_on_malformed_input(self, tmp_path, capsys, monkeypatch):
        monkeypatch.setenv(coordinator.ENV_VAR, str(tmp_path / "no-target"))
        d = tmp_path / "proj" / ".borg" / "chains"
        d.mkdir(parents=True)
        (d / "bad.json").write_text("{not json")
        assert coordinator.cmd_plan(_Args([str(tmp_path / "proj")])) == 1

    def test_reports_findings_without_writing_anything(self, tmp_path, capsys, monkeypatch):
        monkeypatch.setenv(coordinator.ENV_VAR, str(tmp_path / "no-target"))
        d = _write_manifest_dir(tmp_path, "proj", "a", [_row("1", "o/r#1", status="merged")])
        before = sorted((tmp_path / "proj").rglob("*"))
        rc = coordinator.cmd_plan(_Args([d]))
        assert rc == 0
        out, err = capsys.readouterr()
        assert "no publish target found" in err
        assert "plan: 1 chain(s), 1 row(s)" in out
        # PM7: plan is read-only — running it must not add or change any file under the project.
        assert sorted((tmp_path / "proj").rglob("*")) == before

    def test_checks_reality_against_a_recon_doc(self, tmp_path, capsys, monkeypatch):
        monkeypatch.setenv(coordinator.ENV_VAR, str(tmp_path / "no-target"))
        d = _write_manifest_dir(tmp_path, "proj", "a", [_row("1", "o/r#1", status="merged")])
        recon_path = tmp_path / "recon.json"
        recon_path.write_text(json.dumps({"items": [{"ref": "o/r#1", "state": "OPEN"}]}))
        rc = coordinator.cmd_plan(_Args([d], recon=str(recon_path)))
        assert rc == 0
        out = capsys.readouterr().out
        assert "merged_but_open: o/r#1" in out


class TestCmdSync:
    def test_refuses_to_sync_malformed_input(self, tmp_path):
        d = tmp_path / "proj" / ".borg" / "chains"
        d.mkdir(parents=True)
        (d / "bad.json").write_text("{not json")
        assert coordinator.cmd_sync(_Args([str(tmp_path / "proj")])) == 1

    def _bad_row_project(self, tmp_path):
        """A project whose one manifest has three rows, the middle one invalid; returns (project, file, bytes)."""
        bad = _row("2", "o/r#2", gate={"kind": "decision", "blocked_by": "someone"})
        d = _write_manifest_dir(tmp_path, "proj", "a", [_row("1", "o/r#1"), bad, _row("3", "o/r#3")])
        path = tmp_path / "proj" / ".borg" / "chains" / "a.json"
        return d, path, path.read_bytes()

    def test_sync_over_a_manifest_with_one_invalid_row_leaves_every_row_on_disk(self, tmp_path, capsys, monkeypatch):
        """No write may reduce a manifest's row count on disk (refuse-the-manifest-stop-salvaging-rows).

        End to end through `cmd_sync`, the real discovery and the real writer. MUTATION: make `sync_borg`
        write back a salvaged manifest (drop the invalid row from the discovered dict and skip the refusal)
        and the file shrinks from three rows to two, at exit 0 -- this goes red.
        """
        monkeypatch.setenv(coordinator.ENV_VAR, str(tmp_path / "no-target"))
        d, path, before = self._bad_row_project(tmp_path)

        assert coordinator.cmd_sync(_Args([d])) == 1, "a refused file refuses the sync"
        assert path.read_bytes() == before, "byte-identical: nothing was rewritten"
        assert len(json.loads(path.read_text())["rows"]) == 3
        assert "wrote" not in capsys.readouterr().out

    def test_sync_borg_will_not_write_back_a_manifest_with_rows_missing_in_memory(self, tmp_path):
        """The structural guard, independent of what discovery returned or warned.

        A discovered dict with the invalid row already removed (what a salvaging reader would hand
        over) must not overwrite the three-row file. MUTATION: delete the row-count guard in `sync_borg`.
        """
        _, path, before = self._bad_row_project(tmp_path)
        salvaged = {"_id": "a", "_path": str(path), "rows": [_row("1", "o/r#1"), _row("3", "o/r#3")]}

        written, warnings = coordinator.sync_borg([salvaged])

        assert written == []
        assert any("no write may drop a declared row" in w for w in warnings), warnings
        assert path.read_bytes() == before

    def test_writes_borgs_copy_and_reports_no_target(self, tmp_path, capsys, monkeypatch):
        monkeypatch.setenv(coordinator.ENV_VAR, str(tmp_path / "no-target"))
        d = _write_manifest_dir(tmp_path, "proj", "a", [_row("1", "o/r#1")])
        rc = coordinator.cmd_sync(_Args([d]))
        assert rc == 0
        out, err = capsys.readouterr()
        assert "wrote 1 manifest(s)" in out
        assert "no publish target found" in err

    def test_dispatches_to_a_discovered_target(self, tmp_path, capsys, monkeypatch):
        target_dir = _make_target(
            tmp_path,
            "ok",
            '#!/bin/sh\ncat <<\'EOF\'\n{"ok": true, "rows": [{"ref": "o/r#1", "status": "merged"}]}\nEOF\n',
        )
        monkeypatch.setenv(coordinator.ENV_VAR, target_dir)
        d = _write_manifest_dir(tmp_path, "proj", "a", [_row("1", "o/r#1")])
        rc = coordinator.cmd_sync(_Args([d]))
        assert rc == 0
        out = capsys.readouterr().out
        assert "dispatched to borg-sync-target-ok (1 row(s) reported)" in out

    def test_a_failed_target_dispatch_is_reported_and_nonzero(self, tmp_path, capsys, monkeypatch):
        target_dir = _make_target(tmp_path, "bad", "#!/bin/sh\nexit 1\n")
        monkeypatch.setenv(coordinator.ENV_VAR, target_dir)
        d = _write_manifest_dir(tmp_path, "proj", "a", [_row("1", "o/r#1")])
        rc = coordinator.cmd_sync(_Args([d]))
        assert rc == 1
        assert "target dispatch failed" in capsys.readouterr().err


class TestMain:
    def test_list_via_argv(self, tmp_path, capsys, monkeypatch):
        d = _write_manifest_dir(tmp_path, "proj", "a", [_row("1", "o/r#1")])
        monkeypatch.setattr("sys.argv", ["coordinator.py", "list", "--chains-dir", d])
        assert coordinator.main() == 0
        assert "1 chain(s), 0 skipped" in capsys.readouterr().out

    def test_the_legacy_flag_spelling_is_still_accepted(self, tmp_path, capsys, monkeypatch):
        # tests/cli_contract.bats pins `--programs-dir` as a spelling `borg chain` forwards untouched.
        d = _write_manifest_dir(tmp_path, "proj", "a", [_row("1", "o/r#1")])
        monkeypatch.setattr("sys.argv", ["coordinator.py", "list", "--programs-dir", d])
        assert coordinator.main() == 0
        assert "1 chain(s), 0 skipped" in capsys.readouterr().out

    def test_requires_a_subcommand(self, monkeypatch):
        monkeypatch.setattr("sys.argv", ["coordinator.py"])
        with pytest.raises(SystemExit):
            coordinator.main()


class TestIndependenceAndBoundary:
    """PM6/PM8: the coordinator delegates every write and knows nothing about the external schema."""

    FORBIDDEN_CALLS = ("subprocess.run([\"gh\"", "'gh pr", '"gh pr', "gh issue", "gh pr edit", "gh pr create")
    # PM6: "no external-schema field names" — the stacked-PR program's own key shape (SCHEMA.md's
    # "row key" table: `repo` + `number`, distinct from borg's `ref`) and its writer's name.
    FORBIDDEN_FIELDS = ("stamp_tool", "\"number\":", "'number':", "repo_number", "pr_body", "PR_BODY_TEMPLATE")

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
        forbidden = ("addon-plugins", "stack-program", "stamp_tool")
        with open(coordinator.__file__) as fh:
            body = fh.read()
        for token in forbidden:
            if token in body:
                offenders.append(token)
        assert offenders == [], f"external-plugin references found: {offenders}"


    def test_no_string_literal_in_the_coordinator_hardcodes_a_path_into_a_sibling_repo(self):
        """Rehomed from the retired module's TestIndependence, which opened programs.py by name.

        Only STRING LITERALS count -- a docstring may legitimately show an example path. `borg_core`'s
        own scan covers only borg_core, so without this the coordinator, the one merge-tree module left,
        would have no guard at all against a path baked into code.
        """
        offenders = []
        with open(coordinator.__file__) as fh:
            for number, line in enumerate(fh, 1):
                for literal in re.findall(r"""["']([^"']*)["']""", line):
                    # `~/.local/state/borg/...` is borg's OWN state dir and correct. What must never
                    # appear is a path into a sibling checkout under the dev root.
                    if "/dev/" in literal:
                        offenders.append(f"coordinator.py:{number} -> {literal}")
        assert offenders == [], f"hardcoded sibling-repo paths: {offenders}"


class TestTheRetiredWordIsOutOfMergeTree:
    """AC5. The word names nothing in merge-tree/ any more; only the three spellings that are a
    filesystem path, a CLI flag, or the on-disk key an author may have written remain."""

    ALLOWED = ("--programs-dir", ".borg/programs", "`program` key")

    def test_no_non_test_module_uses_it_outside_the_allowlist(self):
        here = os.path.dirname(os.path.abspath(coordinator.__file__))
        sources = sorted(n for n in os.listdir(here) if n.endswith(".py") and not n.startswith("test_"))
        assert "coordinator.py" in sources, sources
        offenders = []
        for name in sources:
            with open(os.path.join(here, name), encoding="utf-8") as fh:
                for number, line in enumerate(fh, 1):
                    for allowed in self.ALLOWED:
                        line = line.replace(allowed, "")
                    if "program" in line.lower():
                        offenders.append(f"{name}:{number}")
        assert offenders == [], f"the retired word is back in merge-tree/: {offenders}"


class TestProjectDirOfUnrecognised:
    """The `""` arm of `_project_dir_of`, which had no coverage (review finding 3 on #222)."""

    def test_a_path_under_neither_directory_name_yields_empty(self):
        # Before the chains rename this split on one hardcoded name, and `rsplit` with NO MATCH
        # returns the WHOLE PATH -- so an unrecognised layout produced a non-empty wrong "root".
        assert coordinator._project_dir_of({"_path": "/tmp/x/.borg/elsewhere/p.json"}) == ""

    def test_both_recognised_names_still_resolve(self):
        assert coordinator._project_dir_of({"_path": "/tmp/x/.borg/chains/p.json"}) == "/tmp/x"
        assert coordinator._project_dir_of({"_path": "/tmp/x/.borg/programs/p.json"}) == "/tmp/x"
        assert coordinator._project_dir_of({"_path": "/tmp/x/.stacks/p.json"}) == "/tmp/x"

    def test_sync_borg_NAMES_a_dropped_manifest_instead_of_losing_it(self, tmp_path):
        """A bare `continue` lost a manifest at exit 0 -- the confident-empty shape again.

        MUTATION: delete the `warnings.append` in `sync_borg`'s guard and this goes red.
        """
        written, warnings = coordinator.sync_borg(
            [{"_id": "p", "_path": str(tmp_path / ".borg" / "elsewhere" / "p.json"), "rows": []}]
        )
        assert written == []
        assert any("not under .borg/chains, .borg/programs or .stacks" in w for w in warnings), warnings
        assert any("p.json" in w for w in warnings), warnings

    def test_a_manifest_with_no_path_at_all_stays_silent(self):
        """The other side of the same guard: nothing came from disk, so nothing was lost."""
        written, warnings = coordinator.sync_borg([{"_id": "p", "rows": []}])
        assert (written, warnings) == ([], [])


_BAD_GATE = {"kind": "decision", "blocked_by": "someone"}


def _refusal_project(tmp_path, kind):
    """A project holding one GOOD manifest and one the reader refuses for `kind`; returns the project."""
    project = _write_manifest_dir(tmp_path, "proj", "good", [_row("1", "o/r#1")])
    chains = tmp_path / "proj" / ".borg" / "chains"
    if kind == "unreadable json":
        (chains / "bad.json").write_text("{not json")
    elif kind == "invalid manifest":
        rows = [_row("1", "o/r#2", gate=_BAD_GATE), _row("2", "o/r#3")]
        (chains / "bad.json").write_text(json.dumps({"rows": rows}))
    elif kind == "declared in both roots":
        _write_stacks(tmp_path, "proj", "dup", [_row("1", "o/r#4")])
        (chains / "dup.json").write_text(json.dumps({"rows": [_row("1", "o/r#5")]}))
    else:
        raise AssertionError(kind)
    return project


class TestRefusalsThroughTheRealReader:
    """Fatality is `shell.refused_manifest_paths`, and every case here builds its warnings by running
    `shell.discover` over real files. The typed-`Refusal` test this replaces monkeypatched a class that
    no longer exists in the reader; building the warning by hand is how it came to pass while the real
    wording drifted. MUTATION: replace `fatal` in cmd_sync or cmd_plan with `[]` and these go red."""

    @pytest.mark.parametrize("kind", ["unreadable json", "invalid manifest", "declared in both roots"])
    def test_every_refusal_class_is_fatal_for_sync_and_plan_and_writes_nothing(
        self, tmp_path, capsys, monkeypatch, kind
    ):
        monkeypatch.setenv(coordinator.ENV_VAR, str(tmp_path / "no-target"))
        project = _refusal_project(tmp_path, kind)
        _, warnings = shell.discover([project])
        assert shell.refused_manifest_paths(warnings), f"the fixture produced no refusal: {warnings}"
        before = _tree_bytes(tmp_path)

        assert coordinator.cmd_sync(_Args([project])) == 1
        assert coordinator.cmd_plan(_Args([project])) == 1

        assert _tree_bytes(tmp_path) == before, "a refused sweep must not rewrite even the good manifest"
        assert "wrote" not in capsys.readouterr().out

    def test_a_registered_path_that_is_absent_is_a_note_and_not_a_refusal(self, tmp_path, capsys, monkeypatch):
        monkeypatch.setenv(coordinator.ENV_VAR, str(tmp_path / "no-target"))
        project = _write_manifest_dir(tmp_path, "proj", "good", [_row("1", "o/r#1")])
        gone = str(tmp_path / "gone")

        assert coordinator.cmd_sync(_Args([gone, project])) == 0
        assert coordinator.cmd_plan(_Args([gone, project])) == 0

        out, err = capsys.readouterr()
        assert "wrote 1 manifest(s)" in out
        assert "does not exist" in err

    def test_a_stray_json_file_is_skipped_with_a_named_note_and_neither_plan_nor_sync_fails(
        self, tmp_path, capsys, monkeypatch
    ):
        # DECISION 1 (Noah, 2026-10-12): borg_core's rule, not a coordinator-only classifier. A file with
        # no rows list declares no rows, so skipping it cannot lose data; the row-count guard and the
        # whole-file refusal still protect every real manifest.
        monkeypatch.setenv(coordinator.ENV_VAR, str(tmp_path / "no-target"))
        project = _write_manifest_dir(tmp_path, "proj", "good", [_row("1", "o/r#1")])
        stray = tmp_path / "proj" / ".borg" / "chains" / "settings.json"
        stray.write_text('{"theme": "dark"}')

        assert coordinator.cmd_plan(_Args([project])) == 0
        plan_out, plan_err = capsys.readouterr()
        assert "settings.json" in plan_err and "not a manifest (no rows list)" in plan_err
        assert "plan: 1 chain(s)" in plan_out and "CAVEAT" not in plan_out

        assert coordinator.cmd_sync(_Args([project])) == 0
        assert "wrote 1 manifest(s)" in capsys.readouterr().out
        assert stray.read_text() == '{"theme": "dark"}'

    def test_a_shorthand_ref_manifest_is_refused_by_list_and_plan(self, tmp_path, capsys, monkeypatch):
        # The validator swap is the intended AC7 outcome: `borg link` already refuses this shape.
        monkeypatch.setenv(coordinator.ENV_VAR, str(tmp_path / "no-target"))
        project = _write_manifest_dir(tmp_path, "proj", "short", [_row("1", "r#22")])

        assert coordinator.cmd_list(_Args([project])) == 0
        out, err = capsys.readouterr()
        assert "MANIFEST SKIPPED" in err and "0 chain(s), 1 skipped" in out

        assert coordinator.cmd_plan(_Args([project])) == 1


class TestStacksRoot:
    """DECISION 3 (Noah, 2026-10-12): list, plan and sync cover both roots, and sync rewrites a `.stacks/`
    manifest in place."""

    def test_list_and_plan_cover_the_stacks_root(self, tmp_path, capsys, monkeypatch):
        monkeypatch.setenv(coordinator.ENV_VAR, str(tmp_path / "no-target"))
        project = _write_stacks(tmp_path, "proj", "tool-neutral", [_row("1", "o/r#1"), _row("2", "o/r#2")])

        assert coordinator.cmd_list(_Args([project])) == 0
        assert "tool-neutral: 2 row(s)" in capsys.readouterr().out
        assert coordinator.cmd_plan(_Args([project])) == 0
        assert "plan: 1 chain(s), 2 row(s)" in capsys.readouterr().out

    def test_sync_rewrites_a_stacks_manifest_in_place_and_creates_no_second_file(self, tmp_path, capsys, monkeypatch):
        # A second copy under `.borg/chains/` would be declared in BOTH roots, which the next read
        # refuses by name and which makes the following sync exit 1.
        monkeypatch.setenv(coordinator.ENV_VAR, str(tmp_path / "no-target"))
        project = _write_stacks(tmp_path, "proj", "tool-neutral", [_row("1", "o/r#1")])
        target = tmp_path / "proj" / ".stacks" / "tool-neutral.json"
        compact = target.read_text()

        assert coordinator.cmd_sync(_Args([project])) == 0

        assert target.read_text() != compact and target.read_text().startswith("{\n  ")
        assert not (tmp_path / "proj" / ".borg").exists(), "a second copy was created beside the first"
        _, warnings = shell.discover([project])
        assert warnings == []
        assert coordinator.cmd_sync(_Args([project])) == 0, "the rewritten tree must sync again"


class TestWhatTheWriterPersists:
    def _synced(self, tmp_path, monkeypatch, directory="chains", **declared):
        monkeypatch.setenv(coordinator.ENV_VAR, str(tmp_path / "no-target"))
        project = _write_manifest_dir(tmp_path, "proj", "plain", [_row("1", "o/r#1")], directory, **declared)
        assert coordinator.cmd_sync(_Args([project])) == 0
        return tmp_path / "proj" / ".borg" / directory / "plain.json"

    def test_written_bytes_gain_no_derived_or_retired_key(self, tmp_path, monkeypatch):
        written = json.loads(self._synced(tmp_path, monkeypatch).read_text())
        assert set(written) == {"rows"}, f"the writer added keys the author never wrote: {set(written)}"

    def test_a_key_the_author_wrote_survives_the_rewrite(self, tmp_path, monkeypatch):
        written = json.loads(self._synced(tmp_path, monkeypatch, program="mine", desc="kept").read_text())
        assert (written["program"], written["desc"]) == ("mine", "kept")

    def test_a_manifest_holding_en_dashes_round_trips_byte_identical(self, tmp_path, monkeypatch):
        # Today's sync dirties viz-program.json with `\\u2013` escapes; ensure_ascii=False is the fix.
        monkeypatch.setenv(coordinator.ENV_VAR, str(tmp_path / "no-target"))
        original = (pathlib.Path(REPO_ROOT) / ".borg" / "chains" / "viz-program.json").read_bytes()
        assert "\u2013".encode() in original
        chains = tmp_path / "proj" / ".borg" / "chains"
        chains.mkdir(parents=True)
        (chains / "viz-program.json").write_bytes(original)

        assert coordinator.cmd_sync(_Args([str(tmp_path / "proj")])) == 0

        assert (chains / "viz-program.json").read_bytes() == original

    def test_the_sync_target_payload_is_the_declared_body_only(self, tmp_path, monkeypatch):
        # DECISION 2 (Noah, 2026-10-12): `program` is dropped from the wire. A key appears only when the
        # author wrote it, and no `_`-prefixed key ever does.
        capture = tmp_path / "stdin.json"
        target_dir = _make_target(
            tmp_path, "capture", "#!/bin/sh\ncat > '" + str(capture) + "'\necho '{\"ok\": true, \"rows\": []}'\n"
        )
        monkeypatch.setenv(coordinator.ENV_VAR, target_dir)
        plain = _write_manifest_dir(tmp_path, "one", "plain", [_row("1", "o/r#1")])
        declared = _write_manifest_dir(tmp_path, "two", "other", [_row("1", "o/r#2")], program="declared-id")

        assert coordinator.cmd_sync(_Args([plain, declared])) == 0

        sent = json.loads(capture.read_text())["manifests"]
        assert sorted(sorted(m) for m in sent) == [["program", "rows"], ["rows"]]
        assert not [key for m in sent for key in m if key in ("_id", "_path")]

    def test_run_target_strips_the_loader_stamps_and_keeps_an_authored_underscore_key(self, tmp_path):
        capture = tmp_path / "stdin.json"
        target_dir = _make_target(
            tmp_path, "capture", "#!/bin/sh\ncat > '" + str(capture) + "'\necho '{\"ok\": true}'\n"
        )
        target = os.path.join(target_dir, "borg-sync-target-capture")
        coordinator.run_target(target, "plan", [{"_id": "x", "_path": "/p", "_comment": 1, "rows": []}])
        assert json.loads(capture.read_text()) == {"manifests": [{"_comment": 1, "rows": []}]}


class TestOneChainRegisteredTwice:
    def test_body_identical_manifests_in_two_registered_paths_collapse_to_one_chain(
        self, tmp_path, capsys, monkeypatch
    ):
        # DECISION 4 (Noah, 2026-10-12): borg_core's rule, accepted. A git worktree is a second checkout of
        # every tracked manifest, and listing or rewriting it twice is wrong whatever it is called. The
        # second copy is neither listed nor rewritten, with no warning -- the grid dedups the same way.
        monkeypatch.setenv(coordinator.ENV_VAR, str(tmp_path / "no-target"))
        first = _write_manifest_dir(tmp_path, "first", "shared", [_row("1", "o/r#1")])
        second = _write_manifest_dir(tmp_path, "second", "shared", [_row("1", "o/r#1")])
        second_file = tmp_path / "second" / ".borg" / "chains" / "shared.json"
        second_before = second_file.read_bytes()

        assert coordinator.cmd_list(_Args([first, second])) == 0
        assert "1 chain(s), 0 skipped" in capsys.readouterr().out

        assert coordinator.cmd_sync(_Args([first, second])) == 0
        assert "wrote 1 manifest(s)" in capsys.readouterr().out
        assert second_file.read_bytes() == second_before


class TestSyncKeepsWhatTheAuthorWrote:
    """PR #341 fix round 1: two regressions inherited from the shared writer, now reached by `borg chain sync`."""

    def _project(self, tmp_path, **declared):
        return _write_manifest_dir(tmp_path, "proj", "plain", [_row("1", "o/r#1")], **declared)

    def test_sync_preserves_an_authored_underscore_key_and_persists_no_stamp(self, tmp_path, monkeypatch):
        monkeypatch.setenv(coordinator.ENV_VAR, str(tmp_path / "no-target"))
        project = self._project(tmp_path, _comment="hand-written", _note=["a", "b"])
        assert coordinator.cmd_sync(_Args([project])) == 0
        written = json.loads((tmp_path / "proj" / ".borg" / "chains" / "plain.json").read_text())
        assert written == {"rows": [_row("1", "o/r#1")], "_comment": "hand-written", "_note": ["a", "b"]}
        assert "_id" not in written and "_path" not in written

    def test_sync_keeps_a_0644_manifest_0644(self, tmp_path, monkeypatch):
        monkeypatch.setenv(coordinator.ENV_VAR, str(tmp_path / "no-target"))
        project = self._project(tmp_path)
        target = tmp_path / "proj" / ".borg" / "chains" / "plain.json"
        os.chmod(target, 0o644)
        assert coordinator.cmd_sync(_Args([project])) == 0
        assert stat.S_IMODE(os.stat(target).st_mode) == 0o644
