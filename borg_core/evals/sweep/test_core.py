"""Tests for the pure sweep core: the budget rule, the guardian reading, the summary and its pinned contract."""

from __future__ import annotations

import ast
from pathlib import Path

import pytest

from borg_core.evals.sweep import core

LIFECYCLE = core.Group(core.LIFECYCLE_HARNESS, core.LIFECYCLE_CASES)
ONE = core.Group(core.LINK_NEXT_HARNESS, ("next-rows-chooser",))


def rec(case: str, cost, verdict: str = "pass", harness: str = core.LIFECYCLE_HARNESS) -> dict:
    return {"harness": harness, "case": case, "cost_usd": cost, "verdict": verdict, "reason": ""}


def test_lifecycle_reserves_six_ceilings_and_fits_the_cap():
    assert LIFECYCLE.reserve_usd == pytest.approx(9.0)
    assert core.decide(LIFECYCLE, 0.0) == (True, "")


def test_boundary_at_exactly_the_cap_runs_and_a_cent_over_skips():
    assert core.decide(ONE, 8.5)[0] is True
    run, reason = core.decide(ONE, 8.51)
    assert run is False
    assert "$10.00 sweep cap" in reason and "$8.51 spent" in reason


def test_skip_once_the_cap_is_reached():
    assert core.decide(ONE, 10.0)[0] is False


def test_null_cost_counts_as_the_full_ceiling_and_recorded_cost_counts_as_itself():
    records = [rec(c, 0.5) for c in core.LIFECYCLE_CASES[:5]] + [rec("N3", None)]
    assert core.group_spend(LIFECYCLE, records) == pytest.approx(5 * 0.5 + 1.5)


def test_a_case_with_no_record_counts_as_its_ceiling():
    assert core.group_spend(LIFECYCLE, []) == pytest.approx(9.0)


def test_the_newest_record_per_case_wins_and_other_harnesses_are_ignored():
    records = [rec("P1", 0.2), rec("P1", 0.4), rec("P1", 9.0, harness="other")]
    assert core.latest_by_case(records, LIFECYCLE)["P1"]["cost_usd"] == 0.4


def test_link_next_with_null_cost_fits_by_arithmetic_after_a_typical_lifecycle():
    spent = 6 * 0.7
    ran = 0
    for group in core.plan_groups(["a", "b", "c", "d"])[1:5]:
        run, _ = core.decide(group, spent)
        if run:
            spent += group.reserve_usd
            ran += 1
    assert ran == 3  # 4.2 + 3 * 1.5 = 8.7; a fourth would make 10.2


def test_plan_puts_lifecycle_first_then_link_next_one_case_each_sorted():
    groups = core.plan_groups(["b", "a"])
    assert [g.cases for g in groups[:3]] == [core.LIFECYCLE_CASES, ("a",), ("b",)]


def test_plan_orders_known_cost_before_null_cost_after_the_existing_groups():
    groups = core.plan_groups(["a"])
    assert [(g.harness, g.selector) for g in groups[2:]] == [
        ("orchestrator-skills", "review"),
        ("agent-gates", ""),
        ("orchestrator-skills", "resume"),
        ("orchestrator-skills", "break-glass"),
    ]


def test_step_3a_groups_cover_every_case_with_realistic_ceilings():
    plan = {(g.harness, g.selector): g for g in core.plan_groups([])}
    gates = plan[("agent-gates", "")]
    assert gates.cases == core.AGENT_GATES_CASES and len(gates.cases) == 8 and gates.agent_pinned
    assert gates.reserve_usd == pytest.approx(4.0)  # at the 1.50 default 8 cases reserve 12 and never ran
    assert plan[("orchestrator-skills", "resume")].cases == ("RS1", "RS2", "RS3", "RS4")
    assert plan[("orchestrator-skills", "break-glass")].cases == ("BG1", "BG2", "BG3")
    assert plan[("orchestrator-skills", "review")].cases == ("RV1", "RV2", "RV3", "RV4")
    assert not any(g.agent_pinned for g in plan.values() if g.harness != "agent-gates")


def test_every_group_fits_the_cap_alone_even_after_a_full_lifecycle_and_link_next():
    spent = 6 * 0.7 + 4 * 0.3
    for group in core.plan_groups(["a", "b", "c", "d"])[5:]:
        assert core.decide(group, spent, core.RAISED_CAP_USD)[0] is True, group


def test_rv3_shares_rv1s_run_so_it_reserves_and_spends_nothing_extra():
    review = next(g for g in core.plan_groups([]) if g.selector == "review")
    assert review.runs == ("RV1", "RV2", "RV4") and review.reserve_usd == pytest.approx(3 * 0.75)
    records = [rec(c, 0.3, harness="orchestrator-skills") for c in ("RV1", "RV2", "RV3", "RV4")]
    assert core.group_spend(review, records) == pytest.approx(0.9)  # RV1's cost is on RV3's record too
    rows = {r["case"]: r for r in core.case_results(review, records)}
    assert rows["RV3"]["verdict"] == "pass" and rows["RV3"]["cost_usd"] is None
    assert rows["RV1"]["cost_usd"] == 0.3


def test_an_unrecorded_shared_case_still_reads_as_an_error_but_adds_no_spend():
    review = next(g for g in core.plan_groups([]) if g.selector == "review")
    assert core.group_spend(review, []) == pytest.approx(3 * 0.75)
    assert {r["case"]: r["verdict"] for r in core.case_results(review, [])}["RV3"] == "error"


