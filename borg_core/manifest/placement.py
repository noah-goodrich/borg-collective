"""Where `scaffold` creates a NEW manifest: the pure decision, split from `core.py`.

`core.py` is at pylint's module-length ceiling, and `refs.py` / `across.py` are the precedent for a
pure sibling. No I/O here: `shell.scaffold_root` gathers the facts (the `.stacks/` directory check, the git probe).

Since step (c) of the chain -> stack rename there is ONE manifest root, `.stacks/`, so the decision is no longer
a choice between roots: it is whether `.stacks/` may be created at all.
"""

from __future__ import annotations

ROOT_STACKS = "stacks"
ROOT_CHOICES = (ROOT_STACKS,)

# `--root borg` named borg's own directory (`.borg/chains`), which is no longer a manifest root. The flag value is
# still PARSED so the refusal can name it, rather than argparse's anonymous "invalid choice" exit 2.
ROOT_BORG = "borg"
BORG_ROOT_REFUSAL = (
    "--root borg is no longer accepted: borg's own directory (.borg/chains) is not a manifest root any more, "
    "and manifests live in .stacks/. Drop the flag to scaffold into .stacks/; "
    "`borg stack migrate` moves manifests that are still under .borg/chains"
)


class StacksIgnored(ValueError):
    """Scaffold was asked to create in `.stacks/` while git ignores it. Never a silent fallback.

    A ValueError subclass so a caller that already catches ValueError keeps working; the CLI seam
    catches this one by name and prints it as a refusal. The message names the ignore and the way out.
    """


def choose_scaffold_root(
    override: str, stacks_exists: bool, stacks_path: str, stacks_ignored: bool = False
) -> tuple[str, str]:
    """`(directory, reason)` for where `scaffold` creates a NEW manifest. Pure: plain facts in, a pair out.

    The directory is always `stacks_path` (`.stacks/`); what varies is the reason, and whether the answer is a
    refusal. First match wins:

    1. `stacks_ignored`: git would ignore a file there, and `.stacks/` is always version-controlled, so this raises
       `StacksIgnored` instead of creating into an ignored path. There is no other root to fall back to.
    2. `override` `ROOT_STACKS` names `.stacks/` outright.
    3. `.stacks/` already exists.
    4. Otherwise: the default.

    The facts are gathered by `shell.scaffold_root`; nothing here touches a disk or runs git. `--root borg` never
    reaches here: the CLI seam refuses it by name first (`BORG_ROOT_REFUSAL`).
    """
    if stacks_ignored:
        raise StacksIgnored(
            f"git ignores {stacks_path}, and .stacks/ is always version-controlled, so scaffold will not "
            "create a manifest there. Remove the ignore rule"
        )
    if override == ROOT_STACKS:
        return stacks_path, "--root stacks"
    if stacks_exists:
        return stacks_path, ".stacks/ already exists"
    return stacks_path, "default"
