"""The PURE half of the weekly live eval sweep: the budget rule, the guardian skip, and the summary.

No clock, environment, filesystem or subprocess: the shell passes the spend records, the guardian sample's facts and
the timestamp in. I/O is borg_core/evals/sweep/shell.py; the entry point is borg_core/evals/sweep/cli.py.

BUDGET RULE. An invocation is one harness run covering one or more cases. It starts only if (spend recorded so far in
this sweep) + (the ceiling of every case in the invocation) <= the sweep cap. A case whose recorded `cost_usd` is
null, or that left no record, counts as its full ceiling: unknown is never free. A case that would break the cap is
skipped with a reason, never run partway.

SUMMARY CONTRACT, `<state root>/evals/sweep-last.json` (written by shell.write_summary, read by `borg next` and
`borg doctor`). One JSON object, replaced whole after every sweep. Consumers must ignore unknown keys and must treat
a `schema` they do not know as unreadable::

    schema      int, SCHEMA_VERSION (currently 1)
    ts          ISO-8601 UTC, second resolution: when the sweep finished
    started     ISO-8601 UTC: when it started
    git_sha     the checkout HEAD the sweep ran from, or null
    model       the pinned model id every case was run with
    cap_usd     the sweep cap, number
    case_cap_usd  the per-case ceiling, number
    spend_usd   recorded spend counting null as the ceiling, number (rounded to 4 places)
    halted      "" normally; the reason when the usage guardian skipped the whole sweep
    cases       list of {harness, case, verdict, reason, cost_usd}, in run order;
                verdict is "pass" | "fail" | "skip" | "error"; reason is "" for pass and fail; cost_usd is
                a number or null (null when the run recorded none; a skip that never ran is null)
    counts      {"pass": n, "fail": n, "skip": n, "error": n}
    needs_attention  true when any case is skip, error or fail, or the sweep was halted
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

SCHEMA_VERSION = 1
SWEEP_CAP_USD = 10.0
CASE_CAP_USD = 1.5
DEFAULT_MODEL = "claude-opus-5-5"
LIFECYCLE_HARNESS = "lifecycle-manifests"
LIFECYCLE_CASES = ("P1", "N1", "P2", "N2", "P3", "N3")
LINK_NEXT_HARNESS = "link-next"
VERDICTS = ("pass", "fail", "skip", "error")
SUMMARY_KEYS = (
    "schema",
    "ts",
    "started",
    "git_sha",
    "model",
    "cap_usd",
    "case_cap_usd",
    "spend_usd",
    "halted",
    "cases",
    "counts",
    "needs_attention",
)
_EPSILON = 1e-9


@dataclass(frozen=True)
class Group:
    """One harness invocation: the cases it covers and the per-case ceiling it reserves."""

    harness: str
    cases: tuple[str, ...]
    ceiling_usd: float = CASE_CAP_USD

    @property
    def reserve_usd(self) -> float:
        """What starting this invocation reserves: every case at its ceiling."""
        return self.ceiling_usd * len(self.cases)


def plan_groups(link_next_cases: list[str]) -> list[Group]:
    """Lifecycle first, as ONE invocation (the six cases are paired and share a harness run), then link-next one case
    per invocation. Lifecycle goes first because its reserve is the biggest and its recorded cost is known; running
    link-next first with null costs could starve it."""
    groups = [Group(LIFECYCLE_HARNESS, LIFECYCLE_CASES)]
    groups.extend(Group(LINK_NEXT_HARNESS, (name,)) for name in sorted(link_next_cases))
    return groups


def decide(group: Group, spent_usd: float, cap_usd: float = SWEEP_CAP_USD) -> tuple[bool, str]:
    """(run, reason). Run only if spend so far plus the group's full reserve fits the cap; else a skip reason."""
    total = spent_usd + group.reserve_usd
    if total <= cap_usd + _EPSILON:
        return True, ""
    return False, (
        f"budget: ${spent_usd:.2f} spent + ${group.reserve_usd:.2f} reserved "
        f"({len(group.cases)} case(s) at ${group.ceiling_usd:.2f}) would exceed the ${cap_usd:.2f} sweep cap"
    )


