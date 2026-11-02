"""The PURE half of the eval run history: parse a captured result, build a record, Wilson interval, summary, report.

No clock, no filesystem, no environment, no subprocess: callers pass the timestamp and git sha in. I/O lives in
borg_core/evals/history.py. Listed under Domain in pyproject.toml so the import linter covers it; imports are pinned
by an AST walk in test_runstats.py.
"""

from __future__ import annotations

import json
import math
from typing import Any

VERDICTS = ("pass", "fail", "skip", "error")
Z95 = 1.959963984540054
_TOKEN_FIELDS = (
    ("input_tokens", "input_tokens", "inputTokens"),
    ("output_tokens", "output_tokens", "outputTokens"),
    ("cache_read_tokens", "cache_read_input_tokens", "cacheReadInputTokens"),
    ("cache_creation_tokens", "cache_creation_input_tokens", "cacheCreationInputTokens"),
)


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
    usage: dict[str, Any] = result.get("usage") or {}
    model_usage: dict[str, Any] = result.get("modelUsage") or {}
    if not isinstance(usage, dict) or not isinstance(model_usage, dict):
        usage, model_usage = {}, {}
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


PLUGIN_EVAL_SCHEMA = 1


def parse_plugin_eval(text: str) -> tuple[float | None, str]:
    """`(cost_usd, partial_reason)` from a `claude plugin eval` aggregate-result.json. FAIL-SAFE: anything not
    understood is `(None, "")`.

    Documented fields only (code.claude.com/docs/en/plugin-evals.md): `schemaVersion` 1, `costUsd` (one estimate for
    the whole invocation, judge calls included, so nothing is summed) and `partialReason` (`cost_ceiling`,
    `interrupted` or `auth_failed`). Unknown keys are ignored; an unknown schema, a non-object, a non-number or a
    bool cost is None. `partial_reason` is only ever one of the documented strings.
    """
    try:
        doc = json.loads(text)
    except (ValueError, TypeError):
        return None, ""
    if not isinstance(doc, dict) or doc.get("schemaVersion") != PLUGIN_EVAL_SCHEMA:
        return None, ""
    cost = doc.get("costUsd")
    value = float(cost) if isinstance(cost, (int, float)) and not isinstance(cost, bool) else None
    reason = doc.get("partialReason")
    return value, reason if reason in ("cost_ceiling", "interrupted", "auth_failed") else ""


# JUSTIFICATION: the independent facts of one record; a wrapper object would only rename them
def make_record(  # pylint: disable=too-many-arguments
    harness: str,
    case: str,
    verdict: str,
    *,
    reason: str = "",
    git_sha: str | None = None,
    result_text: str = "",
    ts: str = "",
) -> dict[str, Any]:
    """Build one record. `ts` and `git_sha` come from the caller (no clock or git here).

    `result_text` is the captured result or stream (empty for a skip: the run never started).
    """
    record: dict[str, Any] = {"ts": ts, "harness": harness, "case": case, "git_sha": git_sha}
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


def parse_lines(text: str) -> tuple[list[dict[str, Any]], int]:
    """(valid records in time order, count of malformed lines skipped) from JSONL text."""
    records: list[dict[str, Any]] = []
    bad = 0
    for line in text.splitlines():
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
