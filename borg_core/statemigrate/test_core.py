"""Pure planner: move / merge-append / keep-new / skip / idempotent / STAYS never planned."""

from __future__ import annotations

import ast
from pathlib import Path

import pytest

from borg_core.statemigrate import core
from borg_core.statemigrate.core import Entry


def _op(rel: str, old: bool, new: bool) -> str:
    return core.plan([Entry(rel, old, new)])[0].op


def test_old_only_moves():
    assert _op("cortex-wakes.json", True, False) == core.MOVE


def test_absent_at_old_skips():
    assert _op("cortex-wakes.json", False, True) == core.SKIP
    assert _op("cortex-wakes.json", False, False) == core.SKIP


def test_both_present_append_only_logs_append():
    for rel in ("agents.jsonl", "prefer-tool.jsonl", "memory-hits.log", "pr-watch.log"):
        assert _op(rel, True, True) == core.APPEND


def test_both_present_json_state_keeps_new():
    assert _op("usage-guardian.json", True, True) == core.KEEP_NEW
    assert _op("recon/last-run", True, True) == core.KEEP_NEW
    assert _op("briefing-x-stderr.log", True, True) == core.KEEP_NEW


def test_briefing_stderr_log_is_moved():
    assert _op("briefing-stderr.log", True, False) == core.MOVE


def test_stays_files_are_never_planned():
    stays = [
        "registry.json",
        ".registry.lock",
        "config.zsh",
        "extensions/a.md",
        "launchd-prefix",
        "desktop/x.json",
        "claude-settings.local.json",
        ".cairn-last-write",
        "cairn-hits.log",
    ]
    assert core.plan([Entry(r, True, False) for r in stays]) == []


def test_families_are_moved_but_only_in_their_place():
    assert core.is_moved("devcontainer-hashes/proj.hash")
    assert core.is_moved("briefing-link-stderr.log")
    assert core.is_moved("briefing-stderr.log")
    assert not core.is_moved("devcontainer-hashes/proj.txt")
    assert not core.is_moved("extensions/briefing-x-stderr.log")


def test_after_a_run_the_plan_is_all_skip():
    assert {a.op for a in core.plan([Entry(r, False, True) for r in core.MOVED_FILES])} == {core.SKIP}


def test_expected_result_append_puts_old_history_first():
    assert core.expected_result(core.APPEND, b"old\n", b"new\n") == b"old\nnew\n"
    assert core.expected_result(core.APPEND, b"old", b"new\n") == b"old\nnew\n"


def test_expected_result_other_ops():
    assert core.expected_result(core.MOVE, b"o", b"") == b"o"
    assert core.expected_result(core.KEEP_NEW, b"o", b"n") == b"n"
    assert core.expected_result(core.SKIP, b"o", b"n") is None


def test_verify_accepts_plan_and_rejects_drift_and_bad_json():
    assert core.verify("agents.jsonl", core.APPEND, b"a\n", b"b\n", b"a\nb\n") is None
    assert core.verify("agents.jsonl", core.APPEND, b"a\n", b"b\n", b"b\n") is not None
    assert core.verify("x.json", core.MOVE, b"{", b"", b"{") is not None
    assert core.verify("x.json", core.MOVE, b"{}", b"", b"{}") is None


@pytest.mark.parametrize("name", ["core.py"])
def test_core_imports_stay_pure(name):
    tree = ast.parse((Path(__file__).parent / name).read_text())
    roots = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            roots.update(a.name.split(".")[0] for a in node.names)
        elif isinstance(node, ast.ImportFrom):
            roots.add((node.module or "").split(".")[0])
    assert roots <= {"__future__", "json", "typing"}
