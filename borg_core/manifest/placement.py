"""Where `scaffold` creates a NEW manifest: the pure decision, split from `core.py`.

`core.py` is at pylint's module-length ceiling, and `refs.py` / `across.py` are the precedent for a
pure sibling. No I/O here: `shell.scaffold_root` gathers the facts (directory checks, the git probes).
"""

from __future__ import annotations

ROOT_STACKS = "stacks"
ROOT_BORG = "borg"
ROOT_CHOICES = (ROOT_STACKS, ROOT_BORG)


class StacksIgnored(ValueError):
    """Scaffold was asked to create in `.stacks/` while git ignores it. Never a silent fallback.

    A ValueError subclass so a caller that already catches ValueError keeps working; the CLI seam
    catches this one by name and prints it as a refusal. The message names the ignore and the way out.
    """


def choose_scaffold_root(
    override: str,
    stacks_exists: bool,
    borg_dir_exists: bool,
    borg_ignored: bool,
    candidates: tuple[str, str],
    stacks_ignored: bool = False,
) -> tuple[str, str]:
    """`(directory, reason)` for where `scaffold` creates a NEW manifest. Pure: plain facts in, a pair out.

    First match wins, and every rule but the `ROOT_BORG` override resolves to `.stacks/`, because
    nothing new may be created under the retiring `.borg/chains` name:

    1. `override` `ROOT_BORG` names borg's own directory outright, even beside an existing `.stacks/`.
       `override` `ROOT_STACKS` names `.stacks/` outright.
    2. `.stacks/` already exists.
    3. borg's own directory already exists -- it is still READ, but a new manifest goes to `.stacks/`.
    4. Neither exists and git ignores `.borg/`.
    5. Otherwise: the default, `.stacks/`.

    `.stacks/` is always version-controlled, so when the answer is `.stacks/` and `stacks_ignored`
    says git would ignore a file there, this raises `StacksIgnored` instead of creating into an
    ignored path. `ROOT_BORG` is the one way past it, since the caller then asked for the other root.

    `candidates` is `(stacks_path, borg_path)`, the two directories a manifest could be created in.
    The facts are gathered by `shell.scaffold_root`; nothing here touches a disk or runs git.
    An `override` that is neither choice falls through to the derived rules -- the CLI rejects it at
    the argparse seam, so reaching here with one is a caller bug that should not become a crash.
    """
    stacks_path, borg_path = candidates
    if override == ROOT_BORG:
        return borg_path, "--root borg"
    if stacks_ignored:
        raise StacksIgnored(
            f"git ignores {stacks_path}, and .stacks/ is always version-controlled, so scaffold will not "
            f"create a manifest there. Remove the ignore rule, or pass --root borg to create in {borg_path}"
        )
    if override == ROOT_STACKS:
        return stacks_path, "--root stacks"
    if stacks_exists:
        return stacks_path, ".stacks/ already exists"
    if borg_dir_exists:
        return stacks_path, f"{borg_path} exists and is still read, but new manifests go in .stacks/"
    if borg_ignored:
        return stacks_path, "git ignores .borg/, so a manifest there could not be shared"
    return stacks_path, "default"
