"""Transcript entries (parsed JSONL dicts) to the few facts the report needs. Pure: no file or network access."""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from datetime import datetime, timezone

SYNTHETIC = "<synthetic>"
PR_URL = re.compile(r"https://github\.com/([\w.-]+/[\w.-]+)/pull/(\d+)")
_WORKTREE = re.compile(r"/[^ ;\"]*/borg/worktrees/[^ ;\"]*")
_WAIT_CI = re.compile(r"gh pr checks|until |sleep ")
_TEST = re.compile(r"make |pytest|bats|ruff|shellcheck|npm |uv run")
_GH = re.compile(r"gh |curl ")
_GIT = re.compile(
    r"git [-a-zA-Z/ ]*(worktree|fetch|pull|push|rebase|checkout|merge|commit|add|status|log|diff|rev-parse|branch"
    r"|stash|reset|cherry-pick|show)"
)
_READ = re.compile(r"^(grep|rg|find|sed -n|cat|head|tail|ls|wc|jq) |\| *(grep|head|tail|jq)")
_PR_CREATE = re.compile(r"gh pr create")
_API_POST = re.compile(r"-X\s*POST|--method\s*POST|\s(-f|-F|--field|--raw-field|--input)\b")
_PULLS = re.compile(r"/pulls(?![\w/])")
CI_WAIT_KIND = "Bash:wait-ci"


def parse_ts(text: str) -> datetime:
    """An ISO-8601 timestamp (Z or offset) as an aware UTC datetime; a naive value is read as UTC."""
    value = datetime.fromisoformat(text.replace("Z", "+00:00"))
    # JUSTIFICATION: stdlib datetime method chain
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)  # pylint: disable=clean-arch-demeter


def bash_kind(command: str) -> str:
    """Classify a Bash command the way the baseline jq did."""
    cmd = _WORKTREE.sub("WT", command)
    for pattern, kind in (
        (_WAIT_CI, CI_WAIT_KIND),
        (_TEST, "Bash:test"),
        (_GH, "Bash:gh"),
        (_GIT, "Bash:git"),
        (_READ, "Bash:read"),
    ):
        if pattern.search(cmd):
            return kind
    return "Bash:other"


def makes_pr(command: str) -> bool:
    """True when a Bash command creates a pull request: `gh pr create` or a `gh api` POST to .../pulls."""
    if _PR_CREATE.search(command):
        return True
    return bool("gh api" in command and _PULLS.search(command) and _API_POST.search(command))


@dataclass(frozen=True)
class ToolUse:
    """One tool_use block: its id, the classified kind, and whether it creates a PR."""

    id: str
    kind: str
    pr: bool = False


@dataclass
# JUSTIFICATION: a flat record of one transcript entry; grouping the token counts would just rename them
class Assist:  # pylint: disable=too-many-instance-attributes
    """One assistant entry carrying usage (several entries can share a message id)."""

    msg_id: str
    model: str
    ts: datetime
    fresh: int
    out: int
    write_total: int
    write_5m: int | None
    write_1h: int
    read: int
    tools: tuple[ToolUse, ...] = ()


@dataclass
class Transcript:
    """Everything the report reads from one transcript file."""

    key: str
    agent: bool = False
    agent_type: str = ""
    assists: list[Assist] = field(default_factory=list)
    results: dict[str, tuple[datetime, str]] = field(default_factory=dict)
    boundaries: list[datetime] = field(default_factory=list)
    pr_links: list[tuple[datetime, str]] = field(default_factory=list)


def _tool(block: dict) -> ToolUse:
    name = block.get("name") or "?"
    if name != "Bash":
        return ToolUse(block.get("id") or "", name)
    command = (block.get("input") or {}).get("command") or ""
    return ToolUse(block.get("id") or "", bash_kind(command), makes_pr(command))


def _assist(entry: dict) -> Assist | None:
    msg = entry.get("message") or {}
    usage = msg.get("usage")
    model = msg.get("model") or ""
    if usage is None or model == SYNTHETIC or not entry.get("timestamp"):
        return None
    split = usage.get("cache_creation") or {}
    content = msg.get("content")
    blocks = [b for b in content if isinstance(b, dict)] if isinstance(content, list) else []
    return Assist(
        msg_id=msg.get("id") or entry.get("uuid") or "",
        model=model,
        ts=parse_ts(entry["timestamp"]),
        fresh=usage.get("input_tokens") or 0,
        out=usage.get("output_tokens") or 0,
        write_total=usage.get("cache_creation_input_tokens") or 0,
        write_5m=split.get("ephemeral_5m_input_tokens"),
        write_1h=split.get("ephemeral_1h_input_tokens") or 0,
        read=usage.get("cache_read_input_tokens") or 0,
        tools=tuple(_tool(b) for b in blocks if b.get("type") == "tool_use"),
    )


def _result_text(block: dict) -> str:
    content = block.get("content")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(str(p.get("text") or "") for p in content if isinstance(p, dict))
    return ""


def _results(entry: dict, out: dict[str, tuple[datetime, str]]) -> None:
    content = (entry.get("message") or {}).get("content")
    if not isinstance(content, list) or not entry.get("timestamp"):
        return
    ts = parse_ts(entry["timestamp"])
    for block in content:
        if isinstance(block, dict) and block.get("type") == "tool_result" and block.get("tool_use_id"):
            text = _result_text(block)
            out[block["tool_use_id"]] = (ts, text if "/pull/" in text else "")


def _on_assistant(entry: dict, out: Transcript) -> None:
    assist = _assist(entry)
    if assist:
        out.assists.append(assist)


def _on_user(entry: dict, out: Transcript) -> None:
    if entry.get("isCompactSummary") and entry.get("timestamp"):
        out.boundaries.append(parse_ts(entry["timestamp"]))
    _results(entry, out.results)


def _on_pr_link(entry: dict, out: Transcript) -> None:
    if entry.get("timestamp") and PR_URL.match(entry.get("prUrl") or ""):
        out.pr_links.append((parse_ts(entry["timestamp"]), entry["prUrl"]))


def _on_system(entry: dict, out: Transcript) -> None:
    if entry.get("subtype") == "compact_boundary" and entry.get("timestamp"):
        out.boundaries.append(parse_ts(entry["timestamp"]))


_HANDLERS = {"assistant": _on_assistant, "user": _on_user, "pr-link": _on_pr_link, "system": _on_system}


def parse_transcript(entries, key: str, agent: bool = False, agent_type: str = "") -> Transcript:
    """Reduce an iterable of parsed JSONL dicts to a Transcript; entries the report does not read are dropped."""
    out = Transcript(key=key, agent=agent, agent_type=agent_type)
    for entry in entries:
        handler = _HANDLERS.get(entry.get("type"))
        if handler:
            handler(entry, out)
    return out
