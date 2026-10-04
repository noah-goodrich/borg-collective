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

import hashlib
import os
import subprocess
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


def state_root() -> Path:
    """Resolve the machine-local state root: `${XDG_STATE_HOME:-$HOME/.local/state}/borg`.

    Siblings: lib/state-root.zsh and lib/borg-hooks.sh, both `_borg_state_root`. A blank
    XDG_STATE_HOME is treated as unset, same as the shells' `:-`.
    """
    xdg = os.environ.get("XDG_STATE_HOME") or str(Path.home() / ".local" / "state")
    return Path(xdg) / "borg"


def operational_file(name: str) -> Path:
    """Resolve an operational file for READING: the state root's copy if it exists, else the old
    config-dir location (`borg_dir() / name`).

    Expand phase of the config -> state-root move: readers accept both locations before any writer
    moves. When neither exists the OLD path is returned, so a caller's "absent" handling and its
    error messages are unchanged. Siblings: `_borg_operational_file` in lib/state-root.zsh and
    lib/borg-hooks.sh. Reader-only: writers must not call this.
    """
    new = state_root() / name
    return new if new.exists() else borg_dir() / name


def _digest12(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:12]


FORK_GIT = object()
"""Sentinel for the `repo` argument below: "not supplied, ask git". Distinct from None, which is a
registry entry's null `repo` and means outside git (path-only key)."""


def project_state_key(directory: str | os.PathLike[str], repo: object = FORK_GIT) -> str:
    """The filesystem-safe key naming one project DIRECTORY's machine-local state.

    `<repo12>-<path12>`, or `local-<path12>` outside any git repository, where `path12` is the first
    12 hex of sha256 over the PHYSICAL directory path (symlinks resolved, no trailing slash) and
    `repo12` the same over `git rev-parse --path-format=absolute --git-common-dir`.

    PER DIRECTORY, NAMESPACED BY REPO. Two worktrees of one repo can be in different statuses at
    once (one active, one idle), and today's `<dir>/.borg/state.json` is per directory; keying by
    repo alone would make them overwrite each other. The repo half is the prefix so a repo's
    worktrees sort together and a later step can group them without parsing paths. Hashes, not
    slugs: paths carry spaces and slashes, and a slug of two different paths can collide.

    Siblings, byte-identical output required: `_borg_project_state_key` in lib/borg-hooks.sh and
    lib/state-root.zsh (pinned by tests/project_state.bats).

    `repo` is the fast path for registry-driven readers: pass the registry entry's `repo` field (the
    git common dir `borg add` recorded; None/"" when the entry has none) and no git is forked, so
    `borg link` over N projects costs zero forks instead of N. Left as FORK_GIT it asks git. A null
    `repo` yields the path-only `local-` key, exactly as the resolver does outside git.
    """
    physical = os.path.realpath(os.fspath(directory))
    if repo is FORK_GIT:
        try:
            out = subprocess.run(
                ["git", "-C", physical, "rev-parse", "--path-format=absolute", "--git-common-dir"],
                capture_output=True,
                text=True,
                check=False,
                timeout=10,
            )
            repo = out.stdout.strip() if out.returncode == 0 else ""
        except (OSError, subprocess.SubprocessError):
            repo = ""
    repo_text = repo if isinstance(repo, str) else ""
    return f"{_digest12(repo_text) if repo_text else 'local'}-{_digest12(physical)}"


def project_state_file(directory: str | os.PathLike[str], repo: object = FORK_GIT) -> Path:
    """`<state root>/projects/<key>/state.json` for a project directory. One `git rev-parse` unless
    `repo` is supplied (see `project_state_key`); creates nothing. Siblings: `_borg_project_state_file`
    in lib/borg-hooks.sh and lib/state-root.zsh."""
    return state_root() / "projects" / project_state_key(directory, repo) / "state.json"


def project_state_read_path(directory: str | os.PathLike[str], repo: object = FORK_GIT) -> Path:
    """The state.json to READ for a project: the per-project state-root copy if it exists, else the
    legacy `<dir>/.borg/state.json` (also the answer when neither exists). AC5 expand phase: readers
    accept both before any writer moves. Reader-only. Siblings: `_borg_state_read_path` in
    lib/borg-hooks.sh and `borg_state_read_path` in lib/registry.zsh."""
    new = project_state_file(directory, repo)
    return new if new.is_file() else Path(directory) / ".borg" / "state.json"


def registry_path() -> Path:
    """Path to registry.json, mirroring zsh's `BORG_REGISTRY="$BORG_DIR/registry.json"`."""
    override = os.environ.get("BORG_REGISTRY")
    if override:
        return Path(override)
    return borg_dir() / "registry.json"
