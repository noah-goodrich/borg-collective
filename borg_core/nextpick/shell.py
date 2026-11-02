"""The impure rung for `borg next` logging: append one JSONL row to the state root. Fail-open."""

from __future__ import annotations

import json
import os
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from borg_core import paths, retention
from borg_core.link import core as link_core
from borg_core.link import shell as link_shell
from borg_core.nextpick import sweeprow
from borg_core.planstate import shell as planstate_shell
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


def read_plans(repositories: dict[str, Any], names: list[str]) -> dict[str, dict[str, Any]]:
    """`{repository: {"name", "text", "mtime"}}` for each repository with a PROJECT_PLAN.md at its root or docs/plans/.

    `mtime` is the plan file's modification time in seconds, or None when it cannot be stat-ed.
    """
    found: dict[str, dict[str, Any]] = {}
    for name in names:
        path = str((repositories.get(name) or {}).get("path") or "")
        if not path or path == "null":
            continue
        for candidate in (Path(path) / "PROJECT_PLAN.md", Path(path) / "docs" / "plans" / "PROJECT_PLAN.md"):
            try:
                text = candidate.read_text(encoding="utf-8")
            except OSError:
                continue
            try:
                mtime: float | None = candidate.stat().st_mtime
            except OSError:
                mtime = None
            found[name] = {"name": plan_name(text, name), "text": text, "mtime": mtime}
            break
    return found


def checkpoint_owned(repositories: dict[str, Any], names: list[str]) -> dict[str, dict[str, Any]]:
    """`{repository: {"items": owned items, "mtime": float | None}}` of its newest checkpoint. Fail-open.

    Reads the WHOLE checkpoint (Blockers sits past the first 20 lines) through `link.shell` (repo-group union read,
    newest by name, content-deduped), so the "newest checkpoint" is the very document `borg link` shows. A repository
    whose checkpoint yields no items, or cannot be read, is omitted.
    """
    found: dict[str, dict[str, Any]] = {}
    for name in names:
        try:
            sources = link_core.repo_sources(name, repositories)
            text, mtime = link_shell.read_latest_checkpoint(sources)
            items = recon_core.checkpoint_owned_items(text)
        # JUSTIFICATION: a checkpoint that cannot be read must leave the cell blank, never fail the chooser.
        except Exception:  # pylint: disable=broad-exception-caught
            continue
        if items:
            found[name] = {"items": items, "mtime": mtime}
    return found


QUEEN = "queen"


def sweep_path() -> Path:
    """`<state root>/evals/sweep-last.json`, the weekly eval sweep's summary (contract: evals/sweep/core.py)."""
    return paths.state_root() / "evals" / "sweep-last.json"


def sweep_agent_installed_epoch() -> float | None:
    """The mtime of the sweep agent's installed plist, or None when it is not installed. The label's prefix is the
    machine's, so this matches on the `borg.eval-sweep.plist` suffix instead of re-deriving the label (the one
    resolver is lib/launchd-label.zsh)."""
    try:
        agents = os.environ.get("BORG_LAUNCH_AGENTS_DIR") or str(Path.home() / "Library" / "LaunchAgents")
        found = list(Path(agents).glob("*borg.eval-sweep.plist"))
        return max(p.stat().st_mtime for p in found) if found else None
    except OSError:
        return None


def sweep_items(now_epoch: float) -> list[dict[str, str]]:
    """The `borg next` item the weekly eval sweep raises, or []. Fail-open: any failure reading it is no item, so a
    broken summary can never break `borg next` or `borg link`. The decisions are `sweeprow.sweep_items`."""
    try:
        target = sweep_path()
        present = target.is_file()
        doc: Any = None
        if present:
            try:
                doc = json.loads(target.read_text(encoding="utf-8"))
            except (OSError, ValueError):
                doc = None
        ts_epoch = None
        if isinstance(doc, dict) and isinstance(doc.get("ts"), str):
            try:
                ts_epoch = datetime.fromisoformat(doc["ts"].replace("Z", "+00:00")).timestamp()
            except ValueError:
                ts_epoch = None
        look = f"PYTHONPATH={Path(__file__).resolve().parents[2]} python3 -m borg_core.evals.history --report"
        return sweeprow.sweep_items(present, doc, now_epoch, ts_epoch, sweep_agent_installed_epoch(), look)
    # JUSTIFICATION: an unreadable sweep summary must mean no item, never a failed chooser.
    except Exception:  # pylint: disable=broad-exception-caught
        return []


def queen_owned() -> dict[str, dict[str, Any]]:
    """`{"queen": {"items": owned items, "mtime": float | None}}`: the Queen's newest checkpoint items plus the
    weekly eval sweep's item, or `{}`. Fail-open.

    The Queen is not in the registry; its checkpoints live in `<orchestrator root>/.borg/checkpoints`. The read is the
    one repositories use (`link.shell.read_latest_checkpoint`, then `recon.core.checkpoint_owned_items`), so the rows
    carry the same owners and freshness. A missing or unreadable directory yields no checkpoint items; the sweep item
    is added after them (it is an orchestrator-level wait, not any repository's).
    """
    items: list[dict[str, str]] = []
    mtime = None
    try:
        text, mtime = link_shell.read_latest_checkpoint([(QUEEN, link_shell.orchestrator_root())])
        items = recon_core.checkpoint_owned_items(text)
    # JUSTIFICATION: an unreadable Queen checkpoint must mean no Queen rows, never a failed chooser.
    except Exception:  # pylint: disable=broad-exception-caught
        items = []
    items = [*items, *sweep_items(datetime.now(timezone.utc).timestamp())]
    return {QUEEN: {"items": items, "mtime": mtime}} if items else {}


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
        planstate_shell.write_atomic(target, f"{now}\t{line}\n")
        return True
    except OSError:
        return False
