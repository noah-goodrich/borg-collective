"""The impure half of the compass reader: find the map directory, read its files, hand the text to core.

FORKS NOTHING. Every read here is `Path.read_text` or a directory listing, so `borg link --local`'s
subprocess contract (tests/link_sweep.bats, test_cli's exact-argv pin) is untouched by this module.

NEVER RAISES. A missing directory is `found: false`; a missing file is an absent argument; a file that cannot
be read (permissions, a directory where a file should be) is a `warnings` entry and is otherwise treated as
absent. The map is the owner's, may be half-written, and must not take `borg link` down.

`today` is derived from the epoch the cli already holds for the whole document, so the leg and the due dates
describe the same instant as `generated_at`. The clock itself is never read here.
"""

from __future__ import annotations

import time
from pathlib import Path

from borg_core import paths
from borg_core.compass import core


MAP_ENTRIES = ("log", "destinations", "README.md", "parking-lot.md")
"""What makes a directory a map. A directory holding none of these (a path that does not exist, a file, a
freshly made empty directory) has no map in it, and the compass says `found: false` rather than reporting a
map that says nothing."""


def today_from_epoch(moment: int) -> str:
    """The local calendar date (YYYY-MM-DD) of an epoch: the day the owner is living in."""
    return time.strftime("%Y-%m-%d", time.localtime(moment))


def _read(path: Path, label: str, warnings: list[str]) -> str | None:
    """The file's text, or None when it does not exist; a file that exists but cannot be read adds a warning."""
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return None
    except OSError as exc:
        warnings.append(f"{label}: unreadable ({exc.strerror or type(exc).__name__})")
        return None


def _destination_files(directory: Path, warnings: list[str]) -> list[tuple[str, str]]:
    """`(destinations/<name>.md, text)` for every markdown file in destinations/, in name order."""
    try:
        names = sorted(entry.name for entry in (directory / "destinations").iterdir() if entry.suffix == ".md")
    except OSError:
        return []
    files: list[tuple[str, str]] = []
    for name in names:
        label = f"destinations/{name}"
        text = _read(directory / "destinations" / name, label, warnings)
        if text is not None:
            files.append((label, text))
    return files


def read_compass(
    moment: int, repository_names: list[str], directory: Path | None = None, parents: dict[str, str] | None = None
) -> dict:
    """The `compass` block: found false when there is no map (see `MAP_ENTRIES`), else everything the map says.

    `directory` defaults to `paths.map_dir()`; the parameter exists so a caller holding a path need not touch
    the environment. `repository_names` are the registry's names, from the document the cli already holds.
    `parents` is `{worktree: repository}` from the registry's `repo` key (`link.worktree.repository_parents`),
    which the caller resolves because only it holds the registry; a worktree then ranks as its repository does.
    """
    root = directory if directory is not None else paths.map_dir()
    if not any((root / name).exists() for name in MAP_ENTRIES):
        return core.absent(str(root))
    today = today_from_epoch(moment)
    warnings: list[str] = []
    log = _read(root / "log" / f"{today}.md", f"log/{today}.md", warnings)
    readme = _read(root / "README.md", "README.md", warnings)
    parking = _read(root / "parking-lot.md", "parking-lot.md", warnings)
    return core.build_compass(
        str(root), today, log, _destination_files(root, warnings), readme, parking, repository_names, warnings, parents
    )
