"""The impure rungs of the project-state migration: observe, back up, apply, verify, remove."""

from __future__ import annotations

import os
import shutil
from pathlib import Path

from borg_core import paths, proc
from borg_core.registry import shell as registry_shell
from borg_core.statemigrate import project_core as core
from borg_core.statemigrate import shell as base


def _tracked(src: Path) -> bool:
    """True when git tracks `src` (it must then never be removed)."""
    captured = proc.run_capture(["git", "-C", str(src.parent), "ls-files", "--error-unmatch", "--", src.name])
    return captured is not None and captured[0] == 0


def registry_projects(registry: dict) -> list[tuple[core.Project, str]]:
    """(precondition view, path) per registry entry. git is forked only for an entry with a null repo."""
    out: list[tuple[core.Project, str]] = []
    for name, entry in sorted((registry.get("projects") or {}).items()):
        entry = entry or {}
        path = str(entry.get("path") or "")
        repo = entry.get("repo") or None
        backed = bool(repo) or bool(path and registry_shell.git_common_dir(path))
        out.append((core.Project(name, repo, backed), path))
    return out


def observe(directory: Path, repo: str | None) -> core.Entry:
    """Observe one project directory; the key uses the registry `repo` (None -> `local-` key)."""
    src = directory / ".borg" / "state.json"
    dest = paths.project_state_file(directory, repo)
    present = src.is_file()
    return core.Entry(str(src), str(dest), present, dest.is_file(), present and _tracked(src))


def apply(action: core.Action, backups: Path) -> str | None:
    """Back up, apply and verify one action; remove the legacy file only on success."""
    src, dest = Path(action.src), Path(action.dest)
    tag = dest.parent.name
    base.copy_file(src, backups / "projects" / tag / "state.json")
    prev_new = dest.read_bytes() if dest.is_file() else b""
    if dest.is_file():
        base.copy_file(dest, backups / "projects" / tag / "state.json.new")
    legacy = src.read_bytes()
    if action.op == core.COPY:
        base.write_atomic(dest, legacy)
    problem = core.verify(action.op, legacy, prev_new, dest.read_bytes())
    if problem:
        return f"{src}: {problem}"
    if action.remove_legacy:
        src.unlink()
        if not any(src.parent.iterdir()):
            shutil.rmtree(src.parent)
    return None


def migrate(entries: list[core.Entry], new_root: Path, dry_run: bool) -> tuple[list[core.Action], list[str]]:
    """Plan, and unless `dry_run`, execute. Returns (actions that were not SKIP, failures)."""
    actions = [a for a in core.plan(entries) if a.op != core.SKIP]
    failures: list[str] = []
    if dry_run or not actions:
        return actions, failures
    backups = base.backup_dir(new_root)
    for action in actions:
        problem = apply(action, backups)
        if problem:
            failures.append(problem)
    return actions, failures


def explicit_entry(file: str, registry: list[tuple[core.Project, str]]) -> core.Entry:
    """An operator-named `.borg/state.json`: reuse a registry entry's repo for the same directory,
    else ask git."""
    directory = Path(os.path.realpath(file)).parent.parent
    for project, path in registry:
        if path and os.path.realpath(path) == str(directory):
            return observe(directory, project.repo)
    return observe(directory, registry_shell.git_common_dir(str(directory)))
