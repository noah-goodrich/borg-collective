"""The impure half of the decision gate: `hooks/borg-decision-gate.sh` runs `python3 -m` on this as a Stop hook.

Reads the Stop payload on stdin, reads the turn out of the transcript, and prints `{"decision": "block", "reason": ...}`
when the turn's final assistant message asks Noah to decide (`core.asks_for_decision`) and the turn made no
AskUserQuestion call. Otherwise it prints nothing.

THE TURN is everything after the last real user prompt. Claude Code's transcript is JSONL of `{"type": "user" |
"assistant", "message": {"content": str | [blocks]}}`; Cortex's `transcript_path` is `<id>.json`, a metadata document
with no messages, so its messages are read from `<id>.history.jsonl` beside it (`{"role", "content": [blocks]}`, a
prompt flagged `is_user_prompt`, tool calls as `{"type": "tool_use", "tool_use": {"name": ...}}`).

NEVER BLOCKS TWICE: a payload with `stop_hook_active` true is the model's answer to our own block, so it passes.
FAILS OPEN: no transcript, a transcript that cannot be read, a crash, all print nothing and exit 0. A plugin hook fires
in every session on the machine, so the scope is every session, Queen and repository alike.
"""

from __future__ import annotations

import json
import os
from typing import Any

from borg_core.decisiongate import core

TAIL_BYTES = 2 * 1024 * 1024


def _tail_lines(path: str) -> list[str]:
    """The last `TAIL_BYTES` of a file as lines, the first (possibly cut) line dropped."""
    with open(path, "rb") as handle:
        size = handle.seek(0, os.SEEK_END)
        handle.seek(max(0, size - TAIL_BYTES))
        raw = handle.read().decode("utf-8", errors="replace")
    lines = str.splitlines(raw)
    return lines[1:] if size > TAIL_BYTES else lines


def _blocks(content: Any) -> list[dict[str, Any]]:
    if isinstance(content, str):
        return [{"type": "text", "text": content}]
    return [block for block in content if isinstance(block, dict)] if isinstance(content, list) else []


def _tool_name(block: dict[str, Any]) -> str:
    if block.get("type") != "tool_use":
        return ""
    inner = block.get("tool_use")
    name = inner.get("name") if isinstance(inner, dict) else block.get("name")
    return name if isinstance(name, str) else ""


def _event(entry: dict[str, Any]) -> tuple[str, str, set[str]] | None:
    """`(kind, text, tool names)` of one transcript entry, kind `prompt` | `result` | `assistant`; None to skip."""
    nested = entry.get("message")
    message: dict[str, Any] = nested if isinstance(nested, dict) else entry
    role = message.get("role") or entry.get("type")
    blocks = _blocks(message.get("content"))
    if role == "assistant":
        text = "\n".join(b["text"] for b in blocks if b.get("type") == "text" and isinstance(b.get("text"), str))
        return "assistant", text, {n for n in map(_tool_name, blocks) if n}
    if role != "user" or entry.get("isMeta"):
        return None
    if any(b.get("type") == "tool_result" for b in blocks):
        return "result", "", set()
    cortex = "message" not in entry
    texts = [
        b["text"]
        for b in blocks
        if b.get("type") == "text"
        and isinstance(b.get("text"), str)
        and (not cortex or b.get("is_user_prompt") is True)
    ]
    return ("prompt", "\n".join(texts), set()) if texts else None


def read_turn(lines: list[str]) -> tuple[str, bool]:
    """`(final assistant message, whether the turn called AskUserQuestion)` from transcript lines of either format."""
    events: list[tuple[str, str, set[str]]] = []
    for raw in lines:
        try:
            entry = json.loads(raw)
        except ValueError:
            continue
        event = _event(entry) if isinstance(entry, dict) else None
        if event:
            events.append(event)
    last_prompt = max((i for i, event in enumerate(events) if event[0] == "prompt"), default=-1)
    turn = events[last_prompt + 1 :]
    asked = any(event[2] & core.ASK_TOOL_NAMES for event in turn)
    tail: list[str] = []
    for kind, text, _ in reversed(turn):
        if kind != "assistant":
            break
        tail.append(text)
    return "\n".join(reversed([t for t in tail if t])), asked


def _transcript_lines(path: str) -> list[str]:
    if path.endswith(".json"):
        path = path[: -len(".json")] + ".history.jsonl"
    return _tail_lines(path)


def verdict(payload: dict[str, Any]) -> dict[str, str] | None:
    """The block decision for one Stop payload, or None to let the turn end."""
    if payload.get("stop_hook_active"):
        return None
    transcript = payload.get("transcript_path")
    message, asked = "", False
    if isinstance(transcript, str) and transcript:
        try:
            message, asked = read_turn(_transcript_lines(transcript))
        except OSError:
            pass
    given = payload.get("last_assistant_message")
    if isinstance(given, str) and given.strip():
        message = given
    if asked or not message or not core.asks_for_decision(message):
        return None
    return {"decision": "block", "reason": core.reason()}


def main() -> None:
    """Read the Stop payload from stdin and print the block decision, if any. Exit 0 whatever happens."""
    if os.environ.get("BORG_NO_SESSION_HOOKS") == "1":
        return
    try:
        with open(0, encoding="utf-8", errors="replace", closefd=False) as handle:
            payload = json.loads(handle.read() or "{}")
        result = verdict(payload) if isinstance(payload, dict) else None
        if result:
            print(json.dumps(result))
    # JUSTIFICATION: a Stop hook that raises must not disturb the session; the fail-open contract is the point.
    except Exception:  # pylint: disable=broad-exception-caught
        return


if __name__ == "__main__":
    main()
