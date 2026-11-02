"""Eval run history, the I/O half (pure logic: borg_core/evals/runstats.py): one JSONL record per live eval case.

The report over them is plan AC1, "recorded".

A live eval costs money and its verdict is a sample, not a fact, so a single green run says little. This module
keeps every live run so a later reader can see a pass RATE with its uncertainty, and how it moved from build to
build. It is stdlib only. The shell harnesses never compute anything: they call `--record` and this module reads
cost, turns, tokens and the model id out of the stream-json `result` / `system/init` events the harness already
captured. Nothing is estimated.

STORE (machine-local data, never committed)::

    ${BORG_EVAL_HISTORY:-$XDG_STATE_HOME/borg/evals/history.jsonl}     (default ~/.local/state/borg/evals/history.jsonl)

`BORG_EVAL_HISTORY` is an override so tests and sandboxes never touch the real file. Readers: `--report` below
(and step 1c's weekly sweep, which calls `append`/`read_records`). The key of a record is (harness, case, git_sha, ts).

RECORD SCHEMA, one JSON object per line::

    ts             ISO-8601 UTC, second resolution
    harness        directory name under evals/, e.g. "lifecycle-manifests"
    case           the case id within that harness, e.g. "P1"
    git_sha        the build under review (`git rev-parse HEAD` of the checkout), or null
    model          the model id(s) the run REPORTED (modelUsage keys, else init `model`), or null
    cost_usd       result.total_cost_usd, or null
    turns          result.num_turns, or null
    input_tokens   result.usage.input_tokens (else summed modelUsage inputTokens), or null
    output_tokens  likewise
    cache_read_tokens, cache_creation_tokens   likewise, or null
    verdict        "pass" | "fail" | "skip" | "error"
    reason         why, for skip and error (a run that could not pass must say so), else ""

A skip or error is COUNTED AND SHOWN by the report but excluded from the pass rate: it is not evidence either way.

CLI::

    python3 -m borg_core.evals.history --record --harness H --case C --verdict V [--reason R]
                                       [--result FILE] [--repo DIR] [--sha SHA] [--path FILE]
    python3 -m borg_core.evals.history --report [--path FILE]

`--result FILE` is a `claude -p --output-format json` result object or a stream-json file (one event per line).
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from borg_core.evals.runstats import VERDICTS, make_record, parse_lines, report
from borg_core.paths import state_root


def history_path() -> Path:
    """The store: `$BORG_EVAL_HISTORY`, else `<state root>/evals/history.jsonl`."""
    override = os.environ.get("BORG_EVAL_HISTORY")
    return Path(override) if override else state_root() / "evals" / "history.jsonl"


def append(record: dict[str, Any], path: Path | str | None = None) -> None:
    """Append one record as one JSON line. Creates the directory; raises ValueError on a bad verdict."""
    if record.get("verdict") not in VERDICTS:
        raise ValueError(f"verdict must be one of {VERDICTS}, got {record.get('verdict')!r}")
    target = Path(path) if path else history_path()
    target.parent.mkdir(parents=True, exist_ok=True)
    line = json.dumps(record, sort_keys=True, separators=(",", ":")) + "\n"
    with open(target, "a", encoding="utf-8") as handle:
        handle.write(line)


def read_records(path: Path | str | None = None) -> tuple[list[dict[str, Any]], int]:
    """(valid records in time order, count of malformed lines skipped). A missing file is ([], 0)."""
    target = Path(path) if path else history_path()
    if not target.is_file():
        return [], 0
    return parse_lines(target.read_text(encoding="utf-8", errors="replace"))


def _git_sha(repo: str | None) -> str | None:
    try:
        proc = subprocess.run(
            ["git", "-C", repo or ".", "rev-parse", "HEAD"], capture_output=True, text=True, check=False
        )
    except OSError:
        return None
    return proc.stdout.strip() or None if proc.returncode == 0 else None


def _parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="borg_core.evals.history", description=__doc__.splitlines()[0])
    # JUSTIFICATION: argparse's builder API is a chain by design
    mode = p.add_mutually_exclusive_group(required=True)  # pylint: disable=clean-arch-demeter
    mode.add_argument("--record", action="store_true", help="append one record")
    mode.add_argument("--report", action="store_true", help="print intervals and per-SHA trends")
    p.add_argument("--harness")
    p.add_argument("--case")
    p.add_argument("--verdict", choices=VERDICTS)
    p.add_argument("--reason", default="")
    p.add_argument("--result", help="captured claude result JSON or stream-json file")
    p.add_argument("--repo", help="checkout whose HEAD is the build under review (default: cwd)")
    p.add_argument("--sha", help="override the git sha")
    p.add_argument("--path", help="history file (default: $BORG_EVAL_HISTORY or the state root)")
    return p


def main(argv: list[str] | None = None) -> int:
    """CLI entry. `--report` never fails on a bad line; `--record` exits 2 on a malformed request."""
    args = _parser().parse_args(argv)
    if args.report:
        records, bad = read_records(args.path)
        for line in report(records):
            print(line)
        if bad:
            print(f"history: skipped {bad} malformed line(s)", file=sys.stderr)
        return 0
    if not (args.harness and args.case and args.verdict):
        print("--record needs --harness, --case and --verdict", file=sys.stderr)
        return 2
    text = ""
    if args.result:
        try:
            text = Path(args.result).read_text(encoding="utf-8", errors="replace")
        except OSError:
            text = ""
    append(
        make_record(
            args.harness,
            args.case,
            args.verdict,
            reason=args.reason,
            git_sha=args.sha or _git_sha(args.repo),
            result_text=text,
            ts=datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        ),
        args.path,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
