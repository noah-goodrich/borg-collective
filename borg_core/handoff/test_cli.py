"""`borg handoff` through its entry point, and a written handoff read back by the real `borg next` reader."""

from __future__ import annotations

from pathlib import Path

import pytest

from borg_core.handoff import cli, shell
from borg_core.nextpick import cli as nextpick_cli

GOAL = "noah-goodrich/borg-collective#567: land the vendor-quote PR"
DONE = "CI is green and the PR is merged"


def _write(repository: Path, *extra: str, goal: str = GOAL, nxt: str = "noah-goodrich/ingle#58") -> int:
    return cli.main(
        ["write", "--repository", str(repository), "--goal", goal, "--done-when", DONE, "--next", nxt, *extra]
    )


def _written(repository: Path) -> list[Path]:
    return sorted((repository / ".borg" / "checkpoints").glob("*.md"))


def test_write_creates_a_queen_named_checkpoint_that_passes_the_lint(tmp_path, capsys):
    assert _write(tmp_path) == 0
    (path,) = _written(tmp_path)
    assert path.name.endswith("-queen.md")
    assert capsys.readouterr().out.strip() == f"wrote {path}"
    assert cli.main(["check", str(path)]) == 0
    assert "ok: one PR thread (noah-goodrich/borg-collective#567)" in capsys.readouterr().out


def test_write_with_two_prs_in_the_goal_prints_the_split_prompt_and_writes_nothing(tmp_path, capsys):
    assert _write(tmp_path, goal="Land noah-goodrich/borg-collective#567 and noah-goodrich/ingle#58") == 1
    out = capsys.readouterr().out
    assert "FAIL: split: this goal names 2 PR threads" in out
    assert "handoff not written" in out
    assert _written(tmp_path) == []


def test_write_with_a_goal_that_names_no_pr_writes_nothing(tmp_path, capsys):
    assert _write(tmp_path, goal="land the week's work") == 1
    assert "names no PR ref" in capsys.readouterr().out
    assert _written(tmp_path) == []


def test_write_requires_the_stop_condition_and_the_next_thread():
    with pytest.raises(SystemExit) as stop:
        cli.main(["write", "--repository", ".", "--goal", GOAL, "--next", "none"])
    assert stop.value.code == 2
    with pytest.raises(SystemExit) as nxt:
        cli.main(["write", "--repository", ".", "--goal", GOAL, "--done-when", DONE])
    assert nxt.value.code == 2


def test_a_second_handoff_in_the_same_second_gets_its_own_name(tmp_path):
    assert _write(tmp_path) == 0
    assert _write(tmp_path) == 0
    assert len(_written(tmp_path)) == 2


def test_check_fails_a_missing_file_and_a_fixture_without_a_stop_condition(tmp_path, capsys):
    assert cli.main(["check", str(tmp_path / "absent.md")]) == 1
    assert "cannot read" in capsys.readouterr().out
    bad = Path(__file__).parent / "fixtures" / "bad-no-stop.md"
    assert cli.main(["check", str(bad)]) == 1
    assert "no `Stop condition:` line" in capsys.readouterr().out


def test_check_reads_stdin(monkeypatch, capsys):
    import io

    text = (Path(__file__).parent / "fixtures" / "good-one-thread.md").read_text(encoding="utf-8")
    monkeypatch.setattr("sys.stdin", io.StringIO(text))
    assert cli.main(["check", "-"]) == 0
    assert "ok:" in capsys.readouterr().out
    assert shell.read("-") == ""


def test_a_written_handoff_still_yields_its_rows_to_borg_next(tmp_path):
    """The readers take the newest checkpoint whole: `Waits on you:` rows are YOU, the numbered Next item is AGENT."""
    assert _write(tmp_path, "--waits-on-you", "Approve the merge in the tracker") == 0
    registry = {"p": {"status": "idle", "last_activity": "2026-10-01", "path": str(tmp_path)}}
    rows, quiet, _degraded, _hidden = nextpick_cli.item_rows(registry, True, show_all=True)
    assert quiet == []
    assert [(r["owner"], r["detail"]) for r in rows] == [
        ("YOU", "Approve the merge in the tracker"),
        ("AGENT", f"{GOAL} Done when {DONE}, then /borg-link-up and end."),
    ]
