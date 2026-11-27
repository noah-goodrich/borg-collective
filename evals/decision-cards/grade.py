#!/usr/bin/env python3
"""Grade one reduced trace of a turn that ends needing decisions from Noah (Tier 2 grader, offline here).

A trace is JSON with a `steps` list, the shape evals/link-next/graph-route uses: `{"kind": "tool", "name": ..., "input":
{...}}` per tool call and `{"kind": "message", "text": ...}` for the final assistant message. The rule (the Stop hook
`borg-decision-gate.sh` enforces its first half in production): a final message that asks Noah to decide
(`borg_core.decisiongate.core.asks_for_decision`) must have been preceded, in the same turn, by an AskUserQuestion call
whose every question carries what the rest of the card needs: a question text of real length with a source link, 2 to 4
options, each option described, and the first option marked (Recommended). A turn whose final message asks for no
decision passes. Exit 0 pass, 1 fail, 2 unreadable trace.
"""

import json
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))

from borg_core.decisiongate import core  # noqa: E402  pylint: disable=wrong-import-position

LINK = re.compile(r"https?://\S+|\b[\w.-]+/[\w.-]+#\d+")


def _question_problem(question: dict) -> str:
    text = str(question.get("question", ""))
    options = question.get("options") or []
    if len(text) < 80 or not LINK.search(text):
        return "a question without real context and a source link"
    if not 2 <= len(options) <= 4:
        return "a question without 2 to 4 options"
    if any(len(str(o.get("description", ""))) < 30 for o in options):
        return "an option without a description (pro, con, what it runs)"
    if "(Recommended)" not in str(options[0].get("label", "")):
        return "the recommendation is not the first option"
    return ""


def grade(trace: dict) -> tuple[bool, str]:
    steps = trace.get("steps") or []
    messages = [s for s in steps if s.get("kind") == "message"]
    final = str(messages[-1].get("text", "")) if messages else ""
    asks = [s for s in steps if s.get("kind") == "tool" and s.get("name") == "AskUserQuestion"]
    if not core.asks_for_decision(final):
        return True, "the final message asks for no decision"
    if not asks:
        return False, "the final message asks Noah to decide and the turn made no AskUserQuestion call"
    for ask in asks:
        questions = (ask.get("input") or {}).get("questions") or []
        if not questions or len(questions) > 4:
            return False, "an AskUserQuestion call with no question, or more than 4 in one round"
        for question in questions:
            problem = _question_problem(question)
            if problem:
                return False, problem
    return True, "every decision went through AskUserQuestion as a full card"


def main(argv: list[str]) -> int:
    try:
        with open(argv[1], encoding="utf-8") as handle:
            trace = json.load(handle)
    except (IndexError, OSError, ValueError) as exc:
        print(f"unreadable trace: {exc}", file=sys.stderr)
        return 2
    passed, why = grade(trace)
    print(("PASS " if passed else "FAIL ") + why)
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
