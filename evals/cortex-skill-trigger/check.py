#!/usr/bin/env python3
"""Grade whether a skill fired in a Cortex Code run. Tier 1: pure functions over recorded or live output.

Cortex shows a skill invocation twice, and both are exact (no model, no regex over prose):
  stream  an `assistant` event whose content has a `tool_use` named `skill` with input {"command": "<skill>"}
  hook    a PreToolUse/PostToolUse payload with tool_name `skill` and tool_input {"command": "<skill>"}

usage:
  check.py fired <stream.jsonl> [<hooks.jsonl>]     print the skills that fired, one per line
  check.py grade <stream.jsonl> <skill> <should_fire:true|false> [<hooks.jsonl>]
                                                    print `CHECK pass|fail <id> <msg>`; exit 1 on fail
  check.py tokens <stream.jsonl>                    print the run's total tokens (input+cache+output)
"""

import json
import sys


def _events(path):
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if line:
                try:
                    yield json.loads(line)
                except ValueError:
                    continue


def stream_skills(path):
    """Skill names the model invoked, in order, read from `skill` tool_use blocks in the stream."""
    names = []
    for ev in _events(path):
        if ev.get("type") != "assistant":
            continue
        content = (ev.get("message") or {}).get("content")
        if not isinstance(content, list):
            continue
        for block in content:
            if block.get("type") == "tool_use" and block.get("name") == "skill":
                cmd = (block.get("input") or {}).get("command")
                if cmd:
                    names.append(cmd)
    return names


def hook_skills(path):
    """Skill names read from hook payloads (PreToolUse only, so one invocation counts once)."""
    return [
        ev["tool_input"]["command"]
        for ev in _events(path)
        if ev.get("hook_event_name") == "PreToolUse"
        and ev.get("tool_name") == "skill"
        and (ev.get("tool_input") or {}).get("command")
    ]


def total_tokens(path):
    total = 0
    for ev in _events(path):
        if ev.get("type") == "result":
            for u in (ev.get("modelUsage") or {}).values():
                total += sum(
                    u.get(k, 0)
                    for k in ("inputTokens", "outputTokens", "cacheReadInputTokens", "cacheCreationInputTokens")
                )
    return total


def grade(stream, skill, should_fire, hooks=None):
    """Return (ok, message). A run that fired the skill passes a should-fire case; any run that did NOT fire it
    passes a should-not-fire case. When hook payloads are given they must agree with the stream."""
    seen = stream_skills(stream)
    if hooks is not None and sorted(set(hook_skills(hooks))) != sorted(set(seen)):
        return False, f"stream {sorted(set(seen))} and hooks {sorted(set(hook_skills(hooks)))} disagree"
    fired = skill in seen
    if fired == should_fire:
        return True, f"{'fired' if fired else 'did not fire'} {skill}, as expected (skills seen: {seen})"
    return False, f"{'fired' if fired else 'did not fire'} {skill}, expected {'fire' if should_fire else 'no fire'}"


def main(argv):
    if len(argv) >= 3 and argv[1] == "fired":
        for name in stream_skills(argv[2]):
            print(name)
        return 0
    if len(argv) >= 3 and argv[1] == "tokens":
        print(total_tokens(argv[2]))
        return 0
    if len(argv) >= 5 and argv[1] == "grade":
        ok, msg = grade(argv[2], argv[3], argv[4] == "true", argv[5] if len(argv) > 5 else None)
        print(f"CHECK {'pass' if ok else 'fail'} {argv[3]} {msg}")
        return 0 if ok else 1
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
