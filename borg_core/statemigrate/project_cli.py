"""`python3 -m borg_core.statemigrate.project_cli [--dry-run] [--path FILE]...` -- the body of
`borg tidy --migrate-project-state`."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from borg_core import paths
from borg_core.registry import shell as registry_shell
from borg_core.statemigrate import project_core as core
from borg_core.statemigrate import project_shell as shell

_VERB = {core.COPY: "copy     ", core.KEEP_NEW: "keep-new "}


def main(argv: list[str] | None = None) -> None:
    """Exit 0 on success or nothing to do; 1 on a verification failure (legacy kept); 2 on refusal."""
    parser = argparse.ArgumentParser(prog="borg tidy --migrate-project-state")
    parser.add_argument("--dry-run", action="store_true", help="print the plan; touch nothing")
    parser.add_argument(
        "--path", action="append", default=[], metavar="FILE", help="an extra <dir>/.borg/state.json (repeatable)"
    )
    args = parser.parse_args(sys.argv[1:] if argv is None else argv)

    registry = shell.registry_projects(registry_shell.read_registry())
    offenders = core.precondition([p for p, _ in registry])
    if offenders:
        print(
            "migrate-project-state: REFUSED -- git-backed registry entries have no `repo`: "
            + ", ".join(offenders)
            + "\n  run `python3 -m borg_core.registry.cli backfill-repo` first "
            "(keys computed before the backfill would orphan state)",
            file=sys.stderr,
        )
        raise SystemExit(2)

    entries = [shell.observe(Path(path), p.repo) for p, path in registry if path]
    entries += [shell.explicit_entry(f, registry) for f in args.path]
    actions, failures = shell.migrate(entries, paths.state_root(), args.dry_run)

    if not actions:
        print("migrate-project-state: nothing to migrate")
        return
    prefix = "would " if args.dry_run else ""
    for action in actions:
        kept = "" if action.remove_legacy else "  (tracked: legacy kept)"
        print(f"{prefix}{_VERB[action.op]}{action.src}{kept}")
    for reason in failures:
        print(f"migrate-project-state: FAILED {reason} (legacy kept)", file=sys.stderr)
    if failures:
        raise SystemExit(1)
    if not args.dry_run:
        print(f"migrate-project-state: {len(actions)} file(s) migrated (backups in tidy-backups/)")


if __name__ == "__main__":
    main()
