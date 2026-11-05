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
    model       the pinned model id the sweep passed to every harness EXCEPT those whose cases carry their own `model`
    cap_usd     the sweep cap in force on the sweep date (see sweep_cap_usd), number
    case_cap_usd  the per-case ceiling, number
    spend_usd   recorded spend counting null as the ceiling, number (rounded to 4 places)
    halted      "" normally; the reason when the usage guardian skipped the whole sweep
    cases       list of {harness, case, verdict, reason, cost_usd, model}, in run order; `model` is the id the case ran
                on, or "agent-frontmatter" when the sweep passed no --model and the agent's own pin was under test
                (expand-only, added 2026-11-03; older readers ignore it, so SCHEMA_VERSION stays 1);
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
RAISED_CAP_USD = 15.0
RAISED_CAP_FROM = "2026-11-03"
RAISED_CAP_UNTIL = "2026-12-03"
CASE_CAP_USD = 1.5
DEFAULT_MODEL = "claude-opus-5-5"
LIFECYCLE_HARNESS = "lifecycle-manifests"
LIFECYCLE_CASES = ("P1", "N1", "P2", "N2", "P3", "N3")
LINK_NEXT_HARNESS = "link-next"
AGENT_GATES_HARNESS = "agent-gates"
AGENT_GATES_CASES = ("NP1", "NP2", "NP3", "NP4", "V1", "V2", "V3", "V4")
AGENT_GATES_CEILING_USD = 0.5
AGENT_GATES_3B_CASES = ("GR1", "GR2", "SC1", "SC2", "RW1", "RW2", "RE1", "RE2")
AGENT_GATES_3B_CEILING_USD = 0.15
ORCH_SKILLS_HARNESS = "orchestrator-skills"
ORCH_SKILLS_CEILING_USD = 0.75
SWITCH_PANE_CEILING_USD = 0.4
COLLECTIVE_REVIEW_CEILING_USD = 0.75
ADHD_CEILING_USD = 0.75
AGENT_PIN_MODEL = "agent-frontmatter"
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
    """One harness invocation: the cases it covers and the per-case ceiling it reserves.

    `selector` is the harness's own name for the invocation when the cases are not passed one by one
    (orchestrator-skills takes a skill group). `shared` names graded cases that have no run of their own (RV3 is
    graded on RV1's run): they appear in the summary but reserve and count nothing. `agent_pinned` means the harness
    is given NO --model, because the agent's frontmatter pin is what the cases test."""

    harness: str
    cases: tuple[str, ...]
    ceiling_usd: float = CASE_CAP_USD
    selector: str = ""
    shared: tuple[str, ...] = ()
    agent_pinned: bool = False

    @property
    def runs(self) -> tuple[str, ...]:
        """The cases that cost a run of their own."""
        return tuple(c for c in self.cases if c not in self.shared)

    @property
    def reserve_usd(self) -> float:
        """What starting this invocation reserves: every case that runs, at its ceiling."""
        return self.ceiling_usd * len(self.runs)

    def model_for(self, model: str) -> str:
        """The model a row of this group reports: the sweep's, or the agent's own pin."""
        return AGENT_PIN_MODEL if self.agent_pinned else model


def sweep_cap_usd(today: str) -> float:
    """The sweep cap on `today` (YYYY-MM-DD, passed in: this module has no clock). $15 from RAISED_CAP_FROM up to but
    NOT including RAISED_CAP_UNTIL, else $10, so the raise expires with no human step. ISO dates order as strings."""
    return RAISED_CAP_USD if RAISED_CAP_FROM <= today[:10] < RAISED_CAP_UNTIL else SWEEP_CAP_USD


