"""Pure planner for the project-state migration: copy / keep-new / skip / refusal / idempotent."""

from __future__ import annotations

import ast
from pathlib import Path

from borg_core.statemigrate import project_core as core
from borg_core.statemigrate.project_core import Entry, Project


def _op(legacy: bool, new: bool, tracked: bool = False) -> str:
    return core.plan([Entry("/p/.borg/state.json", "/s/k/state.json", legacy, new, tracked)])[0].op


def test_legacy_only_copies():
    assert _op(True, False) == core.COPY


def test_both_present_keeps_new():
    assert _op(True, True) == core.KEEP_NEW


def test_legacy_absent_skips_idempotent():
    assert _op(False, True) == core.SKIP
    assert _op(False, False) == core.SKIP


def test_tracked_legacy_is_not_removed():
    assert core.plan([Entry("a", "b", True, False, True)])[0].remove_legacy is False
    assert core.plan([Entry("a", "b", True, False, False)])[0].remove_legacy is True


def test_duplicate_destination_planned_once():
    entries = [Entry("a", "d", True, False), Entry("a", "d", True, False)]
    assert len(core.plan(entries)) == 1


def test_precondition_refuses_git_backed_without_repo():
    projects = [Project("a", None, True), Project("b", "/r/.git", True), Project("c", None, False)]
    assert core.precondition(projects) == ["a"]
    assert core.precondition([Project("x", "", True)]) == ["x"]
    assert core.precondition(projects[1:]) == []


def test_verify_accepts_plan_rejects_drift_and_bad_json():
    assert core.verify(core.COPY, b"{}", b"", b"{}") is None
    assert core.verify(core.COPY, b"{}", b"", b"[]") is not None
    assert core.verify(core.COPY, b"{", b"", b"{") is not None
    assert core.verify(core.KEEP_NEW, b'{"o":1}', b'{"n":1}', b'{"n":1}') is None
    assert core.verify(core.KEEP_NEW, b'{"o":1}', b'{"n":1}', b'{"o":1}') is not None
    assert core.verify(core.SKIP, b"{}", b"{}", b"{}") is not None


def test_core_imports_stay_pure():
    tree = ast.parse((Path(__file__).parent / "project_core.py").read_text())
    roots = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            roots.update(a.name.split(".")[0] for a in node.names)
        elif isinstance(node, ast.ImportFrom):
            roots.add((node.module or "").split(".")[0])
    assert roots <= {"__future__", "json", "typing"}
