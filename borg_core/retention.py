"""Log retention for append-only files in the state root.

Siblings: `_borg_rotate_log` in lib/borg-hooks.sh. Same contract, one definition per language.

Policy: when a log reaches ``LOG_CAP_BYTES`` it is renamed to ``<file>.1`` (replacing any older
``.1``) and the writer carries on with a fresh file. ONE previous generation -- the fewest moving
parts that still bounds disk at ``2 * cap``. 1 MiB holds months of history at the current write
rates of every log in the state root, so a reader that spans ``.1`` then the live file loses nothing
it uses. Rotation is fail-open: it never raises.
"""

from __future__ import annotations

import os
from collections.abc import Iterator
from pathlib import Path

LOG_CAP_BYTES = 1024 * 1024


def rotate_log(path: Path | str, cap: int = LOG_CAP_BYTES) -> bool:
    """Rename ``path`` to ``path.1`` when it is at or over ``cap`` bytes. Returns True if rotated.

    Call immediately before appending. Missing files, symlinks and any OSError are a no-op.
    """
    p = Path(path)
    try:
        if p.is_symlink() or not p.is_file() or p.stat().st_size < cap:
            return False
        os.replace(p, p.with_name(p.name + ".1"))
        return True
    except OSError:
        return False


def read_generations(path: Path | str) -> Iterator[str]:
    """Yield lines oldest-first: ``<path>.1`` then ``<path>``. Absent generations are skipped."""
    p = Path(path)
    for f in (p.with_name(p.name + ".1"), p):
        try:
            with f.open(encoding="utf-8", errors="replace") as fh:
                yield from fh
        except OSError:
            continue
