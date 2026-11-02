"""Tests for borg_core.evals.runstats: the pure half (parse a result, build a record, Wilson, report lines)."""

from __future__ import annotations

import ast
import json
from pathlib import Path

import pytest

from borg_core.evals import runstats as history

REPO = Path(__file__).resolve().parents[2]
RECORDED = REPO / "evals" / "cortex-agents" / "recorded"


def test_ten_identical_passes_have_wilson_lower_bound_near_072():
    low, high = history.wilson(10, 10)
    assert low == pytest.approx(0.722, abs=0.002)
    assert high == pytest.approx(1.0)


def test_wilson_of_no_evidence_is_none_not_zero():
    assert history.wilson(0, 0) is None


def test_parser_derives_turns_tokens_and_models_from_a_recorded_result_event():
    # A REAL recorded stream (evals/cortex-agents/recorded), not a fixture that sets what production must derive.
    derived = history.parse_result((RECORDED / "stream-assume.jsonl").read_text())
    assert derived["turns"] == 3
    assert derived["input_tokens"] == 8 + 10
    assert derived["output_tokens"] == 376 + 233
    assert derived["cache_read_tokens"] == 182619 + 14273
    assert derived["model"] == "claude-haiku-5-5,claude-sonnet-5-5"
    assert derived["cost_usd"] is None  # Cortex reports no cost; it is not estimated


def test_parser_falls_back_to_the_init_model_and_reads_claude_cost_and_usage():
    # The shape `claude -p --output-format json` prints (the fields run.sh's _report_run reads), after an init.
    stream = "\n".join(
        json.dumps(e)
        for e in [
            {"type": "system", "subtype": "init", "model": "claude-opus-5-5"},
            {
                "type": "result",
                "subtype": "success",
                "total_cost_usd": 0.4321,
                "num_turns": 7,
                "usage": {"input_tokens": 12, "output_tokens": 345, "cache_read_input_tokens": 9},
            },
        ]
    )
    derived = history.parse_result(stream)
    assert (derived["cost_usd"], derived["turns"]) == (0.4321, 7)
    assert (derived["input_tokens"], derived["output_tokens"], derived["cache_read_tokens"]) == (12, 345, 9)
    assert derived["model"] == "claude-opus-5-5"
    assert history.parse_result("")["model"] is None


def test_make_record_takes_ts_and_sha_from_the_caller():
    rec = history.make_record("h", "c", "pass", ts="2026-11-02T03:04:05Z", git_sha="abc")
    assert (rec["ts"], rec["git_sha"]) == ("2026-11-02T03:04:05Z", "abc")



def test_runstats_imports_are_a_pure_root_set():
    # W9004's allow-list would wave through pathlib or datetime; an exact root set is what keeps this module pure.
    tree = ast.parse((REPO / "borg_core" / "evals" / "runstats.py").read_text())
    roots = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            roots.update(a.name.split(".")[0] for a in node.names)
        elif isinstance(node, ast.ImportFrom):
            roots.add((node.module or "").split(".")[0])
    assert roots == {"__future__", "json", "math", "typing"}


def test_parse_lines_skips_malformed_and_sorts_by_time():
    good = json.dumps({"harness": "h", "case": "c", "ts": "2026-11-02T00:00:00Z", "verdict": "pass"})
    early = json.dumps({"harness": "h", "case": "c", "ts": "2026-11-01T00:00:00Z", "verdict": "fail"})
    records, bad = history.parse_lines(good + "\nnope\n" + early + "\n\n")
    assert [r["verdict"] for r in records] == ["fail", "pass"] and bad == 1


# A document built ONLY from the fields code.claude.com/docs/en/plugin-evals.md documents, plus an unknown one.
def _aggregate(**over):
    doc = {"schemaVersion": 1, "costUsd": 0.42, "partial": False, "futureField": {"x": 1}}
    doc.update(over)
    return json.dumps(doc)


def test_plugin_eval_cost_is_read_and_unknown_keys_are_ignored():
    assert history.parse_plugin_eval(_aggregate()) == (0.42, "")


def test_plugin_eval_partial_reason_is_one_of_the_documented_strings():
    assert history.parse_plugin_eval(_aggregate(partial=True, partialReason="cost_ceiling")) == (0.42, "cost_ceiling")
    assert history.parse_plugin_eval(_aggregate(partialReason="auth_failed"))[1] == "auth_failed"
    assert history.parse_plugin_eval(_aggregate(partialReason="made_up"))[1] == ""


@pytest.mark.parametrize(
    "text",
    [
        "not json",
        "[]",
        "null",
        _aggregate(schemaVersion=2),
        json.dumps({"costUsd": 1.0}),
        _aggregate(costUsd="1.0"),
        _aggregate(costUsd=True),
        _aggregate(costUsd=None),
    ],
)
def test_plugin_eval_anything_unrecognized_is_none(text):
    assert history.parse_plugin_eval(text)[0] is None
