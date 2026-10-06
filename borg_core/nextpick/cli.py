"""argparse entrypoint that logs one `borg next` row. Registry JSON on stdin; NEVER writes stdout; exit 0 always.

PR 1 of the chooser plan: nothing is ever shown, so `shown` is False and `rec` is the top-ranked project.
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
    return parser


def build_row(args: argparse.Namespace, projects: dict[str, Any], now: datetime) -> dict[str, Any]:
    """Assemble the log row for one invocation."""
    ranked = core.rank(projects)
    chooser = bool(args.chooser or args.pick is not None)
    rec = ranked[0]["name"] if ranked else None
    opened = None
    if args.pick is not None and 1 <= args.pick <= len(ranked):
        opened = ranked[args.pick - 1]["name"]
    return core.log_row(
        ts=now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        session=args.session,
        ranked=ranked,
        rec=rec,
        opened=opened,
        opened_after_s=0 if opened is not None else None,
        active=args.active or None,
        switch=bool(args.switch),
        chooser=chooser,
        scripted=bool(args.scripted or args.pick is not None),
    )


def main(argv: list[str] | None = None) -> int:
    """Log one row; swallow every failure. Always returns 0."""
    try:
        args, _unknown = _parser().parse_known_args(argv)
        doc = json.load(sys.stdin)
        projects = doc.get("projects") or {}
        shell.append_row(build_row(args, projects, datetime.now(UTC)))
    # JUSTIFICATION: a logging side channel must never fail the command it observes; every error is swallowed.
    except (Exception, SystemExit):  # pylint: disable=broad-exception-caught
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
