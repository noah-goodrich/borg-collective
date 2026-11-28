"""Thin I/O: find a session's transcripts, read them, and ask `gh` for the PR list."""

from __future__ import annotations

import json
import os
from pathlib import Path

from borg_core.gh import shell as gh
from borg_core.spend.core import pr_repositories
from borg_core.spend.parse import PR_URL, Transcript, parse_transcript


class SpendError(RuntimeError):
    """A usage or discovery failure the CLI reports by name and exits 2 on."""


def default_projects_dir() -> Path:
    """`$CLAUDE_CONFIG_DIR/projects`, else `$HOME/.claude/projects`."""
    base = os.environ.get("CLAUDE_CONFIG_DIR")
    return Path(base) / "projects" if base else Path.home() / ".claude" / "projects"


def find_session(projects_dir: Path, prefix: str) -> tuple[Path, list[Path]]:
    """The main transcript whose uuid starts with `prefix`, and its subagent transcripts. Refuses 0 or 2+ matches."""
    if not prefix:
        raise SpendError("--session needs a session id or prefix")
    found = sorted(p for p in projects_dir.glob(f"*/{prefix}*.jsonl") if p.is_file())
    if not found:
        raise SpendError(f"no session matches '{prefix}' under {projects_dir}")
    if len(found) > 1:
        raise SpendError(f"session prefix '{prefix}' is ambiguous: " + ", ".join(p.stem for p in found))
    main = found[0]
    return main, sorted((main.parent / main.stem / "subagents").glob("agent-*.jsonl"))


def _entries(path: Path):
    with path.open(encoding="utf-8", errors="replace") as handle:
        for line in handle:
            try:
                yield json.loads(line)
            except ValueError:
                continue


def _agent_type(path: Path) -> str:
    try:
        return json.loads(path.with_suffix(".meta.json").read_text(encoding="utf-8")).get("agentType") or "unknown"
    except (OSError, ValueError):
        return "unknown"


def load_session(main: Path, agents: list[Path]) -> list[Transcript]:
    """Parse the main transcript and every subagent transcript."""
    out = [parse_transcript(_entries(main), main.stem)]
    out += [parse_transcript(_entries(a), a.stem, agent=True, agent_type=_agent_type(a)) for a in agents]
    return out


def listed_prs(prs: list[str], start: str, end: str) -> list[str]:
    """PR URLs `gh pr list` shows for each repository the transcripts opened PRs in, over the window."""
    urls: list[str] = []
    for repo in pr_repositories(prs):
        argv = ["pr", "list", "--repo", repo, "--state", "all", "--author", "@me", "--limit", "200"]
        code, out, err = gh.run([*argv, "--search", f"created:{start}..{end}", "--json", "url"])
        if code != 0:
            raise SpendError(f"gh pr list failed for {repo}: {err.strip()}")
        urls += [row["url"] for row in json.loads(out or "[]") if PR_URL.match(row.get("url", ""))]
    return urls
