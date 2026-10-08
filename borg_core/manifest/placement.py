"""Where `scaffold` creates a NEW manifest: the pure decision, split from `core.py`.

`core.py` is at pylint's module-length ceiling, and `refs.py` / `across.py` are the precedent for a
pure sibling. No I/O here: `shell.scaffold_root` gathers the facts (directory checks, the git probe).
"""

from __future__ import annotations

ROOT_STACKS = "stacks"
ROOT_BORG = "borg"
ROOT_CHOICES = (ROOT_STACKS, ROOT_BORG)


def choose_scaffold_root(
    override: str,
    stacks_exists: bool,
    borg_dir_exists: bool,
    borg_ignored: bool,
    candidates: tuple[str, str],
) -> tuple[str, str]:
    """`(directory, reason)` for where `scaffold` creates a NEW manifest. Pure: plain facts in, a pair out.

    First match wins:

    1. `override` (`ROOT_STACKS` or `ROOT_BORG`) names the root outright, even beside an existing one.
    2. `.stacks/` already exists -- the repository has already chosen the tool-neutral root.
    3. borg's own directory already exists -- likewise.
    4. Neither exists and git ignores `.borg/`: `.stacks/`, because a manifest under an ignored
       `.borg/` could never be shared.
    5. Otherwise borg's own directory, which is what scaffold did before `.stacks/` existed.

    `candidates` is `(stacks_path, borg_path)`, the two directories a manifest could be created in.
    The facts are gathered by `shell.scaffold_root`; nothing here touches a disk or runs git.
    An `override` that is neither choice falls through to the derived rules -- the CLI rejects it at
    the argparse seam, so reaching here with one is a caller bug that should not become a crash.
    """
    stacks_path, borg_path = candidates
    if override == ROOT_STACKS:
        return stacks_path, "--root stacks"
    if override == ROOT_BORG:
        return borg_path, "--root borg"
    if stacks_exists:
        return stacks_path, ".stacks/ already exists"
    if borg_dir_exists:
        return borg_path, f"{borg_path} already exists"
    if borg_ignored:
        return stacks_path, "git ignores .borg/, so a manifest there could not be shared"
    return borg_path, "default"
