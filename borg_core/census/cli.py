"""`python3 -m borg_core.census.cli [root]` -- the reader-census gate.

Exit 0 when every referenced `.borg/<name>` declares a reader that exists and mentions it. Exit 1
with one line per violation otherwise. Takes a root so the same gate runs against this repository
and against the fixtures that prove it fires -- a gate only ever run against a passing tree is the
vacuous green this repo keeps paying for.
"""

from __future__ import annotations

import sys
from pathlib import Path

from borg_core.census import core, shell

CENSUS_FILE = Path("docs") / "state-census.md"


def main(argv: list[str] | None = None) -> None:
    """Run the gate against `argv[0]` (default cwd). Exit 1 with one stderr line per violation.

    Violations go to STDERR and the pass line to STDOUT, so a caller can capture the report without
    capturing the success message, and a CI lane shows the failures in the right stream.
    """
    args = sys.argv[1:] if argv is None else argv
    root = Path(args[0]) if args else Path.cwd()

    rows = shell.declared(root / CENSUS_FILE)
    found = core.violations(
        shell.discover(root),
        rows,
        shell.reader_mentions(root, rows),
        shell.reader_exists(root, rows),
    )

    for line in found:
        print(f"census: {line}", file=sys.stderr)
    if found:
        print(f"census: {len(found)} violation(s)", file=sys.stderr)
        raise SystemExit(1)
    print(f"census: {len(rows)} declared, 0 violations")
    raise SystemExit(0)


if __name__ == "__main__":
    main()
