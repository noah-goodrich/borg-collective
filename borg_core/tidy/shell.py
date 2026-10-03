"""I/O for the cairn-leftover cleanup: find, back up, then delete. Never delete before the copy."""

from __future__ import annotations

import shutil
from pathlib import Path

from borg_core.tidy import core


def find(roots: dict[str, Path]) -> list[tuple[str, Path]]:
    """Every leftover directly inside a root, as (root label, path). Top level only; missing roots skip."""
    hits: list[tuple[str, Path]] = []
    for label, root in roots.items():
        if not root.is_dir():
            continue
        for entry in sorted(root.iterdir()):
            if core.is_cairn_leftover(entry.name):
                hits.append((label, entry))
    return hits


def back_up(hits: list[tuple[str, Path]], backup_dir: Path) -> None:
    """Copy each hit to `backup_dir/<label>/<name>`, preserving metadata. Raises on the first failure."""
    for label, path in hits:
        dest = backup_dir / label / path.name
        dest.parent.mkdir(parents=True, exist_ok=True)
        if path.is_dir() and not path.is_symlink():
            shutil.copytree(path, dest, symlinks=True)
        else:
            shutil.copy2(path, dest, follow_symlinks=False)


def delete(hits: list[tuple[str, Path]]) -> None:
    """Remove each hit. A directory goes with its contents; a symlink is unlinked, never followed."""
    for _, path in hits:
        if path.is_dir() and not path.is_symlink():
            shutil.rmtree(path)
        else:
            path.unlink()
