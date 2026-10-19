"""The impure rung for `borg next` logging: append one JSONL row to the state root. Fail-open."""

from __future__ import annotations

import json
import os
import re
from pathlib import Path
from typing import Any

from borg_core import paths, retention
from borg_core.link import core as link_core
from borg_core.link import shell as link_shell
from borg_core.nextpick import core
from borg_core.recon import core as recon_core

LOG_NAME = "next-recs.jsonl"


def log_path() -> Path:
    """`<state root>/next-recs.jsonl`."""
    return paths.state_root() / LOG_NAME


def append_row(row: dict[str, Any]) -> bool:
    """Rotate if over the cap, then append `row` as one line. True on success, False on any I/O failure."""
    try:
        line = json.dumps(row, separators=(",", ":")) + "\n"
        target = log_path()
        os.makedirs(os.path.dirname(target), exist_ok=True)
        retention.rotate_log(target)
        with open(target, "a", encoding="utf-8") as handle:
            handle.write(line)
        return True
    except (OSError, TypeError, ValueError):
        return False


def recon_items(repositories: dict[str, Any], local: bool) -> tuple[dict[str, list[dict[str, Any]]], str | None]:
    """`(items grouped by repository, degraded note)` from the recon sweep `borg recon --json` runs. Fail-open.

    Uses `link.shell.sweep`, the in-process fan-out under its own 10s per-adapter deadline (inside the 15s network
    bound). Unlike `borg recon --json` it NEVER writes the last-run marker, so `--rows --json` stays read-only.
    `--local` skips the sweep entirely: no adapter discovery, no subprocess, no network, no note.
    """
    if local:
        return {}, None
    live = {name: entry for name, entry in repositories.items() if entry.get("status") != "archived"}
    try:
        result = link_shell.sweep(live)
        tracks = result.get("tracks") or []
        by_repository = recon_core.merge_by_repository(tracks)
        failed = [str(t.get("source")) for t in tracks if t.get("ok") is False]
        if not result.get("swept"):
            note = "; ".join(result.get("warnings") or []) or "sweep did not run"
        elif failed:
            note = "sweep source failed: " + ", ".join(failed)
        else:
            note = None
    # JUSTIFICATION: a failed sweep must degrade the rows to the other sources, never fail the chooser.
    except Exception as exc:  # pylint: disable=broad-exception-caught
        return {}, f"sweep failed: {exc}"
    return by_repository, note


_PLAN_TITLE = re.compile(r"^#\s*Project Plan:\s*(.+?)\s*$", re.MULTILINE)
_PLAN_SLUG = re.compile(r"^- Plan-slug:\s*(.+?)\s*$", re.MULTILINE)


def plan_name(text: str, fallback: str) -> str:
    """The plan's name: its `# Project Plan:` title, else its `- Plan-slug:` value, else `fallback`. Backticks go."""
    for pattern in (_PLAN_TITLE, _PLAN_SLUG):
        found = pattern.search(text)
        if found:
            value = found[1]
            return value.replace("`", "").strip()
    return fallback


def read_plans(repositories: dict[str, Any], names: list[str]) -> dict[str, dict[str, str]]:
    """`{repository: {"name", "text"}}` for each repository with a PROJECT_PLAN.md at its root or under docs/plans/."""
    found: dict[str, dict[str, str]] = {}
    for name in names:
        path = str((repositories.get(name) or {}).get("path") or "")
        if not path or path == "null":
            continue
        for candidate in (Path(path) / "PROJECT_PLAN.md", Path(path) / "docs" / "plans" / "PROJECT_PLAN.md"):
            try:
                text = candidate.read_text(encoding="utf-8")
            except OSError:
                continue
            found[name] = {"name": plan_name(text, name), "text": text}
            break
    return found


_WHOLE_CHECKPOINT_LINES = 1_000_000


def checkpoint_next_steps(repositories: dict[str, Any], names: list[str]) -> dict[str, str]:
    """`{repository: first next-session item of its latest checkpoint}` for the names that have one. Fail-open.

    Resolves the checkpoint through `link.shell` (repo-group union read, name-sorted, content-deduped), so the
    "latest checkpoint" is the very document `borg link` shows. Any error for a repository omits that repository.
    """
    found: dict[str, str] = {}
    for name in names:
        try:
            sources = link_core.repo_sources(name, repositories)
            text = link_shell.read_latest_checkpoint_head(sources, _WHOLE_CHECKPOINT_LINES)
            step = core.checkpoint_next_step(text)
        # JUSTIFICATION: a checkpoint that cannot be read must leave the cell blank, never fail the chooser.
        except Exception:  # pylint: disable=broad-exception-caught
            continue
        if step:
            found[name] = step
    return found


def read_log_rows() -> list[dict[str, Any]]:
    """Every parseable row of `next-recs.jsonl`, rotated generation first. Missing or unreadable files yield []."""
    target = log_path()
    rows: list[dict[str, Any]] = []
    for path in (Path(f"{target}.1"), target):
        try:
            with open(path, encoding="utf-8") as handle:
                lines = handle.read().splitlines()
        except OSError:
            continue
        for line in lines:
            try:
                row = json.loads(line)
            except ValueError:
                continue
            if isinstance(row, dict):
                rows.append(row)
    return rows


GLANCE_NAME = "next-glance"


def glance_path() -> Path:
    """`<state root>/next-glance`: one line, `<epoch>\\t<glance line>`, read by `borg next --line` (zsh, no Python)."""
    return paths.state_root() / GLANCE_NAME


def write_glance(line: str, now: int) -> bool:
    """Replace the glance cache with `line` stamped `now`, atomically. True on success, False on any I/O failure."""
    try:
        target = glance_path()
        os.makedirs(os.path.dirname(target), exist_ok=True)
        tmp = Path(f"{target}.tmp.{os.getpid()}")
        tmp.write_text(f"{now}\t{line}\n", encoding="utf-8")
        os.replace(tmp, target)
        return True
    except OSError:
        return False
