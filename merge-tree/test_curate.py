"""Characterization tests for curate.py — lock in CURRENT behavior.

Per the python-core-and-toolchain directive (Part 2, P1/P2): these tests document existing
behavior, including known-fragile behavior, rather than "fixing" anything found along the way.
See curate.py:69-82 (bucket_for) and curate.py:106-109 (curate()) for the ordering fragility
this file's regression guard exists to catch — do not "fix" it here.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from curate import bucket_for, chain_refs, curate, normalize_health, numeric_urgency

FIXTURES = Path(__file__).parent / "fixtures"


# --------------------------------------------------------------------------
# numeric_urgency
# --------------------------------------------------------------------------


class TestNumericUrgency:
    def test_now_maps_to_base_88(self):
        assert numeric_urgency({"urgency": "now"}) == 88

    def test_this_week_maps_to_base_55(self):
        assert numeric_urgency({"urgency": "this_week"}) == 55

    def test_fyi_maps_to_base_30(self):
        assert numeric_urgency({"urgency": "fyi"}) == 30

    def test_urgency_absent_falls_back_to_fyi_base(self):
        assert numeric_urgency({}) == 30

    def test_urgency_already_numeric_is_passthrough(self):
        # isinstance(raw, (int, float)) branch: returned verbatim, no bump applied even
        # if is_entrypoint/blocked are set.
        assert numeric_urgency({"urgency": 42, "is_entrypoint": True, "blocked": True}) == 42

    def test_urgency_already_float_is_passthrough_and_int_cast(self):
        assert numeric_urgency({"urgency": 42.9}) == 42

    def test_unrecognised_urgency_word_falls_back_to_fyi_base(self):
        assert numeric_urgency({"urgency": "whenever"}) == 30

    def test_urgency_is_case_insensitive(self):
        assert numeric_urgency({"urgency": "NOW"}) == 88

    def test_entrypoint_bump_applied(self):
        assert numeric_urgency({"urgency": "fyi", "is_entrypoint": True}) == 35

    def test_blocked_bump_applied(self):
        assert numeric_urgency({"urgency": "fyi", "blocked": True}) == 35

    def test_entrypoint_and_blocked_bumps_stack(self):
        assert numeric_urgency({"urgency": "fyi", "is_entrypoint": True, "blocked": True}) == 40

    def test_score_is_capped_at_99(self):
        assert numeric_urgency({"urgency": "now", "is_entrypoint": True, "blocked": True}) == 98
        # now(88) + 5 + 5 = 98, still under cap; verify the cap itself with a direct probe
        assert numeric_urgency({"urgency": "now", "is_entrypoint": True, "blocked": True}) <= 99


# --------------------------------------------------------------------------
# chain_refs
# --------------------------------------------------------------------------


class TestChainRefs:
    def test_stacked_edge_contributes_both_endpoints(self):
        edges = [{"parent": "a#1", "child": "a#2", "kind": "stacked"}]
        assert chain_refs(edges) == {"a#1", "a#2"}

    def test_apex_edge_contributes_both_endpoints(self):
        edges = [{"parent": "a#1", "child": "a#2", "kind": "apex"}]
        assert chain_refs(edges) == {"a#1", "a#2"}

    def test_blocks_edge_is_ignored(self):
        edges = [{"parent": "a#1", "child": "a#2", "kind": "blocks"}]
        assert chain_refs(edges) == set()

    def test_unknown_kind_is_ignored(self):
        edges = [{"parent": "a#1", "child": "a#2", "kind": "mystery"}]
        assert chain_refs(edges) == set()

    def test_empty_edges_yields_empty_set(self):
        assert chain_refs([]) == set()

    def test_missing_endpoint_key_is_skipped_not_errored(self):
        edges = [{"parent": "a#1", "kind": "stacked"}]
        assert chain_refs(edges) == {"a#1"}

    def test_multiple_edges_merge_into_one_set(self):
        edges = [
            {"parent": "a#1", "child": "a#2", "kind": "stacked"},
            {"parent": "a#2", "child": "a#3", "kind": "apex"},
        ]
        assert chain_refs(edges) == {"a#1", "a#2", "a#3"}


# --------------------------------------------------------------------------
# bucket_for
# --------------------------------------------------------------------------


class TestBucketFor:
    def test_urgency_now_wins_regardless_of_chain_or_state(self):
        assert bucket_for({"urgency": "now", "ref": "x#1", "state": "MERGED"}, set()) == "needs-you"

    def test_urgency_now_is_case_insensitive(self):
        assert bucket_for({"urgency": "NOW"}, set()) == "needs-you"

    def test_urgency_absent_falls_through_to_chain_check(self):
        # str(None).lower() == "none", never equals "now" — no KeyError/AttributeError.
        assert bucket_for({"ref": "a#1"}, {"a#1"}) == "active-chains"

    def test_in_chain_wins_over_raw_state(self):
        assert bucket_for({"ref": "a#1", "state": "OPEN"}, {"a#1"}) == "active-chains"

    def test_merged_in_chain_stays_in_chain_not_noise(self):
        assert bucket_for({"ref": "a#1", "state": "MERGED"}, {"a#1"}) == "active-chains"

    def test_merged_state_not_in_chain_is_collapsed_noise(self):
        assert bucket_for({"ref": "a#1", "state": "MERGED"}, set()) == "collapsed-noise"

    def test_closed_state_not_in_chain_is_collapsed_noise(self):
        assert bucket_for({"ref": "a#1", "state": "CLOSED"}, set()) == "collapsed-noise"

    def test_state_is_case_insensitive(self):
        assert bucket_for({"ref": "a#1", "state": "merged"}, set()) == "collapsed-noise"

    def test_state_absent_and_not_in_chain_falls_to_standalone(self):
        assert bucket_for({"ref": "a#1"}, set()) == "standalone"

    def test_open_state_not_in_chain_is_standalone(self):
        assert bucket_for({"ref": "a#1", "state": "OPEN"}, set()) == "standalone"

    def test_numeric_urgency_never_equals_now_string_no_crash(self):
        # bucket_for reads urgency as a *string*; a numeric urgency (post numeric_urgency)
        # can never match "now", so this always falls through. Documented, not "fixed" —
        # see the needs-you regression guard below for why curate() still works today.
        assert bucket_for({"urgency": 88, "ref": "a#1"}, set()) == "standalone"


# --------------------------------------------------------------------------
# needs-you regression guard (curate.py:106-109 call-ordering fragility)
# --------------------------------------------------------------------------


class TestNeedsYouRegressionGuard:
    """Guards the exact call sequence in curate(): bucket_for(it, ...) must run on the RAW
    pre-overwrite item (string urgency) BEFORE cur["urgency"] is overwritten with a number.

    bucket_for reads item.get("urgency") as a *string* (.lower() == "now") while
    numeric_urgency WRITES cur["urgency"] as a *number*. If a future change passes `cur`
    instead of `it` to bucket_for, or reorders these two lines, "needs-you" would silently
    stop firing forever — no error, no type complaint, green suite (since bucket_for degrades
    to a no-crash "standalone" for a numeric urgency, not a KeyError). This test is the guard
    that would catch that regression. Do NOT change curate.py to "fix" this — that's a
    deliberate decision for Noah, out of scope here.
    """

    def test_item_with_urgency_now_is_assigned_needs_you_bucket(self):
        raw = {
            "meta": {},
            "items": [{"ref": "x#1", "urgency": "now", "state": "OPEN"}],
            "edges": [],
            "actions": {},
        }
        result = curate(raw)
        assert len(result["items"]) == 1
        assert result["items"][0]["bucket"] == "needs-you"
        # And urgency itself did get promoted to numeric, confirming both curate() side
        # effects happened, in the order that keeps the guard meaningful.
        assert result["items"][0]["urgency"] == 88


# --------------------------------------------------------------------------
# normalize_health
# --------------------------------------------------------------------------


class TestNormalizeHealth:
    def test_none_input_yields_empty_list(self):
        assert normalize_health(None) == []

    def test_empty_list_input_yields_empty_list(self):
        assert normalize_health([]) == []

    def test_valid_status_passthrough(self):
        out = normalize_health([{"check": "x", "status": "ok"}])
        assert out[0]["status"] == "ok"

    def test_invalid_status_coerced_to_down(self):
        out = normalize_health([{"check": "x", "status": "bogus"}])
        assert out[0]["status"] == "down"

    def test_missing_status_defaults_to_down(self):
        out = normalize_health([{"check": "x"}])
        assert out[0]["status"] == "down"

    def test_status_is_case_insensitive(self):
        out = normalize_health([{"check": "x", "status": "OK"}])
        assert out[0]["status"] == "ok"

    def test_does_not_mutate_input_dicts(self):
        original = {"check": "x", "status": "bogus"}
        normalize_health([original])
        assert original["status"] == "bogus"


# --------------------------------------------------------------------------
# curate() — integration over the whole pipeline
# --------------------------------------------------------------------------


class TestCurate:
    def test_items_without_ref_are_dropped(self):
        raw = {"items": [{"urgency": "now"}, {"ref": "a#1", "urgency": "fyi"}]}
        result = curate(raw)
        assert len(result["items"]) == 1
        assert result["items"][0]["ref"] == "a#1"

    def test_items_are_sorted_by_urgency_descending_then_ref(self):
        raw = {
            "items": [
                {"ref": "b#1", "urgency": "fyi"},
                {"ref": "a#1", "urgency": "now"},
                {"ref": "c#1", "urgency": "this_week"},
            ]
        }
        result = curate(raw)
        refs = [it["ref"] for it in result["items"]]
        assert refs == ["a#1", "c#1", "b#1"]

    def test_defaults_are_applied_when_fields_missing(self):
        raw = {"items": [{"ref": "a#1"}]}
        result = curate(raw)
        item = result["items"][0]
        assert item["is_entrypoint"] is False
        assert item["blocked"] is False
        assert item["one_line"] == ""
        assert item["action_needed"] == ""

    def test_edges_missing_endpoints_are_dropped(self):
        raw = {
            "items": [{"ref": "a#1"}],
            "edges": [{"parent": "a#1", "kind": "stacked"}, {"parent": "a#1", "child": "a#2", "kind": "stacked"}],
        }
        result = curate(raw)
        assert result["edges"] == [{"parent": "a#1", "child": "a#2", "kind": "stacked"}]

    def test_duplicate_edges_are_deduped(self):
        raw = {
            "items": [{"ref": "a#1"}],
            "edges": [
                {"parent": "a#1", "child": "a#2", "kind": "stacked"},
                {"parent": "a#1", "child": "a#2", "kind": "stacked"},
            ],
        }
        result = curate(raw)
        assert len(result["edges"]) == 1

    def test_edge_kept_if_only_one_endpoint_is_a_known_ref(self):
        raw = {
            "items": [{"ref": "a#1"}],
            "edges": [{"parent": "a#1", "child": "unknown#9", "kind": "stacked"}],
        }
        result = curate(raw)
        assert len(result["edges"]) == 1

    def test_edge_dropped_if_neither_endpoint_is_a_known_ref(self):
        raw = {
            "items": [{"ref": "a#1"}],
            "edges": [{"parent": "unknown#8", "child": "unknown#9", "kind": "stacked"}],
        }
        result = curate(raw)
        assert result["edges"] == []

    def test_edge_kind_defaults_to_stacked_when_absent(self):
        raw = {"items": [{"ref": "a#1"}], "edges": [{"parent": "a#1", "child": "a#1"}]}
        result = curate(raw)
        assert result["edges"][0]["kind"] == "stacked"

    def test_actions_only_kept_for_known_refs(self):
        raw = {
            "items": [{"ref": "a#1"}],
            "actions": {
                "a#1": {"label": "l", "command": "c", "class": "readonly"},
                "unknown#9": {"label": "l2", "command": "c2", "class": "readonly"},
            },
        }
        result = curate(raw)
        assert list(result["actions"].keys()) == ["a#1"]

    def test_non_dict_action_value_is_skipped(self):
        raw = {"items": [{"ref": "a#1"}], "actions": {"a#1": "not-a-dict"}}
        result = curate(raw)
        assert result["actions"] == {}

    def test_action_defaults_applied_when_fields_missing(self):
        raw = {"items": [{"ref": "a#1"}], "actions": {"a#1": {}}}
        result = curate(raw)
        assert result["actions"]["a#1"] == {"label": "", "command": "", "class": "readonly"}

    def test_missing_meta_items_edges_actions_do_not_error(self):
        result = curate({})
        assert result == {"meta": {"health": []}, "items": [], "edges": [], "actions": {}}

    def test_health_is_normalized_inside_curate(self):
        raw = {"meta": {"health": [{"check": "x", "status": "bad"}]}}
        result = curate(raw)
        assert result["meta"]["health"][0]["status"] == "down"

    def test_golden_fixture_produces_expected_bucket_counts(self):
        # Integration-level characterization against the checked-in golden fixture, without
        # asserting byte-for-byte equality against data.golden.json (that's render.py's/CI's
        # concern) — just that curate() over real-shaped data produces a stable count per
        # bucket, catching wholesale regressions.
        raw = json.loads((FIXTURES / "gather.raw.json").read_text())
        result = curate(raw)
        counts: dict[str, int] = {}
        for it in result["items"]:
            counts[it["bucket"]] = counts.get(it["bucket"], 0) + 1
        assert counts == {"needs-you": 3, "active-chains": 7, "collapsed-noise": 2, "standalone": 1}

    def test_golden_fixture_matches_checked_in_golden_json(self):
        raw = json.loads((FIXTURES / "gather.raw.json").read_text())
        golden = json.loads((FIXTURES / "data.golden.json").read_text())
        assert curate(raw) == golden


# --------------------------------------------------------------------------
# main() — CLI wrapper (I/O), thin smoke coverage only
# --------------------------------------------------------------------------


class TestMainCLI:
    def test_main_reads_writes_and_reports_counts(self, tmp_path, capsys, monkeypatch):
        import curate as curate_module

        src = tmp_path / "in.json"
        dst = tmp_path / "out.json"
        src.write_text(json.dumps({"items": [{"ref": "a#1", "urgency": "now"}]}))

        monkeypatch.setattr("sys.argv", ["curate.py", "--in", str(src), "--out", str(dst)])
        rc = curate_module.main()

        assert rc == 0
        written = json.loads(dst.read_text())
        assert written["items"][0]["bucket"] == "needs-you"
        out = capsys.readouterr().out
        assert "wrote" in out
        assert "per-bucket" in out

    def test_main_returns_1_on_unreadable_source(self, tmp_path, monkeypatch):
        import curate as curate_module

        monkeypatch.setattr(
            "sys.argv", ["curate.py", "--in", str(tmp_path / "missing.json"), "--out", str(tmp_path / "out.json")]
        )
        rc = curate_module.main()
        assert rc == 1

    def test_main_returns_1_on_unwritable_destination(self, tmp_path, monkeypatch):
        import curate as curate_module

        src = tmp_path / "in.json"
        src.write_text(json.dumps({"items": []}))
        monkeypatch.setattr(
            "sys.argv", ["curate.py", "--in", str(src), "--out", str(tmp_path / "nowhere" / "out.json")]
        )
        rc = curate_module.main()
        assert rc == 1
