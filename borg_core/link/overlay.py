"""`python3 -m borg_core.link.overlay`: the registry with state.json and the reap overlay applied, as JSON.

THE ONE STATE OVERLAY. `borg link` builds its view with `shell.registry_with_state`; `borg next` used to build
its own with the zsh `borg_registry_with_state` and hand that to nextpick, so the two commands read the same
registry through two readers. This is the seam that ends it: `borg next` pipes THIS output into nextpick, so a
session that `borg link` shows as waiting is a session `borg next` sees as waiting, by construction rather than
by two implementations staying in step. Fail loud: a traceback on stderr and a non-zero exit, never a plausible
empty registry (the zsh caller turns that into a visible `die`).
"""

from __future__ import annotations

import json
import sys

from borg_core.link import shell


def main() -> int:
    """Print the overlaid registry as one JSON document on stdout."""
    print(json.dumps(shell.registry_with_state()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
