"""argparse entrypoint for `borg next`. Registry JSON on stdin; exit 0 always.

Log mode (default) appends one row and NEVER writes stdout. `--rows` prints the chooser screen instead: the
rendered lines, then one final `names` line (tab-separated ranked repository names in row order) for the zsh side.
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import UTC, datetime
from typing import Any

from borg_core.compass import shell as compass_shell
from borg_core.nextpick import core, shell


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="borg_core.nextpick.cli", add_help=False)
    parser.add_argument("--switch", action="store_true")
    parser.add_argument("--pick", type=int, default=None)
    parser.add_argument("--top", type=int, default=None)
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


def read_compass(repositories: dict[str, Any]) -> dict[str, Any] | None:
    """The compass block ranking reads, or None when it cannot be had. Fail-open: ranking must never need a map.

    The reader (`borg_core.compass.shell`) forks nothing and never raises on content; the guard is for the
    environment (an unreadable home, say), and the cost of None is only the order `borg next` always had.
    """
    try:
        return compass_shell.read_compass(int(datetime.now(UTC).timestamp()), list(repositories))
    # JUSTIFICATION: a map is an optional input to an ordering; any failure reading it degrades to no map.
    except Exception:  # pylint: disable=broad-exception-caught
        return None


def build_row(
    args: argparse.Namespace, repositories: dict[str, Any], now: datetime, compass: dict[str, Any] | None = None
) -> dict[str, Any]:
    """Assemble the log row for one invocation."""
    ranked = core.rank(repositories, compass)
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
    repositories: dict[str, Any],
    local: bool,
    show_all: bool = False,
    swept: tuple[dict[str, list[dict[str, Any]]], str | None] | None = None,
    compass: dict[str, Any] | None = None,
) -> tuple[list[dict[str, Any]], list[str], str | None, dict[str, int]]:
    """`(rows, quiet, degraded, hidden)`: work items from the recon sweep, plans, sessions and checkpoints.

    Capped by `core.cap_rows` (at most 5 YOU rows; the rest only counted in `hidden`) unless `show_all`.

    `compass` is the map's block, when the caller has one: it reorders the repositories (`core.rank`) and so the
    rows, and the caller that shows these rows on a page hands in the same block it renders.

    Each source is gathered fail-open (a failed sweep only sets `degraded`). Under `local` the sweep is skipped, so
    only session, plan and checkpoint rows appear.

    `swept` is a sweep the caller ALREADY RAN, as `(items by repository, degraded note)`: `borg link` hands in the one
    its grid performed, so a page that shows these rows never pays a second `gh` round trip for them.
    """
    ranked = core.rank(repositories, compass)
    names = [item["name"] for item in ranked]
    by_repository, degraded = swept if swept is not None else shell.recon_items(repositories, local)
    work, quiet = core.work_items(
        ranked,
        by_repository,
        shell.read_plans(repositories, names),
        shell.checkpoint_next_steps(repositories, names),
        int(datetime.now(UTC).timestamp()),
    )
    shown, hidden = core.cap_rows(work, show_all)
    return core.numbered_rows(shown, ranked), quiet, degraded, hidden


def rows_output(
    repositories: dict[str, Any], local: bool, show_all: bool = False, compass: dict[str, Any] | None = None
) -> list[str]:
    """The chooser screen plus the trailing names line (one repository per ROW, so a key selects a row)."""
    rows, quiet, _degraded, hidden = item_rows(repositories, local, show_all, compass=compass)
    suggestion = core.suggestion_for(rows, shell.read_log_rows())
    lines = core.render_chooser(rows, suggestion=suggestion, quiet=quiet, hidden=hidden)
    return [*lines, NAMES_PREFIX + "\t".join(row["project"] for row in rows)]


def rows_json(
    repositories: dict[str, Any], local: bool, show_all: bool = False, compass: dict[str, Any] | None = None
) -> dict[str, Any]:
    """The `--rows --json` payload: item rows, the first row's repository, the earned suggestion's row number or None.

    `hidden` is `{agent, stale, overflow}`: how many rows the cap left out (all zero under `--all`).
    """
    rows, quiet, degraded, hidden = item_rows(repositories, local, show_all, compass=compass)
    earned = core.suggestion_for(rows, shell.read_log_rows()) is not None
    return {
        "rows": rows,
        "rec": rows[0]["project"] if rows else None,
        "suggestion": rows[0]["n"] if rows and earned else None,
        "quiet": quiet,
        "degraded": degraded,
        "hidden": hidden,
    }


def _rows_json_failopen(
    repositories: dict[str, Any], local: bool, show_all: bool = False, compass: dict[str, Any] | None = None
) -> dict[str, Any]:
    """`rows_json`, degrading to an empty payload that says why; never raises."""
    try:
        return rows_json(repositories, local, show_all, compass)
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


def top_entry(repositories: dict[str, Any], index: int, compass: dict[str, Any] | None = None) -> dict[str, Any] | None:
    """The ranked repository at 0-based `index`, or None when there is no such row."""
    ranked = core.rank(repositories, compass)
    return ranked[index] if 0 <= index < len(ranked) else None


def _top(index: int) -> int:
    """`--top`: print the repository at `index` in the ranked order as one JSON object, nothing when out of range.

    The one place the non-interactive `borg next` (`--switch`, `--pick`, the plain "Next up" screen) asks for its
    choice, so those paths order exactly as the chooser does. Unlike the log mode this EXITS NON-ZERO on a failure:
    the caller falls back to its own pipeline on a crash, and silence would read as "all clear".
    """
    try:
        repositories = json.load(sys.stdin).get("projects") or {}
        entry = top_entry(repositories, index, read_compass(repositories))
    except (ValueError, AttributeError, OSError):
        return 1
    if entry is not None:
        print(json.dumps(entry))
    return 0


def main(argv: list[str] | None = None) -> int:
    """Log one row; swallow every failure. Always returns 0 (except `--top`, see `_top`)."""
    try:
        args, _unknown = _parser().parse_known_args(argv)
        if args.top is not None:
            return _top(args.top)
        if args.rows and args.json:
            try:
                repositories = json.load(sys.stdin).get("projects") or {}
            except (ValueError, AttributeError):
                repositories = {}
            compass = read_compass(repositories)
            print(json.dumps(_rows_json_failopen(repositories, bool(args.local), bool(args.all), compass)))
            return 0
        doc = json.load(sys.stdin)
        repositories = doc.get("projects") or {}
        compass = read_compass(repositories)
        if args.rows:
            print("\n".join(rows_output(repositories, bool(args.local), bool(args.all), compass)))
            return 0
        shell.append_row(build_row(args, repositories, datetime.now(UTC), compass))
    # JUSTIFICATION: a logging side channel must never fail the command it observes; every error is swallowed.
    except (Exception, SystemExit):  # pylint: disable=broad-exception-caught
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
