"""How many times HEAD moved forward since a moment: the arrival brief's `since then` fact (`focus.since`).

READ FROM THE GIT DIR'S `logs/HEAD`, NOT BY FORKING GIT, for `shell.read_git_identity`'s reason: `--local`'s fork
count is a pinned contract (docs/agents/commands.md, `cli._grid`'s docstring). It is its own module only because
`shell.py` sits at pylint's 1000-line ceiling; the git-dir lookup is `shell`'s own (`git_dir_of`).
"""

from __future__ import annotations

import os
from pathlib import Path

from borg_core.link import arrival, shell


def read_head_moves(repository_path: str | None, since_epoch: int | None) -> int | None:
    """HEAD moves (commit, merge, pull) after `since_epoch`, or None when that cannot be told.

    None (the brief then states nothing) for a path that is not a directory, a non-git directory, no reflog, or no
    checkpoint to measure from. 0 is a real answer.
    """
    if not repository_path or since_epoch is None or not Path(repository_path).is_dir():
        return None
    git_dir = shell.git_dir_of(os.path.realpath(repository_path))
    reflog = git_dir / "logs" / "HEAD" if git_dir is not None else None
    if reflog is None or not reflog.is_file():
        return None
    try:
        return arrival.count_head_moves(reflog.read_text(encoding="utf-8", errors="replace"), since_epoch)
    except OSError:
        return None
