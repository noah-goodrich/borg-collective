"""`python3 -m borg_core.evals.cli {check,select}` -- the eval ledger gate and changed-files selector.

  check   exit 1, one stderr line per problem, unless every skill/agent is an eval or an unexpired
          waiver and every eval path exists. `--today` pins the clock for the expiry case.
  select  print, one per line on stdout, the evals whose `covers` match a changed file. The changed
          set is `--files ...` or the git range `--base REF --head REF` (base defaults to the
          merge-base with origin/main, head to HEAD). The reason goes to STDERR so stdout stays a
          clean list; a selection of zero is exit 0 -- "nothing to run" is not a floor violation.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from borg_core.evals import core, shell


def _parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="borg_core.evals.cli")
    # JUSTIFICATION: argparse's builder API is a chain by design
    sub = p.add_subparsers(dest="cmd", required=True)  # pylint: disable=clean-arch-demeter
    # JUSTIFICATION: argparse's builder API is a chain by design
    chk = sub.add_parser("check", help="validate the ledger")  # pylint: disable=clean-arch-demeter
    chk.add_argument("--root", default=".")
    chk.add_argument("--today", default=None, help="YYYY-MM-DD (default: the real date)")
    # JUSTIFICATION: argparse's builder API is a chain by design
    sel = sub.add_parser("select", help="choose evals")  # pylint: disable=clean-arch-demeter
    sel.add_argument("--root", default=".")
    sel.add_argument("--base", default=None)
    sel.add_argument("--head", default="HEAD")
    sel.add_argument("--files", nargs="*", default=None)
    return p


def _check(root: Path, today: str) -> int:
    ledger = shell.load_ledger(root)
    names = list(ledger.get("evals", {}))
    found = core.ledger_problems(ledger, shell.discover_items(root), shell.existing_evals(root, names), today)
    for line in found:
        print(f"eval-ledger: {line}", file=sys.stderr)
    if found:
        print(f"eval-ledger: {len(found)} problem(s)", file=sys.stderr)
        return 1
    print(f"eval-ledger: {len(ledger.get('items', {}))} items, {len(names)} evals, 0 problems")
    return 0


def _select(root: Path, args: argparse.Namespace) -> int:
    ledger = shell.load_ledger(root)
    changed = args.files if args.files is not None else shell.changed_files(root, args.base, args.head)
    chosen = core.select(ledger, changed)
    print(f"eval-select: {chosen.reason}", file=sys.stderr)
    for name in chosen.evals:
        print(name)
    return 0


def main(argv: list[str] | None = None) -> None:
    """Dispatch; an unreadable ledger or git failure is exit 2 with the reason on stderr."""
    args = _parser().parse_args(sys.argv[1:] if argv is None else argv)
    root = Path(args.root)
    try:
        if args.cmd == "check":
            raise SystemExit(_check(root, args.today or shell.today()))
        raise SystemExit(_select(root, args))
    except ValueError as exc:
        print(f"eval-ledger: {exc}", file=sys.stderr)
        raise SystemExit(2) from exc


if __name__ == "__main__":
    main()
