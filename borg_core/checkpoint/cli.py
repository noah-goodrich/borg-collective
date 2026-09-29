"""`borg checkpoint-name` -- print the filename stem a new checkpoint should use.

Prints ONE line and nothing else, because its consumer is a skill that substitutes the literal
stdout into a path. No flags: there is exactly one question to ask, and the ambient inputs are the
answer. Any future option would be a second way to name a checkpoint, which is how two writers of
one convention come to disagree.
"""

from __future__ import annotations

from borg_core.checkpoint import shell


def main() -> None:
    """Print the stem. Never non-zero: an unnamed checkpoint is a lost checkpoint."""
    print(shell.checkpoint_stem())


if __name__ == "__main__":
    main()
