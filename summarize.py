#!/usr/bin/env python3
"""
summarize.py — Extract a 2-3 sentence context summary from a Claude Code
JSONL transcript.

Usage:
    python3 summarize.py /path/to/transcript.jsonl
    tail -200 transcript.jsonl | python3 summarize.py

Output: plain text summary to stdout (2-3 sentences)

Pattern reused from ~/.config/dotfiles/claude/code/hooks/pre-compact.py
"""

import json
import sys
from pathlib import Path


def read_jsonl(source) -> list[dict]:
    messages = []
    for line in source:
        line = line.strip()
        if line:
            try:
                messages.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return messages


def extract_text(content) -> str:
    if isinstance(content, str):
        return content.strip()
    if isinstance(content, list):
        parts = []
        for block in content:
            if isinstance(block, dict) and block.get("type") == "text":
                parts.append(block["text"].strip())
        return " ".join(parts)
    return ""


def extract_files_modified(messages: list[dict]) -> list[str]:
    files: set[str] = set()
    for msg in messages:
        role, content = unwrap_message(msg)
        if role != "assistant":
            continue
        if not isinstance(content, list):
            continue
        for block in content:
            if not isinstance(block, dict) or block.get("type") != "tool_use":
                continue
            if block.get("name") in ("Edit", "Write"):
                fp = block.get("input", {}).get("file_path", "")
                if fp:
                    files.add(fp)
    return sorted(files)


def unwrap_message(msg: dict) -> tuple[str, any]:
    """Extract role and content from a JSONL entry.

    Claude Code JSONL uses nested format: {type, message: {role, content}}
    Falls back to flat format: {role, content}
    """
    inner = msg.get("message", msg)
    role = inner.get("role", "")
    content = inner.get("content", "")
    return role, content


def summarize(messages: list[dict]) -> str:
    user_messages: list[str] = []
    assistant_messages: list[str] = []

    for msg in messages:
        role, content = unwrap_message(msg)
        text = extract_text(content)
        if not text:
            continue
        if role == "user":
            user_messages.append(text)
        elif role == "assistant":
            assistant_messages.append(text)

    if not user_messages and not assistant_messages:
        return "No conversation content found."

    parts: list[str] = []

    # Goal: first user message (truncated)
    if user_messages:
        goal = user_messages[0][:300].replace("\n", " ").strip()
        if len(user_messages[0]) > 300:
            goal += "..."
        parts.append(f"Goal: {goal}")

    # Files modified
    files = extract_files_modified(messages)
    if files:
        # Show up to 4 files, then "and N more"
        if len(files) <= 4:
            parts.append(f"Modified: {', '.join(Path(f).name for f in files)}")
        else:
            shown = ", ".join(Path(f).name for f in files[:4])
            parts.append(f"Modified: {shown} and {len(files) - 4} more")

    # Last user message = most recent request (if different from first)
    if len(user_messages) > 1:
        last = user_messages[-1][:200].replace("\n", " ").strip()
        if len(user_messages[-1]) > 200:
            last += "..."
        parts.append(f"Last request: {last}")
    elif assistant_messages:
        # Fallback: truncate last assistant response
        last_a = assistant_messages[-1][:200].replace("\n", " ").strip()
        if len(assistant_messages[-1]) > 200:
            last_a += "..."
        parts.append(f"Last response: {last_a}")

    return " | ".join(parts)


def main():
    if len(sys.argv) > 1:
        path = Path(sys.argv[1])
        if not path.exists():
            print(f"File not found: {path}", file=sys.stderr)
            sys.exit(1)
        # Read last 200 lines for speed on large transcripts
        with open(path) as f:
            lines = f.readlines()
        messages = read_jsonl(lines[-200:])
    else:
        # Read from stdin (piped: tail -200 transcript.jsonl | python3 summarize.py)
        messages = read_jsonl(sys.stdin)

    print(summarize(messages))


if __name__ == "__main__":
    main()
