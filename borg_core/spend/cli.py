"""`python3 -m borg_core.spend.cli --session <id>` -- the engine behind `borg spend --session`.

    --session ID           session id or unique prefix (required)
    --since ISO --until ISO  bound on request start time, UTC ISO-8601
    --json                 the report as JSON
    --projects-dir DIR     default $CLAUDE_CONFIG_DIR/projects, else $HOME/.claude/projects
    --cross-check          compare PRs opened with `gh pr list` over the window
Exit 0 ok, 2 usage or discovery error (named on stderr).
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path

from borg_core.spend import core, render, shell
from borg_core.spend.parse import parse_ts


def _parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(prog="borg spend", description="Live cost report for one session.")
    ap.add_argument("--session", required=True)
    ap.add_argument("--since")
    ap.add_argument("--until")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--projects-dir")
    ap.add_argument("--cross-check", action="store_true")
    return ap


def _bound(value: str | None, flag: str) -> datetime | None:
    try:
        return parse_ts(value) if value else None
    except ValueError as exc:
        raise shell.SpendError(f"{flag} is not an ISO-8601 time: {value}") from exc


def _iso(value: datetime | None) -> str:
    return value.strftime("%Y-%m-%dT%H:%M:%SZ") if value else ""


def _jsonable(report: dict) -> dict:
    return {**report, "window": {k: _iso(v) for k, v in report["window"].items()}}


def _run(args: argparse.Namespace) -> int:
    since, until = _bound(args.since, "--since"), _bound(args.until, "--until")
    projects = Path(args.projects_dir) if args.projects_dir else shell.default_projects_dir()
    found, agents = shell.find_session(projects, args.session)
    report = core.build_report(shell.load_session(found, agents), since, until)
    report["session"] = found.stem
    check = None
    if args.cross_check:
        win = _jsonable(report)["window"]
        listed = shell.listed_prs(report["prs"], win["start"], win["end"])
        check = core.cross_check(report["prs"], listed)
    if args.json:
        print(json.dumps({**_jsonable(report), "cross_check": check}, indent=2))
        return 0
    print(render.render(report, found.stem))
    if check is not None:
        print(render.render_cross_check(check))
    return 0


def main(argv: list[str] | None = None) -> int:
    """Entry point."""
    try:
        args = _parser().parse_args(argv)
    except SystemExit as exc:
        return 0 if exc.code in (0, None) else 2
    try:
        return _run(args)
    except shell.SpendError as exc:
        print(f"borg spend: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
