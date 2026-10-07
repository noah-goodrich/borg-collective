"""Shell tests: the ledger reader, tree discovery, and git ranges against a real temp repository."""

from __future__ import annotations

import subprocess
from pathlib import Path

import pytest

from borg_core.evals import shell


def git(root: Path, *args: str) -> None:
    subprocess.run(["git", "-C", str(root), *args], check=True, capture_output=True)


@pytest.fixture
def repo(tmp_path: Path) -> Path:
    git(tmp_path, "init", "-q", "-b", "main")
    (tmp_path / "a.txt").write_text("a")
    git(tmp_path, "add", ".")
    git(tmp_path, "commit", "-qm", "base")
    git(tmp_path, "update-ref", "refs/remotes/origin/main", "HEAD")
    return tmp_path


def test_load_ledger_errors_name_the_file(tmp_path: Path) -> None:
    with pytest.raises(ValueError, match="evals/ledger.json"):
        shell.load_ledger(tmp_path)
    (tmp_path / "evals").mkdir()
    (tmp_path / "evals" / "ledger.json").write_text("[]")
    with pytest.raises(ValueError, match="top level"):
        shell.load_ledger(tmp_path)
    (tmp_path / "evals" / "ledger.json").write_text('{"version": 1}')
    assert shell.load_ledger(tmp_path) == {"version": 1}


def test_discover_items_and_existing_evals(tmp_path: Path) -> None:
    (tmp_path / "skills" / "s").mkdir(parents=True)
    (tmp_path / "skills" / "s" / "SKILL.md").write_text("")
    (tmp_path / "skills" / "empty").mkdir()
    (tmp_path / "agents").mkdir()
    (tmp_path / "agents" / "ROUTING.md").write_text("")
    (tmp_path / "evals" / "e").mkdir(parents=True)
    (tmp_path / "evals" / "e" / "run.sh").write_text("")
    (tmp_path / "evals" / "norun").mkdir()
    assert shell.discover_items(tmp_path) == ["agents/ROUTING", "skills/s"]
    assert shell.existing_evals(tmp_path, ["evals/e", "evals/norun", "evals/gone"]) == {"evals/e"}


def test_changed_files_default_base_is_merge_base_with_origin_main(repo: Path) -> None:
    git(repo, "checkout", "-qb", "feature")
    (repo / "b.txt").write_text("b")
    git(repo, "add", ".")
    git(repo, "commit", "-qm", "feature")
    assert shell.changed_files(repo, None, "HEAD") == ["b.txt"]
    assert shell.changed_files(repo, "HEAD", "HEAD") == []
    assert shell.changed_files(repo, "main", "feature") == ["b.txt"]


def test_changed_files_git_failure_is_a_valueerror(repo: Path) -> None:
    with pytest.raises(ValueError, match="git"):
        shell.changed_files(repo, "no-such-ref", "HEAD")
