"""Config-path resolution shared by every borg_core package.

`borg_dir()` and `registry_path()` existed as byte-identical copies in borg_core/registry/shell.py
and borg_core/recon/shell.py. Two copies were tolerated; the third (borg_core/link/) would not have
been, and pylint's duplicate-code check failed the moment recon grew its own `registry_path`. One
definition lives here, mirroring the single assignment each has on the zsh side:

    BORG_DIR      -- borg.zsh:24,          ${XDG_CONFIG_HOME:-$HOME/.config}/borg
    BORG_REGISTRY -- lib/registry.zsh:15,  $BORG_DIR/registry.json

Both environment variables are OVERRIDES, never requirements. borg.zsh assigns them without
`export`, so a `python3 -m borg_core...` child routinely inherits NEITHER and must be able to derive
both from scratch. `borg recon` shipped without that fallback and died with "no registry at " on
every real invocation; see the _borg_py helper in borg.zsh for the other half of that fix.
"""

from __future__ import annotations

import os
from pathlib import Path


def borg_dir() -> Path:
    """Resolve BORG_DIR, mirroring zsh's `${XDG_CONFIG_HOME:-$HOME/.config}/borg`."""
    if os.environ.get("BORG_DIR"):
        return Path(os.environ["BORG_DIR"])
    xdg = os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config")
    return Path(xdg) / "borg"


def registry_path() -> Path:
    """Path to registry.json, mirroring zsh's `BORG_REGISTRY="$BORG_DIR/registry.json"`."""
    override = os.environ.get("BORG_REGISTRY")
    if override:
        return Path(override)
    return borg_dir() / "registry.json"
