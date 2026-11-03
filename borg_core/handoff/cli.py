"""`borg handoff write|check`: one PR thread per worker session, enforced where the handoff is written.

    borg handoff write --repository <path> --goal "<owner/repo#N: what>" --done-when "<X>" --next "<thread|none>"
    borg handoff check <file|->

`write` renders the template, lints it and only then writes `<repository>/.borg/checkpoints/<stem>-queen.md`; a goal
that names more than one PR prints the split prompt and writes nothing. `check` lints any handoff file (exit 1 with
the problems on stdout) so a hand-written one can be held to the same rule.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from borg_core.handoff import core, shell


def _parse(argv: list[str] | None) -> argparse.Namespace:
    # JUSTIFICATION: argparse's builder API is a chain by design; the parser is built and discarded here.
    # pylint: disable=clean-arch-demeter
    parser = argparse.ArgumentParser(prog="borg handoff", description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="verb", required=True)
    writer = sub.add_parser("write", help="render, lint and write one handoff checkpoint")
    writer.add_argument("--repository", required=True, help="the repository the worker session will open in")
    writer.add_argument("--goal", required=True, help="the ONE PR thread: its ref and what to do")
    writer.add_argument("--done-when", required=True, help="the stop condition, up to 'then /borg-link-up and end'")
    writer.add_argument("--next", dest="next_thread", required=True, help="the next thread (fresh session), or none")
    writer.add_argument("--waits-on-you", action="append", default=[], help="a thing only the person can do (repeat)")
    checker = sub.add_parser("check", help="lint a handoff file (- for stdin)")
    checker.add_argument("file")
    return parser.parse_args(argv)


def _report(verdict: core.Verdict) -> None:
    for problem in verdict.problems:
        print(f"FAIL: {problem}")


def _write(args: argparse.Namespace) -> int:
    text = core.render(args.goal, args.done_when, args.next_thread, tuple(args.waits_on_you))
    verdict = core.check(text)
    if not verdict.ok:
        _report(verdict)
        print("handoff not written")
        return 1
    path = shell.handoff_path(Path(args.repository).expanduser())
    shell.write(path, text)
    print(f"wrote {path}")
    return 0


def _check(args: argparse.Namespace) -> int:
    try:
        text = shell.read(args.file)
    except OSError as error:
        print(f"FAIL: cannot read {args.file}: {error}")
        return 1
    verdict = core.check(text)
    if verdict.ok:
        print(f"ok: one PR thread ({verdict.refs[0]}), stop condition and next thread present")
        return 0
    _report(verdict)
    return 1


def main(argv: list[str] | None = None) -> int:
    """Entry point."""
    args = _parse(argv)
    return _write(args) if args.verb == "write" else _check(args)


if __name__ == "__main__":
    sys.exit(main())
