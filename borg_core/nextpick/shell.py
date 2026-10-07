"""The impure rung for `borg next` logging: append one JSONL row to the state root. Fail-open."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any

from borg_core import paths, retention
from borg_core.link import core as link_core
from borg_core.link import shell as link_shell
from borg_core.nextpick import core

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


LINK_TIMEOUT_S = 15


def link_document(local: bool, timeout: float = LINK_TIMEOUT_S) -> dict[str, Any] | None:
    """The `borg link --json` document built in ORCHESTRATOR scope, or None on any failure.

    chooser_rows needs every project's manifests, and `link` narrows them to one repository when its cwd sits
    inside a registered project. So the child runs with cwd = the orchestrator root (`link.shell.orchestrator_root`,
    the same BORG_ORCHESTRATOR_ROOT-or-~/dev rule `link` itself uses to decide scope). `--local` skips the network.
    """
    argv = [sys.executable, "-m", "borg_core.link.cli", "--json"] + (["--local"] if local else [])
    root = link_shell.orchestrator_root()
    env = dict(os.environ)
    package_parent = str(Path(__file__).resolve().parents[2])
    env["PYTHONPATH"] = package_parent + (os.pathsep + env["PYTHONPATH"] if env.get("PYTHONPATH") else "")
    try:
        proc = subprocess.run(
            argv,
            cwd=root if os.path.isdir(root) else None,
            env=env,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
        doc = json.loads(proc.stdout) if proc.returncode == 0 else None
    except (OSError, ValueError, subprocess.SubprocessError):
        return None
    return doc if isinstance(doc, dict) else None


_WHOLE_CHECKPOINT_LINES = 1_000_000


def checkpoint_next_steps(projects: dict[str, Any], names: list[str]) -> dict[str, str]:
    """`{project: first next-session item of its latest checkpoint}` for the names that have one. Fail-open.

    Resolves the checkpoint through `link.shell` (repo-group union read, name-sorted, content-deduped), so the
    "latest checkpoint" is the very document `borg link` shows. Any error for a project omits that project.
    """
    found: dict[str, str] = {}
    for name in names:
        try:
            sources = link_core.repo_sources(name, projects)
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
