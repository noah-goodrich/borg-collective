"""I/O for checkpoint naming: the clock and the session identity. Nothing else lives here.

Both are ambient, and that is exactly why they are quarantined in this module rather than read
inside `core`. The generator is pure and pinnable; this file is the two lines that cannot be.
"""

from __future__ import annotations

import os
from datetime import datetime

from borg_core.checkpoint import core


def session_id() -> str:
    """This session's id, or "" when it is not discoverable.

    `CLAUDE_CODE_SESSION_ID` is exported into every Claude Code shell, so a Bash-invoked helper
    reads it directly and needs no hook plumbing -- unlike the hooks, which parse `session_id` out
    of the JSON on stdin (`hooks/borg-link-up.sh`). Cortex Code sessions and a bare terminal do not
    set it, and that is a supported state, not an error: the name degrades to second resolution
    alone. "" rather than a raised error, because failing to name a checkpoint would lose the
    document, and losing the document to protect a suffix is the wrong trade.
    """
    return os.environ.get("CLAUDE_CODE_SESSION_ID", "")


def checkpoint_stem() -> str:
    """The stem for a checkpoint written right now, by this session."""
    return core.checkpoint_stem(datetime.now(), core.short_suffix(session_id()))
