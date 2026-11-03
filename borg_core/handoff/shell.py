"""I/O for `borg handoff`: the clock, the session id and the file write. The rules live in `core`."""

from __future__ import annotations

import sys
from datetime import datetime
from pathlib import Path

from borg_core.checkpoint import shell as checkpoint_shell

SUFFIX = "queen"


def handoff_path(repository: Path) -> Path:
    """`<repository>/.borg/checkpoints/<stem>-queen.md`, advanced to -2, -3 until the name is free.

    The stem is the checkpoint stem (second resolution plus the session tag) so a handoff sorts among the repository's
    checkpoints by name, which is how every reader picks the newest.
    """
    directory = repository / ".borg" / "checkpoints"
    stem = f"{checkpoint_shell.checkpoint_stem(moment=datetime.now())}-{SUFFIX}"
    candidate = directory / f"{stem}.md"
    counter = 2
    while candidate.exists():
        candidate = directory / f"{stem}-{counter}.md"
        counter += 1
    return candidate


def write(path: Path, text: str) -> None:
    """Create the checkpoints directory if needed and write `text`."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def read(source: str) -> str:
    """The text of a file path, or of stdin for `-`."""
    if source == "-":
        return "".join(sys.stdin)
    return Path(source).read_text(encoding="utf-8")
