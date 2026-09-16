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


def repo_root_of(directory: Path) -> Path:
    """The nearest ancestor of `directory` (inclusive) containing `.git`, else `directory`.

    Hoisted here when `borg_core/extensions/shell.py` grew the second copy of this walk; the first
    is `borg_core/planstate/derive.py`. This module's own docstring sets the rule for exactly this
    shape -- two copies tolerated, the third refused by pylint's duplicate-code check -- so the walk
    lives in one place before it becomes three.

    TAKES A DIRECTORY, INCLUSIVE. The two callers differ in what they start from and that difference
    is load-bearing: planstate resolves annotations relative to the repository containing a plan
    FILE, so it passes `path.parent`; extensions resolves a repository from a directory it was
    handed, so it passes that directory itself. Folding `.parent` in here would have silently moved
    the extensions caller one level up and let a repository root resolve to its own parent.

    Falling back to `directory` rather than raising keeps a path outside any repository usable.
    """
    here = directory.resolve()
    for candidate in (here, *here.parents):
        if (candidate / ".git").exists():
            return candidate
    return here


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