def plan_groups(link_next_cases: list[str]) -> list[Group]:
    """Lifecycle first, as ONE invocation (the six cases are paired and share a harness run), then link-next one case
    per invocation. Lifecycle goes first because its reserve is the biggest and its recorded cost is known; running
    link-next first with null costs could starve it.

    Then the step-3a harnesses, KNOWN COST BEFORE NULL: the review skill group has recorded costs for every run, so it
    goes first; agent-gates (only a recorded total, no per-case rows), resume and break-glass (nothing recorded) follow,
    because an unrecorded case counts at its full ceiling and a null-cost group run early inflates `spent` against the
    groups behind it. Ceilings come from recorded costs with headroom: agent-gates 8 cases for $1.52 is $0.19 each,
    ceiling $0.50 per attempt; orchestrator-skills 11 cases for $3.33 is $0.30 each (runs $0.22 to $0.33), ceiling
    $0.75 per run.

    Then the step-3b groups, last: new groups go after the existing ones. Their ceilings come from the recorded costs
    and from the per-case cap evals/orchestrator-skills/live.sh applies (the sweep passes its ceiling as
    EVAL_MAX_BUDGET_USD, which overrides that cap, so a ceiling below the cap would cut a run off under what live.sh
    allows): GR and SC under $0.01 a run, RE about $0.02, RW $0.03 to $0.05, so the 8 agent cases get $0.15 per attempt;
    SW and PN ran $0.10 to $0.18, live.sh cap $0.40, ceiling $0.40; CR ran $0.25 to $0.48, cap $0.75, ceiling $0.75; AD
    ran $0.20 to $0.52, cap $0.50, ceiling $0.75 so the top run is not cut off.
    AD4 is graded on AD2's run (`shared`)."""
    groups = [Group(LIFECYCLE_HARNESS, LIFECYCLE_CASES)]
    groups.extend(Group(LINK_NEXT_HARNESS, (name,)) for name in sorted(link_next_cases))
    skills = ORCH_SKILLS_CEILING_USD
    groups.append(
        Group(ORCH_SKILLS_HARNESS, ("RV1", "RV2", "RV3", "RV4"), skills, selector="review", shared=("RV3",))
    )
    groups.append(Group(AGENT_GATES_HARNESS, AGENT_GATES_CASES, AGENT_GATES_CEILING_USD, agent_pinned=True))
    groups.append(Group(ORCH_SKILLS_HARNESS, ("RS1", "RS2", "RS3", "RS4"), skills, selector="resume"))
    groups.append(Group(ORCH_SKILLS_HARNESS, ("BG1", "BG2", "BG3"), skills, selector="break-glass"))
    groups.append(Group(AGENT_GATES_HARNESS, AGENT_GATES_3B_CASES, AGENT_GATES_3B_CEILING_USD, agent_pinned=True))
    groups.append(Group(ORCH_SKILLS_HARNESS, ("SW1", "SW2", "SW3"), SWITCH_PANE_CEILING_USD, selector="switch"))
    groups.append(Group(ORCH_SKILLS_HARNESS, ("PN1", "PN2", "PN3"), SWITCH_PANE_CEILING_USD, selector="pane"))
    groups.append(
        Group(ORCH_SKILLS_HARNESS, ("CR1", "CR2"), COLLECTIVE_REVIEW_CEILING_USD, selector="collective-review")
    )
    groups.append(
        Group(
            ORCH_SKILLS_HARNESS,
            ("AD1", "AD2", "AD3", "AD4"),
            ADHD_CEILING_USD,
            selector="adhd",
            shared=("AD4",),
        )
    )
    return groups


def decide(group: Group, spent_usd: float, cap_usd: float = SWEEP_CAP_USD) -> tuple[bool, str]:
    """(run, reason). Run only if spend so far plus the group's full reserve fits the cap; else a skip reason."""
    total = spent_usd + group.reserve_usd
    if total <= cap_usd + _EPSILON:
        return True, ""
    return False, (
        f"budget: ${spent_usd:.2f} spent + ${group.reserve_usd:.2f} reserved "
        f"({len(group.runs)} run(s) at ${group.ceiling_usd:.2f}) would exceed the ${cap_usd:.2f} sweep cap"
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
    return sum(_cost(found.get(case), group.ceiling_usd) for case in group.runs)


def case_results(group: Group, records: list[dict[str, Any]], model: str = DEFAULT_MODEL) -> list[dict[str, Any]]:
    """One summary row per case. A case the harness left no record for is an `error`: the harness did not do its job.
    A shared case reports no cost: it rode another case's run, and repeating that cost would double-count it."""
    found = latest_by_case(records, group)
    shown = group.model_for(model)
    rows = []
    for case in group.cases:
        rec = found.get(case)
        if rec is None:
            rows.append(_row(group.harness, case, "error", "the harness recorded no result for this case", None, shown))
            continue
        cost = rec.get("cost_usd")
        numeric = isinstance(cost, (int, float)) and not isinstance(cost, bool) and case not in group.shared
        reason = rec.get("reason") or ""
        rows.append(_row(group.harness, case, rec["verdict"], reason, cost if numeric else None, shown))
    return rows


def skipped_rows(group: Group, reason: str, model: str = DEFAULT_MODEL) -> list[dict[str, Any]]:
    """Summary rows for an invocation that never started."""
    return [_row(group.harness, case, "skip", reason, None, group.model_for(model)) for case in group.cases]


# JUSTIFICATION: the six independent fields of one summary row
def _row(  # pylint: disable=too-many-arguments,too-many-positional-arguments
    harness: str, case: str, verdict: str, reason: str, cost: float | None, model: str
) -> dict[str, Any]:
    return {"harness": harness, "case": case, "verdict": verdict, "reason": reason, "cost_usd": cost, "model": model}


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
