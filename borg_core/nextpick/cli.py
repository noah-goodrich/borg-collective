"""argparse entrypoint for `borg next`. Registry JSON on stdin; exit 0 always.

Log mode (default) appends one row and NEVER writes stdout. `--rows` prints the chooser screen instead: the
rendered lines, then one final `names` line (tab-separated ranked project names in row order) for the zsh side.
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import UTC, datetime
from typing import Any

from borg_core.nextpick import core, shell


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="borg_core.nextpick.cli", add_help=False)
    parser.add_argument("--switch", action="store_true")
    parser.add_argument("--pick", type=int, default=None)
    parser.add_argument("--chooser", action="store_true")
    parser.add_argument("--scripted", action="store_true")
    parser.add_argument("--active", default="")
    parser.add_argument("--session", default="")
    parser.add_argument("--rows", action="store_true")
    parser.add_argument("--local", action="store_true")
    parser.add_argument("--shown", action="store_true")
    parser.add_argument("--opened", default="")
    parser.add_argument("--opened-after", type=float, default=None)
    return parser


def build_row(args: argparse.Namespace, projects: dict[str, Any], now: datetime) -> dict[str, Any]:
    """Assemble the log row for one invocation."""
    ranked = core.rank(projects)
    chooser = bool(args.chooser or args.pick is not None)
    rec = ranked[0]["name"] if ranked else None
    opened = None
    if args.pick is not None and 1 <= args.pick <= len(ranked):
        opened = ranked[args.pick - 1]["name"]
    if args.opened:
        opened = args.opened
    return core.log_row(
        ts=now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        session=args.session,
        ranked=ranked,
        rec=rec,
        opened=opened,
        opened_after_s=_opened_after(args, opened),
        active=args.active or None,
        switch=bool(args.switch),
        chooser=chooser,
        scripted=bool(args.scripted or args.pick is not None),
        shown=bool(args.shown),
    )


def _opened_after(args: argparse.Namespace, opened: str | None) -> float | None:
    if opened is None:
        return None
    return args.opened_after if args.opened_after is not None else 0


NAMES_PREFIX = "names\t"


def rows_output(projects: dict[str, Any], local: bool) -> list[str]:
    """The chooser screen plus the trailing names line. A failed link build yields blank cells, never an error."""
    ranked = core.rank(projects)
    rows = core.chooser_rows(ranked, shell.link_document(local))
    suggestion = core.suggestion_for(rows, shell.read_log_rows())
    lines = core.render_chooser(rows, suggestion=suggestion)
    return [*lines, NAMES_PREFIX + "\t".join(row["project"] for row in rows)]


def main(argv: list[str] | None = None) -> int:
    """Log one row; swallow every failure. Always returns 0."""
    try:
        args, _unknown = _parser().parse_known_args(argv)
        doc = json.load(sys.stdin)
        projects = doc.get("projects") or {}
        if args.rows:
            print("\n".join(rows_output(projects, bool(args.local))))
            return 0
        shell.append_row(build_row(args, projects, datetime.now(UTC)))
    # JUSTIFICATION: a logging side channel must never fail the command it observes; every error is swallowed.
    except (Exception, SystemExit):  # pylint: disable=broad-exception-caught
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
