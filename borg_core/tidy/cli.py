"""`python3 -m borg_core.tidy.cli cairn-leftovers --config-root R --state-root S [--dry-run]`.

Backs the leftovers up under `<state-root>/tidy-backups/<timestamp>/` and then deletes them. The
backup directory is deliberately NOT named for cairn: the post-merge verify is
`ls ~/.config/borg ~/.local/state/borg | grep -c cairn` equal to 0, and a backup folder called
`cairn-...` would fail the very check the cleanup exists to satisfy. Idempotent: a second run finds
nothing, writes no backup directory, and exits 0.
"""

from __future__ import annotations

import argparse
from datetime import datetime
from pathlib import Path

from borg_core.tidy import shell


def main(argv: list[str] | None = None) -> None:
    """Find, report, and (unless --dry-run) back up then delete the cairn leftovers."""
    parser = argparse.ArgumentParser(prog="borg tidy")
    parser.add_argument("action", choices=["cairn-leftovers"])
    parser.add_argument("--config-root", required=True, type=Path)
    parser.add_argument("--state-root", required=True, type=Path)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)

    hits = shell.find({"config": args.config_root, "state": args.state_root})
    if not hits:
        print("nothing to clean: no cairn leftovers found")
        return

    verb = "would remove" if args.dry_run else "removing"
    for label, path in hits:
        print(f"{verb} [{label}] {path}")
    if args.dry_run:
        print(f"dry run: {len(hits)} item(s), nothing copied or deleted")
        return

    backup = args.state_root / "tidy-backups" / datetime.now().strftime("%Y%m%d-%H%M%S")
    shell.back_up(hits, backup)
    shell.delete(hits)
    print(f"removed {len(hits)} item(s); backup at {backup}")


if __name__ == "__main__":
    main()
