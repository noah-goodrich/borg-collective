"""`python3 -m borg_core.manifest.migrate_cli [--dry-run] [<repository>]` -- the body of `borg stack migrate`.

Moves every manifest from a repository's `.borg/chains/` (and the legacy `.borg/programs/`) into `.stacks/`,
which is always version-controlled. Never commits. The decision is `migrate.plan_repository`; this module
resolves which repositories to look at, prints, and turns the plans into an exit status.

`<repository>` is a registry name, or failing that an existing directory (a worktree is a directory the
registry may not hold, and `migrate` does not chase worktrees: each directory is migrated on its own).
With none, every registered repository is migrated.

Exit 0 when nothing was skipped or refused and nothing failed; 1 otherwise; 2 for a repository that cannot
be resolved. The registry is READ and never created: this command writes nothing on a `--dry-run`.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from typing import Any

from borg_core import paths
from borg_core.manifest import migrate, migrate_shell


def _read_registry() -> tuple[Any, str]:
    """`(registry, problem)`. Unlike `registry.shell.read_registry`, never creates the file."""
    path = paths.registry_path()
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle), ""
    except FileNotFoundError:
        return None, f"no registry at {path} -- run 'borg add <path>' first"
    except (OSError, ValueError) as exc:
        return None, f"registry at {path} is unreadable ({exc})"


def _named_directory(registry: Any, name: str) -> str:
    """The directory `name` stands for: its registry path, else `name` itself when it is a directory, else ""."""
    entries = registry.get("projects") if isinstance(registry, dict) else None
    entry = entries.get(name) if isinstance(entries, dict) else None
    registered = str(entry.get("path") or "") if isinstance(entry, dict) else ""
    if registered and registered != "null":
        return registered
    return os.path.abspath(name) if os.path.isdir(name) else ""


def _targets(repository: str) -> tuple[list[str], int]:
    """`(directories, exit_code)`: what to migrate. A non-zero code means the arguments resolved to nothing."""
    registry, problem = _read_registry()
    if repository:
        target = _named_directory(registry, repository)
        if not target:
            print(
                f"stack migrate: no repository named '{repository}' in the registry, and no such directory",
                file=sys.stderr,
            )
            return [], 2
        return [target], 0
    if problem:
        print(f"stack migrate: {problem}", file=sys.stderr)
        return [], 1
    directories, warnings = migrate_shell.registered_directories(registry)
    for warning in warnings:
        print(f"stack migrate: {warning}", file=sys.stderr)
    if not directories:
        print("stack migrate: the registry has no repository paths -- run 'borg add <path>' first", file=sys.stderr)
        return [], 1
    return directories, 0


def main(argv: list[str] | None = None) -> int:
    """Plan, print, and (unless `--dry-run`) execute. Returns the exit status."""
    parser = argparse.ArgumentParser(prog="borg stack migrate", description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true", help="print the plan; touch nothing")
    parser.add_argument(
        "repository", nargs="?", default="", help="a registry name or a directory; default: every registered repository"
    )
    args = parser.parse_args(sys.argv[1:] if argv is None else argv)

    directories, code = _targets(args.repository)
    if code:
        return code
    results = migrate_shell.run(directories, args.dry_run)
    for plan, failure in results:
        if failure:
            print(f"failed: {plan.path}: {failure}")
        else:
            print("\n".join(migrate.render(plan, args.dry_run)))
    plans = [plan for plan, failure in results if not failure]
    print(migrate.summary(plans, args.dry_run))
    failed = sum(1 for _, failure in results if failure)
    left = len(migrate.incomplete(plans))
    if left:
        print(
            f"stack migrate: {left} repository(ies) were skipped or refused and left untouched (see above)",
            file=sys.stderr,
        )
    if failed:
        print(f"stack migrate: {failed} repository(ies) failed part-way (see above)", file=sys.stderr)
    return 1 if left or failed else 0


if __name__ == "__main__":  # pragma: no cover - module entry point
    sys.exit(main())
