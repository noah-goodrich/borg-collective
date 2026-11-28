"""The CLI end to end over the fixture projects dir."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from borg_core.spend import cli, shell

PROJECTS = str(Path(__file__).parent / "fixtures" / "projects")


def _run(capsys, *argv):
    code = cli.main(["--projects-dir", PROJECTS, *argv])
    captured = capsys.readouterr()
    return code, captured.out, captured.err


def test_human_page(capsys):
    code, out, _ = _run(capsys, "--session", "11111111")
    assert code == 0
    assert "total          $2.51  (17 requests)" in out
    assert "PRs opened     2" in out and "window         2026-11-27T10:00:00Z .. 2026-11-27T13:21:00Z" in out


def test_json_has_window_strings_and_session(capsys):
    code, out, _ = _run(capsys, "--session", "11111111", "--json", "--until", "2026-11-27T10:03:00Z")
    doc = json.loads(out)
    assert code == 0 and doc["requests"]["total"] == 4 and doc["cross_check"] is None
    assert doc["window"] == {"start": "2026-11-27T10:00:00Z", "end": "2026-11-27T10:03:00Z"}
    assert doc["session"].startswith("11111111-aaaa")


def test_cross_check_uses_window_and_prints_difference(capsys, monkeypatch):
    seen = {}

    def fake(prs, start, end):
        seen.update(prs=prs, start=start, end=end)
        return [
            "https://github.com/example-org/example-repo/pull/101",
            "https://github.com/example-org/example-repo/pull/7",
        ]

    monkeypatch.setattr(shell, "listed_prs", fake)
    code, out, _ = _run(capsys, "--session", "11111111", "--cross-check")
    assert code == 0 and seen["start"] == "2026-11-27T10:00:00Z" and seen["end"] == "2026-11-27T13:21:00Z"
    assert "only in transcripts: https://github.com/example-org/example-repo/pull/102" in out
    assert "only in gh pr list:  https://github.com/example-org/example-repo/pull/7" in out
    code, out, _ = _run(capsys, "--session", "11111111", "--cross-check", "--json")
    assert json.loads(out)["cross_check"]["only_gh"] == ["https://github.com/example-org/example-repo/pull/7"]


@pytest.mark.parametrize(
    "argv,message",
    [
        (["--session", "nope"], "no session matches 'nope'"),
        (["--session", "11111111", "--since", "yesterday"], "--since is not an ISO-8601 time"),
    ],
)
def test_errors_are_named_and_exit_2(capsys, argv, message):
    code, _, err = _run(capsys, *argv)
    assert code == 2 and message in err


def test_usage_error_exits_2_and_help_exits_0(capsys):
    assert cli.main([]) == 2
    assert cli.main(["--help"]) == 0
    capsys.readouterr()


def test_default_projects_dir_from_env(capsys, monkeypatch, tmp_path):
    monkeypatch.setenv("CLAUDE_CONFIG_DIR", str(tmp_path))
    assert cli.main(["--session", "11111111"]) == 2
    assert "no session matches" in capsys.readouterr().err
