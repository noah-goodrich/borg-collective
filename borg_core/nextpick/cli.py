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
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--unmeasured", action="store_true")
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
    if args.unmeasured:
        return None
    return args.opened_after if args.opened_after is not None else 0


NAMES_PREFIX = "names\t"


def item_rows(
    projects: dict[str, Any], local: bool, show_all: bool = False
) -> tuple[list[dict[str, Any]], list[str], str | None, dict[str, int]]:
    """`(rows, quiet, degraded, hidden)`: work items from the recon sweep, plans, sessions and checkpoints.

    Capped by `core.cap_rows` (at most 5 YOU rows; the rest only counted in `hidden`) unless `show_all`.

    Each source is gathered fail-open (a failed sweep only sets `degraded`). Under `local` the sweep is skipped, so
    only session, plan and checkpoint rows appear.
    """
    ranked = core.rank(projects)
    names = [item["name"] for item in ranked]
    by_project, degraded = shell.recon_items(projects, local)
    work, quiet = core.work_items(
        ranked,
        by_project,
        shell.read_plans(projects, names),
        shell.checkpoint_next_steps(projects, names),
        int(datetime.now(UTC).timestamp()),
    )
    shown, hidden = core.cap_rows(work, show_all)
    return core.numbered_rows(shown, ranked), quiet, degraded, hidden


def rows_output(projects: dict[str, Any], local: bool, show_all: bool = False) -> list[str]:
    """The chooser screen plus the trailing names line (one project per ROW, so a key selects a row)."""
    rows, quiet, _degraded, hidden = item_rows(projects, local, show_all)
    suggestion = core.suggestion_for(rows, shell.read_log_rows())
    lines = core.render_chooser(rows, suggestion=suggestion, quiet=quiet, hidden=hidden)
    return [*lines, NAMES_PREFIX + "\t".join(row["project"] for row in rows)]


def rows_json(projects: dict[str, Any], local: bool, show_all: bool = False) -> dict[str, Any]:
    """The `--rows --json` payload: item rows, the first row's project, the earned suggestion's row number or None.

    `hidden` is `{agent, stale, overflow}`: how many rows the cap left out (all zero under `--all`).
    """
    rows, quiet, degraded, hidden = item_rows(projects, local, show_all)
    earned = core.suggestion_for(rows, shell.read_log_rows()) is not None
    return {
        "rows": rows,
        "rec": rows[0]["project"] if rows else None,
        "suggestion": rows[0]["n"] if rows and earned else None,
        "quiet": quiet,
        "degraded": degraded,
        "hidden": hidden,
    }


def _rows_json_failopen(projects: dict[str, Any], local: bool, show_all: bool = False) -> dict[str, Any]:
    """`rows_json`, degrading to an empty payload that says why; never raises."""
    try:
        return rows_json(projects, local, show_all)
    # JUSTIFICATION: the payload must be valid JSON whatever fails underneath; degrade, do not crash.
    except Exception as exc:  # pylint: disable=broad-exception-caught
        return {
            "rows": [],
            "rec": None,
            "suggestion": None,
            "quiet": [],
            "degraded": f"rows failed: {exc}",
            "hidden": {"agent": 0, "stale": 0, "overflow": 0},
        }


def main(argv: list[str] | None = None) -> int:
    """Log one row; swallow every failure. Always returns 0."""
    try:
        args, _unknown = _parser().parse_known_args(argv)
        if args.rows and args.json:
            try:
                projects = json.load(sys.stdin).get("projects") or {}
            except (ValueError, AttributeError):
                projects = {}
            print(json.dumps(_rows_json_failopen(projects, bool(args.local), bool(args.all))))
            return 0
        doc = json.load(sys.stdin)
        projects = doc.get("projects") or {}
        if args.rows:
            print("\n".join(rows_output(projects, bool(args.local), bool(args.all))))
            return 0
        shell.append_row(build_row(args, projects, datetime.now(UTC)))
    # JUSTIFICATION: a logging side channel must never fail the command it observes; every error is swallowed.
    except (Exception, SystemExit):  # pylint: disable=broad-exception-caught
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
