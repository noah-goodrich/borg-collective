"""Tier 1: the decision gate's detector and transcript reader, no model and no network."""

import json

import pytest

from borg_core.decisiongate import core, hook

REQUESTS = [
    "## Needs Noah\n- #97, close or restate scope",
    "Needs Noah: #97, close or restate scope",
    "**Needs you**\n- pick one",
    "### Waits on you\n- rotate the token",
    "Done. Waits on you: #97 (close or restate)",
    "**Decision needed**\n1. ship now",
    "Decisions needed:\n- a",
    "Decide: A or B",
    "Your call.",
    "- Your call: merge or hold",
    "## Open questions\n- which name?",
    "Questions for you:\n- which name?",
    "- Should I close #97?\n- Merge #101 now?",
    "1. Close #97?\n2. Merge #101?",
]
PASSES = [
    "Shipped the hook. Decision: wire it through HOOKS_JSON, decided 2026-11-25.",
    "Needs Noah: none",
    "**Waits on you:** nothing",
    "### Open questions\nNone.",
    "## Decisions needed\n\nn/a",
    "I decided to keep it short, and Noah decided earlier.",
    "Decided: use the plain list.",
    "That change needs your attention at some point.",
    "Want me to open the PR?",
    "- Should I close #97?",
    "> Needs Noah: #97\n> - Close it?\n> - Restate it?",
    "```\nWaits on you:\n- Rotate?\n- Approve?\n```",
    "",
]


@pytest.mark.parametrize("text", REQUESTS)
def test_a_decision_request_is_detected(text):
    assert core.asks_for_decision(text)


@pytest.mark.parametrize("text", PASSES)
def test_a_report_that_only_mentions_a_decision_passes(text):
    assert not core.asks_for_decision(text)


def test_reason_names_every_required_part():
    reason = core.reason()
    for needle in ("AskUserQuestion", "pros", "cons", "what choosing it runs", "Recommended", "source link", "nothing"):
        assert needle in reason or needle.lower() in reason.lower()


def _lines(*entries):
    return [json.dumps(entry) for entry in entries]


def test_read_turn_scopes_the_ask_to_the_current_turn():
    ask = {
        "type": "assistant",
        "message": {"role": "assistant", "content": [{"type": "tool_use", "name": "AskUserQuestion"}]},
    }
    first = {"type": "user", "message": {"role": "user", "content": "one"}}
    second = {"type": "user", "message": {"role": "user", "content": [{"type": "text", "text": "two"}]}}
    final = {
        "type": "assistant",
        "message": {"role": "assistant", "content": [{"type": "text", "text": "Needs Noah: x"}]},
    }
    assert hook.read_turn(_lines(first, ask, second, final)) == ("Needs Noah: x", False)
    assert hook.read_turn(_lines(first, second, ask, final)) == ("Needs Noah: x", True)


def test_read_turn_skips_garbage_meta_and_non_dict_lines():
    meta = {"type": "user", "isMeta": True, "message": {"role": "user", "content": "caveat"}}
    final = {"type": "assistant", "message": {"role": "assistant", "content": "plain string"}}
    assert hook.read_turn(["not json", "[1]", *_lines(meta, final)]) == ("plain string", False)


def test_verdict_passes_when_stop_hook_is_active(tmp_path):
    path = tmp_path / "t.jsonl"
    path.write_text("\n".join(_lines({"type": "assistant", "message": {"content": "Needs Noah: x"}})))
    assert hook.verdict({"transcript_path": str(path), "stop_hook_active": True}) is None
    blocked = hook.verdict({"transcript_path": str(path)})
    assert blocked and blocked["decision"] == "block"


def test_verdict_fails_open_on_a_missing_transcript_and_prefers_the_given_message():
    assert hook.verdict({"transcript_path": "/nonexistent/t.jsonl"}) is None
    assert hook.verdict({}) is None
    assert hook.verdict({"last_assistant_message": "Needs Noah: x"})["decision"] == "block"


def test_cortex_history_is_read_beside_the_metadata_document(tmp_path):
    (tmp_path / "c.json").write_text("{}")
    prompt = {"role": "user", "content": [{"type": "text", "text": "hi", "is_user_prompt": True}]}
    injected = {"role": "user", "content": [{"type": "text", "text": "context"}]}
    final = {"role": "assistant", "content": [{"type": "text", "text": "Waits on you: x"}]}
    (tmp_path / "c.history.jsonl").write_text("\n".join(_lines(prompt, injected, final)))
    assert hook.verdict({"transcript_path": str(tmp_path / "c.json")})["decision"] == "block"
