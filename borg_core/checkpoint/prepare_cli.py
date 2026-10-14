"""`borg checkpoint-prepare [--session <id>] [--cwd <dir>]` -- print every mechanical input /borg-link-up needs.

One plain-text document on stdout, and EXIT 0 ALWAYS. The consumer is a skill's load-time injection, where any
non-zero exit aborts the whole skill invocation before the model sees it, so every failure -- including a bad
argument and a crash in this module -- is reported as a field of the document, never as an exit code. The format
and its bounds are specified in docs/plans/directives/2026-10-14-link-up-prepare.md and built by `prepare.py`.

Writes nothing, anywhere. Run it as often as you like.
"""

from __future__ import annotations

import argparse
import contextlib
import io
import os
import sys

from borg_core.checkpoint import prepare, prepare_shell


def _parse(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(prog="borg checkpoint-prepare", description=__doc__.splitlines()[0])
    parser.add_argument("--session", default="", help="session id for the checkpoint name (default: the environment)")
    parser.add_argument("--cwd", default="", help="directory to prepare for (default: the current directory)")
    return parser.parse_args(argv)


def _parse_quietly(argv: list[str] | None) -> argparse.Namespace | str:
    """The parsed arguments, or the parser's complaint as a string. argparse's usage text goes nowhere."""
    errors = io.StringIO()
    try:
        with contextlib.redirect_stderr(errors):
            return _parse(argv)
    except SystemExit:
        # JUSTIFICATION: stdlib StringIO/str accessors on a buffer this function just created, not a layer reach.
        lines = errors.getvalue().strip().splitlines()  # pylint: disable=clean-arch-demeter
        return lines[-1] if lines else "unparseable"


def build(argv: list[str] | None = None) -> str:
    """The document for `argv`. Never raises: a failure here is a skeleton document with a fallback STATUS."""
    try:
        args = _parse_quietly(argv)
        if isinstance(args, str):
            return prepare.skeleton(f"bad arguments: {args}")
        return prepare.render(prepare_shell.gather(args.cwd, args.session))
    # JUSTIFICATION: the exit-0-always contract; a crash here must reach the skill as a field, not an exit code.
    except Exception as exc:  # pylint: disable=broad-exception-caught
        return prepare.skeleton(f"internal error: {type(exc).__name__}: {exc}")


def _to_bytes(text: str) -> bytes:
    return text.encode("utf-8", errors="replace")


def main(argv: list[str] | None = None) -> int:
    """Print the document. Returns 0 on every path, including a closed pipe."""
    data = _to_bytes(build(sys.argv[1:] if argv is None else argv))
    try:
        # JUSTIFICATION: the binary half of stdout, so the encoding never depends on the locale; stdlib, not a layer.
        sys.stdout.buffer.write(data)  # pylint: disable=clean-arch-demeter
        # JUSTIFICATION: same stream as the line above.
        sys.stdout.buffer.flush()  # pylint: disable=clean-arch-demeter
    except OSError:
        # The reader went away (BrokenPipeError is an OSError). Python would otherwise print a traceback to stderr
        # at interpreter exit when it flushes the dead pipe.
        with contextlib.suppress(OSError):
            # JUSTIFICATION: stdlib file descriptor of the stream above, not a layer reach.
            stdout_fd = sys.stdout.fileno()  # pylint: disable=clean-arch-demeter
            os.dup2(os.open(os.devnull, os.O_WRONLY), stdout_fd)
    return 0


if __name__ == "__main__":
    sys.exit(main())