def latest_by_case(records: list[dict[str, Any]], group: Group) -> dict[str, dict[str, Any]]:
    """The newest record per case of `group`. `records` are this sweep's, in time order."""
    found: dict[str, dict[str, Any]] = {}
    for rec in records:
        if rec.get("harness") == group.harness and rec.get("case") in group.cases:
            found[rec["case"]] = rec
    return found


def _cost(record: dict[str, Any] | None, ceiling_usd: float) -> float:
    value = (record or {}).get("cost_usd")
    return float(value) if isinstance(value, (int, float)) and not isinstance(value, bool) else ceiling_usd


def group_spend(group: Group, records: list[dict[str, Any]]) -> float:
    """Spend a finished invocation adds: each case's recorded cost, or its ceiling when null or unrecorded."""
    found = latest_by_case(records, group)
    return sum(_cost(found.get(case), group.ceiling_usd) for case in group.cases)


def case_results(group: Group, records: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """One summary row per case. A case the harness left no record for is an `error`: the harness did not do its job."""
    found = latest_by_case(records, group)
    rows = []
    for case in group.cases:
        rec = found.get(case)
        if rec is None:
            rows.append(_row(group.harness, case, "error", "the harness recorded no result for this case", None))
        else:
            cost = rec.get("cost_usd")
            numeric = isinstance(cost, (int, float)) and not isinstance(cost, bool)
            rows.append(_row(group.harness, case, rec["verdict"], rec.get("reason") or "", cost if numeric else None))
    return rows


def skipped_rows(group: Group, reason: str) -> list[dict[str, Any]]:
    """Summary rows for an invocation that never started."""
    return [_row(group.harness, case, "skip", reason, None) for case in group.cases]


def _row(harness: str, case: str, verdict: str, reason: str, cost: float | None) -> dict[str, Any]:
    return {"harness": harness, "case": case, "verdict": verdict, "reason": reason, "cost_usd": cost}


# JUSTIFICATION: the independent facts of the guardian's reading; a wrapper object would only rename them
def guardian_halted(  # pylint: disable=too-many-arguments,too-many-positional-arguments
    enabled: bool, status: str, session_pct: Any, age_sec: int | None, halt_pct: int, ttl_sec: int
) -> bool:
    """True when the usage guardian says new dispatch is halted: the reading hooks/borg-dispatch-guard.sh and
    `_rg_dispatch_guard_denies` (lib/borg/resume-gate.sh) share. FAIL-OPEN: anything missing, stale, malformed or not
    an `ok` sample means "not halted"."""
    if not enabled or status != "ok":
        return False
    if isinstance(session_pct, bool) or not isinstance(session_pct, (int, float)):
        return False
    if age_sec is None or age_sec < 0 or age_sec > ttl_sec:
        return False
    return int(session_pct) >= halt_pct


# JUSTIFICATION: the independent fields of one summary document; a wrapper object would only rename them
def summarize_sweep(  # pylint: disable=too-many-arguments
    *,
    started: str,
    ts: str,
    git_sha: str | None,
    model: str,
    spend_usd: float,
    halted: str,
    cases: list[dict[str, Any]],
    cap_usd: float = SWEEP_CAP_USD,
    case_cap_usd: float = CASE_CAP_USD,
) -> dict[str, Any]:
    """The `sweep-last.json` document (see the module docstring for the contract)."""
    counts = {verdict: sum(1 for c in cases if c["verdict"] == verdict) for verdict in VERDICTS}
    return {
        "schema": SCHEMA_VERSION,
        "ts": ts,
        "started": started,
        "git_sha": git_sha,
        "model": model,
        "cap_usd": cap_usd,
        "case_cap_usd": case_cap_usd,
        "spend_usd": round(spend_usd, 4),
        "halted": halted,
        "cases": cases,
        "counts": counts,
        "needs_attention": bool(halted) or any(counts[v] for v in ("fail", "skip", "error")),
    }
