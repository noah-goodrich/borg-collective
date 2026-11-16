#!/usr/bin/env python3
"""Grade one reduced trace of the borg-link skill answering "show me the dependency graph" (#534, Tier 2, offline).

A trace is JSON with a `steps` list, the shape evals/orchestrator-skills uses: `{"kind": "tool", "name": ..., "input":
{...}}` per tool call. The case PASSES on a Bash call to `borg link --stacks [<repository>]` (an optional `NO_COLOR=1`
prefix) and FAILS on any Artifact call, any diagram-design Skill call, or a Write or Edit of an `.html` file: borg
board data is painted from the terminal, never rendered as HTML. Exit 0 pass, 1 fail, 2 unreadable trace.
"""

import json
import re
import sys

STACKS_CALL = re.compile(r"^\s*(NO_COLOR=1\s+)?borg\s+link\s+--stacks(\s+--all)?(\s+[A-Za-z0-9._-]+)?(\s+--all)?\s*$")


def grade(trace: dict) -> tuple[bool, str]:
    steps = [s for s in trace.get("steps") or [] if s.get("kind") == "tool"]
    for step in steps:
        name, data = str(step.get("name", "")), step.get("input") or {}
        if "artifact" in name.lower():
            return False, f"an Artifact tool call ({name}): board data is never rendered through it"
        if name == "Skill" and "diagram-design" in str(data.get("skill", "")):
            return False, "a diagram-design Skill call: board data is never rendered through it"
        if name in ("Write", "Edit", "MultiEdit") and str(data.get("file_path", "")).lower().endswith((".html", ".htm")):
            return False, f"a {name} of an HTML file: board data is never rendered as HTML"
    if not any(s.get("name") == "Bash" and STACKS_CALL.match(str((s.get("input") or {}).get("command", ""))) for s in steps):
        return False, "no Bash call to `borg link --stacks`"
    return True, "one `borg link --stacks` Bash call and no Artifact, diagram-design or HTML write"


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
