"""CLI tests: exit codes and streams for `check` and `select`, in-process against a temp tree."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import pytest

from borg_core.evals import cli

LEDGER: dict[str, Any] = {
    "version": 1,
    "evals": {"evals/a": {"covers": ["evals/a/**", "skills/x/**"]}},
    "items": {"skills/x": {"eval": "evals/a"}, "agents/y": {"waiver": "later", "review_by": "2026-12-01"}},
}


@pytest.fixture
def tree(tmp_path: Path) -> Path:
    (tmp_path / "evals" / "a").mkdir(parents=True)
    (tmp_path / "evals" / "a" / "run.sh").write_text("")
    (tmp_path / "evals" / "ledger.json").write_text(json.dumps(LEDGER))
    (tmp_path / "skills" / "x").mkdir(parents=True)
    (tmp_path / "skills" / "x" / "SKILL.md").write_text("")
    (tmp_path / "agents").mkdir()
    (tmp_path / "agents" / "y.md").write_text("")
    return tmp_path


def run(capsys, *argv: str) -> tuple[int, str, str]:
    with pytest.raises(SystemExit) as exc:
        cli.main(list(argv))
    out = capsys.readouterr()
    return int(exc.value.code or 0), out.out, out.err


def test_check_passes_clean_tree(tree: Path, capsys) -> None:
    code, out, _ = run(capsys, "check", "--root", str(tree), "--today", "2026-10-03")
    assert code == 0 and "0 problems" in out


def test_check_defaults_to_real_clock_and_fails_on_expiry(tree: Path, capsys) -> None:
    old = {**LEDGER, "items": {**LEDGER["items"], "agents/y": {"waiver": "x", "review_by": "2020-01-01"}}}
    (tree / "evals" / "ledger.json").write_text(json.dumps(old))
    code, _, err = run(capsys, "check", "--root", str(tree))
    assert code == 1 and "expired" in err and "agents/y" in err


def test_check_unreadable_ledger_is_exit_2(tmp_path: Path, capsys) -> None:
    code, _, err = run(capsys, "check", "--root", str(tmp_path))
    assert code == 2 and "evals/ledger.json" in err


def test_select_files_prints_paths_on_stdout_reason_on_stderr(tree: Path, capsys) -> None:
    code, out, err = run(capsys, "select", "--root", str(tree), "--files", "skills/x/SKILL.md")
    assert code == 0 and out == "evals/a\n" and "1 of 1" in err


def test_select_nothing_is_exit_zero_with_empty_stdout(tree: Path, capsys) -> None:
    code, out, err = run(capsys, "select", "--root", str(tree), "--files", "README.md")
    assert code == 0 and out == "" and "nothing to run" in err


def test_select_ledger_change_selects_all(tree: Path, capsys) -> None:
    code, out, err = run(capsys, "select", "--root", str(tree), "--files", "evals/ledger.json")
    assert code == 0 and out == "evals/a\n" and "selecting all" in err


def test_select_git_failure_is_exit_2(tree: Path, capsys) -> None:
    code, _, err = run(capsys, "select", "--root", str(tree), "--base", "nope")
    assert code == 2 and "git" in err