def test_rows_carry_the_model_and_agent_gates_reports_the_agents_pin():
    gates = next(g for g in core.plan_groups([]) if g.agent_pinned)
    assert {r["model"] for r in core.skipped_rows(gates, "why", "m-1")} == {core.AGENT_PIN_MODEL}
    assert {r["model"] for r in core.skipped_rows(LIFECYCLE, "why", "m-1")} == {"m-1"}


@pytest.mark.parametrize(
    "today,cap",
    [
        ("2026-11-02", 10.0),
        ("2026-11-03", 15.0),
        ("2026-11-08", 15.0),
        ("2026-12-02", 15.0),
        ("2026-12-03", 10.0),
        ("2026-12-06", 10.0),
        ("2027-06-01", 10.0),
        ("2026-12-02T23:59:59Z", 15.0),
    ],
)
def test_the_raised_cap_starts_2026_11_03_and_expires_on_its_own_2026_12_03(today, cap):
    assert core.sweep_cap_usd(today) == cap


def test_case_results_report_a_missing_record_as_an_error():
    rows = core.case_results(LIFECYCLE, [rec("P1", 0.3)])
    by_case = {r["case"]: r for r in rows}
    assert by_case["P1"]["verdict"] == "pass" and by_case["P1"]["cost_usd"] == 0.3
    assert by_case["N3"]["verdict"] == "error" and "no result" in by_case["N3"]["reason"]


def test_skipped_rows_carry_the_reason_and_no_cost():
    rows = core.skipped_rows(ONE, "why")
    assert rows == [
        {
            "harness": "link-next",
            "case": "next-rows-chooser",
            "verdict": "skip",
            "reason": "why",
            "cost_usd": None,
            "model": core.DEFAULT_MODEL,
        }
    ]


@pytest.mark.parametrize(
    "args,expected",
    [
        ((True, "ok", 95, 10, 92, 300), True),
        ((True, "ok", 92, 10, 92, 300), True),
        ((True, "ok", 91, 10, 92, 300), False),
        ((False, "ok", 99, 10, 92, 300), False),
        ((True, "error", 99, 10, 92, 300), False),
        ((True, "ok", "99", 10, 92, 300), False),
        ((True, "ok", True, 10, 92, 300), False),
        ((True, "ok", None, 10, 92, 300), False),
        ((True, "ok", 99, 301, 92, 300), False),
        ((True, "ok", 99, None, 92, 300), False),
        ((True, "ok", 99, -5, 92, 300), False),
    ],
)
def test_guardian_halts_only_on_a_fresh_ok_sample_at_or_over_the_threshold(args, expected):
    assert core.guardian_halted(*args) is expected


def make_summary(cases, halted=""):
    return core.summarize_sweep(
        started="2026-11-08T04:00:00Z",
        ts="2026-11-08T04:30:00Z",
        git_sha="abc",
        model="claude-opus-5-5",
        spend_usd=3.123456,
        halted=halted,
        cases=cases,
    )


def test_summary_keys_are_pinned_because_borg_next_and_doctor_read_them():
    doc = make_summary(core.case_results(LIFECYCLE, [rec(c, 0.1) for c in core.LIFECYCLE_CASES]))
    assert tuple(doc) == core.SUMMARY_KEYS
    assert set(core.SUMMARY_KEYS) == {
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
    }
    assert doc["schema"] == 1
    assert set(doc["cases"][0]) >= {"harness", "case", "verdict", "reason", "cost_usd"}  # expand-only: "model" is extra
    assert doc["spend_usd"] == 3.1235 and doc["cap_usd"] == 10.0 and doc["case_cap_usd"] == 1.5


def test_summary_needs_attention_on_skip_error_fail_or_halt_but_not_all_pass():
    passing = core.case_results(LIFECYCLE, [rec(c, 0.1) for c in core.LIFECYCLE_CASES])
    assert make_summary(passing)["needs_attention"] is False
    for verdict in ("skip", "error", "fail"):
        bad = [dict(passing[0], verdict=verdict)] + passing[1:]
        doc = make_summary(bad)
        assert doc["needs_attention"] is True and doc["counts"][verdict] == 1
    assert make_summary(passing, halted="halted")["needs_attention"] is True


def test_core_imports_only_pure_modules():
    tree = ast.parse(Path(core.__file__).read_text())
    roots = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            roots.update(a.name.split(".")[0] for a in node.names)
        elif isinstance(node, ast.ImportFrom):
            roots.add((node.module or "").split(".")[0])
    assert roots == {"__future__", "dataclasses", "typing"}


def test_a_recorded_link_next_cost_is_charged_instead_of_the_ceiling():
    records = [rec("next-rows-chooser", 0.35, harness=core.LINK_NEXT_HARNESS)]
    assert core.group_spend(ONE, records) == pytest.approx(0.35)
    assert core.group_spend(ONE, [rec("next-rows-chooser", None, harness=core.LINK_NEXT_HARNESS)]) == 1.5


def test_with_recorded_costs_all_four_link_next_cases_fit_after_a_typical_lifecycle():
    spent = 6 * 0.7
    for group in core.plan_groups(["a", "b", "c", "d"])[1:5]:
        run, _ = core.decide(group, spent)
        assert run  # decide() reserves the ceiling before the run; the recorded 0.4 is what is then charged
        spent += core.group_spend(group, [rec(group.cases[0], 0.4, harness=core.LINK_NEXT_HARNESS)])
    assert spent == pytest.approx(4.2 + 4 * 0.4)
