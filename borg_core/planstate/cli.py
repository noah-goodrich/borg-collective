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
_UNKNOWN_MARK = _VERDICT_MARK[core.UNKNOWN]


def _die_json(message: str) -> NoReturn:
    """Fail in `--json` mode: a parseable error object on stdout, nothing on stderr to splice into a
    consumer's `jq`. A machine surface that fails with prose fails SILENTLY, because the caller reads
    an empty document as "no criteria".

    DELIBERATELY DIFFERENT FROM `link/cli.py::_die_json`, which prints prose to stderr: link's
    `--json` consumer is a `jq` pipeline inside a zsh function that already checks the exit status,
    while this one is a skill prompt that reads the payload and has no exit status to consult."""
    print(jsonlib.dumps({"error": message}), file=sys.stdout)
    raise SystemExit(1)


def _die(message: str) -> NoReturn:
    """Fail in human mode: the reason on stderr, non-zero. Nothing on stdout, so a caller that
    redirects stdout into a file does not get half a table plus an error."""
    print(f"planstate: {message}", file=sys.stderr)
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
        lines.append(f"  [{box}] {_VERDICT_MARK.get(row['verdict'], _UNKNOWN_MARK)}  {row['text']}")
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
        print(jsonlib.dumps(report, indent=2, sort_keys=True), file=sys.stdout)
    else:
        print(_human(report, applied), end="", file=sys.stdout)
    try:
        # JUSTIFICATION: this process's own standard stream, not a caller-supplied collaborator.
        sys.stdout.flush()  # pylint: disable=clean-arch-demeter
    except BrokenPipeError:
        # The documented CPython idiom, verbatim from `link/cli.py` -- closing stdout or leaving it
        # alone makes the interpreter print "Exception ignored in: <_io.TextIOWrapper ...>" at
        # shutdown instead, which is the same leak wearing a different hat.
        # JUSTIFICATION: same stream, and this line is the documented CPython idiom verbatim.
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

    A SINGLE exception boundary, formatter chosen by mode -- `_die_json` for `--json` so a consumer
    gets an object rather than prose on stderr. `SystemExit(0)` on success, matching
    `link/cli.py::main`; argparse's own exit 2 leaves before the boundary exists. The
    `raise SystemExit` sits OUTSIDE the `try` rather than inside it, so the broad `except` cannot
    swallow the successful exit -- pylint names that shape W0706 and it is a real bug, not a style.
    """
    args = _build_parser().parse_args(argv)
    fail = _die_json if _mode(args) == "json" else _die
    try:
        exit_code = _run(args)
    # Same breadth and same reason as `link/cli.py::main`: a malformed plan raises from parse or
    # resolve as OSError, ValueError or AttributeError.
    # JUSTIFICATION: a `--json` consumer must get a payload, never an uncaught traceback.
    except Exception as exc:  # pylint: disable=broad-except
        fail(str(exc))
    raise SystemExit(exit_code)


if __name__ == "__main__":
    main()
