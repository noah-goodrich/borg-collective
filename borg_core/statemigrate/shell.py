"""The impure rungs of the state migration: observe the filesystem, back up, apply, verify, remove."""

from __future__ import annotations

import os
import shutil
from datetime import datetime, timezone
from pathlib import Path

from borg_core.statemigrate import core


def discover(old_root: Path, new_root: Path) -> list[core.Entry]:
    """Every MOVED file present at either location (the planner skips what is absent at old)."""
    rels = set(core.MOVED_FILES)
    for directory, pattern in core.MOVED_GLOBS:
        for root in (old_root, new_root):
            base = root / directory
            if base.is_dir():
                rels.update(str(p.relative_to(root)) for p in base.glob(pattern) if p.is_file())
    return [core.Entry(r, (old_root / r).is_file(), (new_root / r).is_file()) for r in sorted(rels)]


def backup_dir(new_root: Path) -> Path:
    """A fresh, unique timestamped directory under `<state root>/tidy-backups/`."""
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    base = new_root / "tidy-backups"
    candidate = base / stamp
    n = 1
    while candidate.exists():
        n += 1
        candidate = base / f"{stamp}-{n}"
    candidate.mkdir(parents=True)
    return candidate


def write_atomic(dest: Path, data: bytes) -> None:
    """Write via a temp file in the same directory, then rename into place."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_name(f".{dest.name}.migrate-tmp")
    with open(tmp, "wb") as handle:
        handle.write(data)
    os.replace(tmp, dest)


def copy_file(src: Path, dest: Path) -> None:
    """Copy with metadata, creating parent directories."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dest)


def apply(action: core.Action, old_root: Path, new_root: Path, backups: Path) -> str | None:
    """Back up, apply and verify one action; remove the old copy only on success.

    Returns None on success, else a failure reason (old copy left in place).
    """
    old, new = old_root / action.rel, new_root / action.rel
    copy_file(old, backups / action.rel)
    prev_new = new.read_bytes() if new.is_file() else b""
    if prev_new:
        copy_file(new, backups / (action.rel + ".new"))
    old_bytes = old.read_bytes()
    want = core.expected_result(action.op, old_bytes, prev_new)
    if want is None:
        return None
    if action.op != core.KEEP_NEW:
        write_atomic(new, want)
    problem = core.verify(action.rel, action.op, old_bytes, prev_new, new.read_bytes())
    if problem:
        return problem
    old.unlink()
    return None


def migrate(old_root: Path, new_root: Path, dry_run: bool) -> tuple[list[core.Action], list[str]]:
    """Plan, and unless `dry_run`, execute. Returns (actions that were not SKIP, failures)."""
    actions = [a for a in core.plan(discover(old_root, new_root)) if a.op != core.SKIP]
    failures: list[str] = []
    if dry_run or not actions:
        return actions, failures
    backups = backup_dir(new_root)
    for action in actions:
        problem = apply(action, old_root, new_root, backups)
        if problem:
            failures.append(problem)
    return actions, failures
