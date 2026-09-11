"""stdlib argparse CLI entrypoint for the plan-state deriver: `python3 -m borg_core.planstate.cli`.

TWO MODES, and `--json` IS THE DEFAULT-ADJACENT ONE ON PURPOSE. `--json` derives and reports what
WOULD change and writes nothing; `--apply` derives and then flips. `--json` must work standalone
because it is what the `/borg-link-up` skill calls -- a derive that could only be reached by
also writing would make "show me the proposal" impossible.

Mirrors `borg_core/link/cli.py`'s shape: `_build_parser` / `_mode` / one `_run` / a single exception
boundary in `main()` whose formatter is chosen by mode, and the same BrokenPipeError idiom, because
the human table is piped into `head` by anything reading it interactively.

`--apply` IMPLIES the derive and reports it too, so a caller that wants both does not pay for two
sweeps and two suite runs -- and cannot be handed a proposal that disagrees with what was written,
which is the "two truth levels inside one invocation" failure `_borg_print_briefing` records.
"""

from __future__ import annotations

import argparse
import json as jsonlib
import os
import sys
from pathlib import Path
from typing import NoReturn

from borg_core.planstate import core, derive as derive_mod

_VERDICT_MARK = {core.PASS: "PASS", core.FAIL: "FAIL", core.UNKNOWN: "????"}


def _die_json(message: str) -> NoReturn:
    """Fail in `--json` mode: a parseable error object on stdout, nothing on stderr to splice into a
    consumer's `jq`. Mirrors `link/cli.py::_die_json` -- a machine surface that fails with prose is a
    machine surface that fails silently, because `jq` prints nothing useful and the caller reads an
    empty document as "no criteria"."""
    sys.stdout.write(jsonlib.dumps({"error": message}) + "\n")
    raise SystemExit(1)


def _die(message: str) -> NoReturn:
    """Fail in human mode: the reason on stderr, non-zero. Nothing on stdout, so a caller that
    redirects stdout into a file does not get half a table plus an error."""
    sys.stderr.write(f"planstate: {message}\n")
    raise SystemExit(1)


def _human(report: dict, applied: int | None) -> str:
    """The human table. One line per criterion with its verdict, its text and its evidence line.

    THE EVIDENCE LINE IS ALWAYS PRINTED, including for `unknown`, because the reason a criterion was
    NOT flipped is the entire value of the report to a person -- "12 unknown" with no reasons is the
    stale-box problem restated in a terminal. This is also what the skill lifts into §3 of the checkpoint.
    """
    lines = [f"{report['file']}  ({report['counts']['total']} criteria)"]
    for row in report["criteria"]:
        box = "x" if row["checked"] else " "
        lines.append(f"  [{box}] {_VERDICT_MARK.get(row['verdict'], '????')}  {row['text']}")
        lines.append(f"        {row['evidence']}")
    counts = report["counts"]
    lines.append(
        f"  {counts[core.PASS]} pass / {counts[core.FAIL]} fail / {counts[core.UNKNOWN]} unknown"
        f" -- {counts['would_flip']} would flip"
    )
    for warning in report["fetch"]["warnings"]:
        lines.append(f"  ! {warning}")
    if applied is not None:
        lines.append(f"  applied: {applied} box(es) flipped")
    return "\n".join(lines) + "\n"


def _run(args: argparse.Namespace) -> int:
    """Derive, optionally apply, and print. The one place both modes meet."""
    path = Path(args.plan)
    root = Path(args.root) if args.root else None
    report = derive_mod.derive(path, root)
    applied = None
    if args.apply:
        applied = derive_mod.apply(path, report)
        report["applied"] = applied
    if args.json_only:
        sys.stdout.write(jsonlib.dumps(report, indent=2, sort_keys=True) + "\n")
    else:
        sys.stdout.write(_human(report, applied))
    try:
        sys.stdout.flush()
    except BrokenPipeError:
        # The documented CPython idiom, verbatim from `link/cli.py` -- closing stdout or leaving it
        # alone makes the interpreter print "Exception ignored in: <_io.TextIOWrapper ...>" at
        # shutdown instead, which is the same leak wearing a different hat.
        os.dup2(os.open(os.devnull, os.O_WRONLY), sys.stdout.fileno())  # pylint: disable=clean-arch-demeter
    return 0


def _build_parser() -> argparse.ArgumentParser:
    """The flag surface. Deliberately tiny: a plan path, the two modes, and an explicit `--root`.

    `--root` EXISTS FOR THE TESTS AND FOR A WORKTREE. `derive.repo_root` walks up for `.git`, which
    is right for every real invocation and wrong for a fixture plan in a tmpdir -- and a fixture that
    silently resolved its `path:` annotations against THIS repository would be the
    `reference_test_supplies_derived_value` shape wearing a filesystem: the test would pass because
    of files it never created.
    """
    parser = argparse.ArgumentParser(prog="borg-planstate", description="Derive plan-state from evidence annotations")
    parser.add_argument("plan")
    parser.add_argument("--json", dest="json_only", action="store_true")
    parser.add_argument("--apply", dest="apply", action="store_true")
    parser.add_argument("--root", dest="root", default="")
    return parser


def _mode(args: argparse.Namespace) -> str:
    """`json` or `human`. `--apply` is NOT a mode -- it is an action either mode can take, which is
    why `--json --apply` is legal and reports exactly what it wrote."""
    return "json" if args.json_only else "human"


def main(argv: list[str] | None = None) -> None:
    """Entrypoint for `python3 -m borg_core.planstate.cli`.

    A SINGLE exception boundary, formatter chosen by mode -- `_die_json` for `--json` so a consumer's
    `jq` gets an object rather than prose on stderr. `SystemExit` is re-raised untouched so argparse's
    own exit 2 and `_die`'s exit 1 pass through unmolested.
    """
    args = _build_parser().parse_args(argv)
    fail = _die_json if _mode(args) == "json" else _die
    try:
        raise SystemExit(_run(args))
    except SystemExit:
        raise
    except (OSError, ValueError) as exc:
        fail(str(exc))


if __name__ == "__main__":
    main()
