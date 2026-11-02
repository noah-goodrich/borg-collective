"""Eval run history: one JSONL record per live eval case, and the report over them (plan AC1, "recorded").

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
import datetime
import json
import math
import os
import subprocess
import sys
from pathlib import Path
from typing import Any

from borg_core.paths import state_root

VERDICTS = ("pass", "fail", "skip", "error")
Z95 = 1.959963984540054
_TOKEN_FIELDS = (
    ("input_tokens", "input_tokens", "inputTokens"),
    ("output_tokens", "output_tokens", "outputTokens"),
    ("cache_read_tokens", "cache_read_input_tokens", "cacheReadInputTokens"),
    ("cache_creation_tokens", "cache_creation_input_tokens", "cacheCreationInputTokens"),
)


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


def _events(text: str) -> list[dict[str, Any]]:
    """Every JSON object in `text`: one whole document, or one per line. Non-JSON lines are ignored."""
    try:
        doc = json.loads(text)
        return [doc] if isinstance(doc, dict) else [e for e in doc if isinstance(e, dict)]
    except (ValueError, TypeError):
        pass
    found = []
    for line in text.splitlines():
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if isinstance(event, dict):
            found.append(event)
    return found


def _sum_usage(model_usage: dict[str, Any], key: str) -> int | None:
    values = [m[key] for m in model_usage.values() if isinstance(m, dict) and isinstance(m.get(key), int)]
    return sum(values) if values else None


def parse_result(text: str) -> dict[str, Any]:
    """Derive model, cost, turns and token counts from captured events. Absent facts stay None."""
    events = _events(text)
    results = [e for e in events if e.get("type") == "result"]
    inits = [e for e in events if e.get("type") == "system" and e.get("subtype") == "init"]
    result = results[-1] if results else {}
    usage = result.get("usage") if isinstance(result.get("usage"), dict) else {}
    model_usage = result.get("modelUsage") if isinstance(result.get("modelUsage"), dict) else {}
    derived: dict[str, Any] = {
        "cost_usd": result.get("total_cost_usd"),
        "turns": result.get("num_turns"),
    }
    for name, usage_key, model_key in _TOKEN_FIELDS:
        value = usage.get(usage_key)
        derived[name] = value if isinstance(value, int) else _sum_usage(model_usage, model_key)
    if model_usage:
        derived["model"] = ",".join(sorted(model_usage))
    else:
        derived["model"] = inits[0].get("model") if inits else None
    return derived


def make_record(
    harness: str,
    case: str,
    verdict: str,
    *,
    reason: str = "",
    git_sha: str | None = None,
    result_text: str = "",
    now: datetime.datetime | None = None,
) -> dict[str, Any]:
    """Build one record. `result_text` is the captured result/stream (empty for a skip: the run never started)."""
    stamp = (now or datetime.datetime.now(datetime.timezone.utc)).strftime("%Y-%m-%dT%H:%M:%SZ")
    record: dict[str, Any] = {"ts": stamp, "harness": harness, "case": case, "git_sha": git_sha}
    record.update(parse_result(result_text))
    record.update({"verdict": verdict, "reason": reason})
    return record


def wilson(passes: int, n: int, z: float = Z95) -> tuple[float, float] | None:
    """Wilson score interval for `passes` of `n`; None when n is 0 (no evidence is not a 0% rate)."""
    if n <= 0:
        return None
    p = passes / n
    denom = 1 + z * z / n
    centre = (p + z * z / (2 * n)) / denom
    half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / denom
    return max(0.0, centre - half), min(1.0, centre + half)


def read_records(path: Path | str | None = None) -> tuple[list[dict[str, Any]], int]:
    """(valid records in time order, count of malformed lines skipped). A missing file is ([], 0)."""
    target = Path(path) if path else history_path()
    if not target.is_file():
        return [], 0
    records, bad = [], 0
    for line in target.read_text(encoding="utf-8", errors="replace").splitlines():
        if not line.strip():
            continue
        try:
            rec = json.loads(line)
        except ValueError:
            bad += 1
            continue
        ok = isinstance(rec, dict) and rec.get("verdict") in VERDICTS
        if ok and all(isinstance(rec.get(k), str) and rec[k] for k in ("harness", "case", "ts")):
            records.append(rec)
        else:
            bad += 1
    records.sort(key=lambda r: r["ts"])
    return records, bad


def summarize(records: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    """Per `harness/case`: counts by verdict, the Wilson interval, and the per-SHA trend in time order."""
    out: dict[str, dict[str, Any]] = {}
    for rec in records:
        row = out.setdefault(
            f"{rec['harness']}/{rec['case']}", {"pass": 0, "fail": 0, "skip": 0, "error": 0, "shas": {}}
        )
        row[rec["verdict"]] += 1
        if rec["verdict"] in ("pass", "fail"):
            sha = (rec.get("git_sha") or "unknown")[:7]
            counted = row["shas"].setdefault(sha, [0, 0])
            counted[0] += rec["verdict"] == "pass"
            counted[1] += 1
    for row in out.values():
        row["n"] = row["pass"] + row["fail"]
        row["interval"] = wilson(row["pass"], row["n"])
    return out


def report(records: list[dict[str, Any]]) -> list[str]:
    """The report lines: one per case, then one trend line per case. Empty input gives no lines."""
    summary = summarize(records)
    lines = []
    for case in sorted(summary):
        row = summary[case]
        span = "n/a" if row["interval"] is None else f"[{row['interval'][0]:.3f}, {row['interval'][1]:.3f}]"
        lines.append(
            f"{case}  n={row['n']} pass={row['pass']} skip={row['skip']} error={row['error']}  wilson95={span}"
        )
    for case in sorted(summary):
        trend = " ".join(f"{sha}:{p}/{n}" for sha, (p, n) in summary[case]["shas"].items())
        if trend:
            lines.append(f"trend {case}  {trend}")
    return lines


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
    mode = p.add_mutually_exclusive_group(required=True)
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
        ),
        args.path,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
