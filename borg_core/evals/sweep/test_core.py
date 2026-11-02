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
    for group in core.plan_groups(["a", "b", "c", "d"])[1:]:
        run, _ = core.decide(group, spent)
        if run:
            spent += group.reserve_usd
            ran += 1
    assert ran == 3  # 4.2 + 3 * 1.5 = 8.7; a fourth would make 10.2


def test_plan_puts_lifecycle_first_then_link_next_one_case_each_sorted():
    groups = core.plan_groups(["b", "a"])
    assert [g.cases for g in groups] == [core.LIFECYCLE_CASES, ("a",), ("b",)]


def test_case_results_report_a_missing_record_as_an_error():
    rows = core.case_results(LIFECYCLE, [rec("P1", 0.3)])
    by_case = {r["case"]: r for r in rows}
    assert by_case["P1"]["verdict"] == "pass" and by_case["P1"]["cost_usd"] == 0.3
    assert by_case["N3"]["verdict"] == "error" and "no result" in by_case["N3"]["reason"]


def test_skipped_rows_carry_the_reason_and_no_cost():
    rows = core.skipped_rows(ONE, "why")
    assert rows == [
        {"harness": "link-next", "case": "next-rows-chooser", "verdict": "skip", "reason": "why", "cost_usd": None}
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
    assert set(doc["cases"][0]) == {"harness", "case", "verdict", "reason", "cost_usd"}
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
