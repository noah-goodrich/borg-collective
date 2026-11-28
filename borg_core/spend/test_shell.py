"""Discovery refusals, file reading and the gh list."""

from __future__ import annotations

import json
import shutil
from pathlib import Path

import pytest

from borg_core.spend import shell

FIXTURES = Path(__file__).parent / "fixtures" / "projects"
SID = "11111111-aaaa-bbbb-cccc-000000000001"


def test_find_session_by_prefix_and_agents():
    main, agents = shell.find_session(FIXTURES, "11111111-aaaa")
    assert main.name == f"{SID}.jsonl"
    assert [a.name for a in agents] == ["agent-a1.jsonl", "agent-b2.jsonl"]


def test_find_session_refuses_missing_empty_and_ambiguous(tmp_path):
    with pytest.raises(shell.SpendError, match="no session matches 'zzz'"):
        shell.find_session(FIXTURES, "zzz")
    with pytest.raises(shell.SpendError, match="needs a session id"):
        shell.find_session(FIXTURES, "")
    shutil.copytree(FIXTURES, tmp_path / "p")
    other = tmp_path / "p" / "-other-repo"
    other.mkdir()
    (other / "11111111-ffff-0000-0000-000000000002.jsonl").write_text("{}\n")
    with pytest.raises(shell.SpendError, match="ambiguous.*11111111-aaaa.*11111111-ffff"):
        shell.find_session(tmp_path / "p", "11111111")
    assert shell.find_session(tmp_path / "p", "11111111-f")[1] == []


def test_default_projects_dir(monkeypatch, tmp_path):
    monkeypatch.setenv("CLAUDE_CONFIG_DIR", str(tmp_path))
    assert shell.default_projects_dir() == tmp_path / "projects"
    monkeypatch.delenv("CLAUDE_CONFIG_DIR")
    monkeypatch.setenv("HOME", str(tmp_path))
    assert shell.default_projects_dir() == tmp_path / ".claude" / "projects"


def test_load_session_skips_bad_lines_and_missing_meta(tmp_path):
    main = tmp_path / "s.jsonl"
    main.write_text('not json\n{"type":"system","subtype":"compact_boundary","timestamp":"2026-11-27T10:00:00Z"}\n')
    agent = tmp_path / "agent-x.jsonl"
    agent.write_text("{}\n")
    (tmp_path / "agent-x.meta.json").write_text("{broken")
    main_tr, agent_tr = shell.load_session(main, [agent])
    assert len(main_tr.boundaries) == 1 and not main_tr.agent
    assert agent_tr.agent and agent_tr.agent_type == "unknown"


def test_listed_prs_asks_gh_per_repository(monkeypatch):
    calls = []

    def fake(argv):
        calls.append(argv)
        return 0, json.dumps([{"url": "https://github.com/o/r/pull/9"}, {"url": "junk"}]), ""

    monkeypatch.setattr(shell.gh, "run", fake)
    urls = shell.listed_prs(["https://github.com/o/r/pull/1", "https://github.com/o/r/pull/2"], "A", "B")
    assert urls == ["https://github.com/o/r/pull/9"]
    assert len(calls) == 1 and "created:A..B" in calls[0] and "o/r" in calls[0]


def test_listed_prs_gh_failure_is_named(monkeypatch):
    monkeypatch.setattr(shell.gh, "run", lambda argv: (1, "", "boom"))
    with pytest.raises(shell.SpendError, match="gh pr list failed for o/r: boom"):
        shell.listed_prs(["https://github.com/o/r/pull/1"], "A", "B")
