"""`python3 -m borg_core.statemigrate.cli [--dry-run]` -- the body of `borg tidy --migrate-state`."""

from __future__ import annotations

import argparse
import sys

from borg_core import paths
from borg_core.statemigrate import shell

_VERB = {"move": "move     ", "append": "append   ", "keep-new": "keep-new "}


def main(argv: list[str] | None = None) -> None:
    """Exit 0 on success or nothing to do; 1 when any file failed verification (its old copy kept)."""
    parser = argparse.ArgumentParser(prog="borg tidy --migrate-state")
    parser.add_argument("--dry-run", action="store_true", help="print the plan; touch nothing")
    args = parser.parse_args(sys.argv[1:] if argv is None else argv)

    old_root, new_root = paths.borg_dir(), paths.state_root()
    actions, failures = shell.migrate(old_root, new_root, args.dry_run)

    if not actions:
        print("migrate-state: nothing to migrate")
        return
    prefix = "would " if args.dry_run else ""
    for action in actions:
        print(f"{prefix}{_VERB[action.op]}{action.rel}")
    for reason in failures:
        print(f"migrate-state: FAILED {reason} (old copy kept)", file=sys.stderr)
    if failures:
        raise SystemExit(1)
    if not args.dry_run:
        print(f"migrate-state: {len(actions)} file(s) migrated to {new_root} (backups in tidy-backups/)")


if __name__ == "__main__":
    main()
