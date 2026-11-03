"""Tier 1 lint over the handoff fixtures: one thread passes, two PR refs and a missing stop condition fail."""

from __future__ import annotations

from pathlib import Path

import pytest

from borg_core.handoff import core
from borg_core.recon.core import checkpoint_owned_items

FIXTURES = Path(__file__).parent / "fixtures"


def _fixture(name: str) -> str:
    return (FIXTURES / name).read_text(encoding="utf-8")


def test_one_pr_thread_passes():
    verdict = core.check(_fixture("good-one-thread.md"))
    assert verdict.ok, verdict.problems
    assert verdict.refs == ("noah-goodrich/borg-collective#567",)


def test_two_pr_refs_in_the_goal_fail_with_a_split_suggestion():
    verdict = core.check(_fixture("bad-two-refs.md"))
    assert not verdict.ok
    assert len(verdict.problems) == 1
    assert verdict.problems[0].startswith("split: this goal names 2 PR threads")
    assert "noah-goodrich/borg-collective#567" in verdict.problems[0]
    assert "noah-goodrich/ingle#58" in verdict.problems[0]
    assert "write 2 handoffs, one per ref" in verdict.problems[0]


def test_missing_stop_condition_fails():
    verdict = core.check(_fixture("bad-no-stop.md"))
    assert not verdict.ok
    assert any("Stop condition:" in problem for problem in verdict.problems)


def test_missing_next_thread_fails():
    verdict = core.check(_fixture("bad-no-next.md"))
    assert not verdict.ok
    assert any("Next thread" in problem for problem in verdict.problems)


def test_a_stop_condition_without_done_when_or_link_up_fails():
    text = _fixture("good-one-thread.md")
    for weak in ("Stop condition: when it feels finished.", "Stop condition: Done when merged."):
        broken = text.replace(
            "Stop condition: Done when CI is green and the PR is merged, then /borg-link-up and end.", weak
        )
        assert not core.check(broken).ok, weak


def test_the_next_thread_may_name_a_pr_without_tripping_the_one_ref_rule():
    # The fixture's next thread is #580 and the goal is #567: only the goal is counted.
    assert "noah-goodrich/borg-collective#580" in _fixture("good-one-thread.md")
    assert core.check(_fixture("good-one-thread.md")).ok


def test_the_same_pr_spelled_three_ways_counts_once_and_an_issue_url_not_at_all():
    verdict = core.check(_fixture("good-pr-url.md"))
    assert verdict.ok, verdict.problems
    assert verdict.refs == ("noah-goodrich/borg-collective#567",)


def test_a_goal_with_no_pr_ref_fails():
    text = _fixture("good-one-thread.md").replace("noah-goodrich/borg-collective#567: land", "land", 1)
    text = text.replace("## 1. Goal\n\nnoah-goodrich/borg-collective#567: land", "## 1. Goal\n\nland")
    assert not core.check(text.replace("#567", "")).ok


@pytest.mark.parametrize(
    ("text", "expected"),
    [
        ("see owner/repo#12", ["owner/repo#12"]),
        ("see #12 and #13", ["#12", "#13"]),
        ("https://github.com/o/r/pull/7", ["o/r#7"]),
        ("https://github.com/o/r/issues/7", []),
        ("o/r#7, https://github.com/o/r/pull/7 and #7", ["o/r#7"]),
        ("o/r#7 and p/q#7", ["o/r#7", "p/q#7"]),
        ("no refs, version 1.2#3x or C#", []),
    ],
)
def test_pr_refs(text, expected):
    assert core.pr_refs(text) == expected


def test_a_missing_goal_section_fails_on_the_goal_not_on_a_crash():
    verdict = core.check("tl;dr\n\n## 2. Accomplished\n\nnothing\n")
    assert not verdict.ok
    assert verdict.problems[0] == "no `## 1. Goal` section"


def test_render_output_passes_its_own_lint_and_is_reader_shaped():
    text = core.render("o/r#5: ship it", "merged", "o/r#6", ("Rotate the key",))
    assert core.check(text).ok
    rows = checkpoint_owned_items(text)
    assert rows == [
        {"text": "Rotate the key", "owner": "YOU"},
        {"text": "o/r#5: ship it Done when merged, then /borg-link-up and end.", "owner": "AGENT"},
    ]


def test_render_with_no_next_thread_writes_none():
    text = core.render("o/r#5: ship it", "merged", "")
    assert text.rstrip().endswith("not this one): none")
    assert core.check(text).ok
