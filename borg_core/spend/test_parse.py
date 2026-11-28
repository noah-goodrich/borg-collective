"""The classifier ports, PR detection and entry reduction."""

from __future__ import annotations

import pytest

from borg_core.spend import parse


@pytest.mark.parametrize(
    "command,kind",
    [
        ("gh pr checks 5 --watch", "Bash:wait-ci"),
        ("until gh run view; do sleep 5; done", "Bash:wait-ci"),
        ("make test", "Bash:test"),
        ("cd /Users/x/.local/state/borg/worktrees/r/b; pytest -q", "Bash:test"),
        ("gh pr view 5", "Bash:gh"),
        ("git -C /x commit -q -m y", "Bash:git"),
        ("grep -n foo bar.txt", "Bash:read"),
        ("echo hi", "Bash:other"),
    ],
)
def test_bash_kind(command, kind):
    assert parse.bash_kind(command) == kind


@pytest.mark.parametrize(
    "command,expected",
    [
        ("gh pr create --title x", True),
        ("gh api -X POST repos/o/r/pulls -f title=x", True),
        ("gh api repos/o/r/pulls -f title=x", True),
        ("gh api repos/o/r/pulls/5/merge -X PUT", False),
        ("gh api repos/o/r/pulls?state=open", False),
        ("git push", False),
    ],
)
def test_makes_pr(command, expected):
    assert parse.makes_pr(command) is expected


def test_parse_ts_variants():
    assert parse.parse_ts("2026-11-27T10:00:00Z") == parse.parse_ts("2026-11-27T10:00:00")
    assert parse.parse_ts("2026-11-27T12:00:00+02:00") == parse.parse_ts("2026-11-27T10:00:00Z")


def test_parse_transcript_reads_only_what_it_needs():
    entries = [
        {
            "type": "assistant",
            "timestamp": "2026-11-27T10:00:00Z",
            "uuid": "u1",
            "message": {"model": "m", "usage": {}},
        },
        {
            "type": "assistant",
            "timestamp": "2026-11-27T10:00:01Z",
            "message": {"id": "a", "model": "<synthetic>", "usage": {}},
        },
        {"type": "assistant", "timestamp": "2026-11-27T10:00:02Z", "message": {"id": "b", "model": "m"}},
        {"type": "user", "timestamp": "2026-11-27T10:01:00Z", "isCompactSummary": True, "message": {"content": "x"}},
        {
            "type": "user",
            "timestamp": "2026-11-27T10:02:00Z",
            "message": {"content": [{"type": "tool_result", "tool_use_id": "t", "content": 5}]},
        },
        {"type": "user", "message": {"content": [{"type": "tool_result", "tool_use_id": "t2", "content": "x"}]}},
        {"type": "pr-link", "timestamp": "2026-11-27T10:03:00Z", "prUrl": "not a url"},
        {"type": "attachment"},
    ]
    tr = parse.parse_transcript(entries, "k")
    assert [a.msg_id for a in tr.assists] == ["u1"]
    assert len(tr.boundaries) == 1 and tr.results["t"][1] == "" and "t2" not in tr.results
    assert tr.pr_links == []
