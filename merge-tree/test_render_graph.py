"""Characterization tests for render_graph.py's derivation helpers (P3).

Scope: derive_project / derive_workstream / hero_index / repo_of_ref / trimmed_item /
apply_annotations -- derived DATA structures only. Rendering/HTML output (build_html, CSS/JS
string assembly) is explicitly out of scope per the directive; no test here asserts on markup.

render_graph.py runs argparse and reads STATE files at MODULE IMPORT TIME (module-level
`ARGS = parse_args()`, `story = load_json(...)`, `D = load_json(...)`, `by_ref = {...}`), which
is itself a testability smell -- but per the testing-discipline rule this file locks in that
CURRENT behavior rather than refactoring it. The workaround: `sys.argv` is pinned before import
so argparse doesn't choke on pytest's own CLI flags, and the module-level globals it builds
(`by_ref`, `actions`, `items`) are monkeypatched per-test since derive_workstream/derive_project
read them as module globals rather than taking them as parameters.
"""

from __future__ import annotations

import sys

import pytest

# Module-level `ARGS = parse_args()` reads sys.argv at import time; pin it so pytest's own
# flags (-v, -q, file paths, ...) don't get parsed as unrecognised render_graph.py arguments.
_saved_argv = sys.argv
sys.argv = ["render_graph.py"]
try:
    import render_graph as rg
finally:
    sys.argv = _saved_argv


# --------------------------------------------------------------------------
# repo_of_ref
# --------------------------------------------------------------------------


class TestRepoOfRef:
    def test_known_ref_uses_item_repo_field(self, monkeypatch):
        monkeypatch.setattr(rg, "by_ref", {"a#1": {"repo": "explicit-repo"}})
        assert rg.repo_of_ref("a#1") == "explicit-repo"

    def test_unknown_ref_with_hash_splits_on_hash(self, monkeypatch):
        monkeypatch.setattr(rg, "by_ref", {})
        assert rg.repo_of_ref("myrepo#42") == "myrepo"

    def test_known_ref_but_item_has_no_repo_falls_through_to_hash_split(self, monkeypatch):
        monkeypatch.setattr(rg, "by_ref", {"a#1": {}})
        assert rg.repo_of_ref("a#1") == "a"

    def test_any_jira_style_key_maps_to_jira(self, monkeypatch):
        # Generic on purpose. This used to be a hardcoded startswith() against two specific project
        # prefixes, which put an employer identifier in source; the prefix is not ours to know.
        monkeypatch.setattr(rg, "by_ref", {})
        assert rg.repo_of_ref("PROJ-1234") == "jira"

    def test_a_second_unrelated_key_prefix_also_maps_to_jira(self, monkeypatch):
        # The pair is the point: one prefix passing could still be a hardcoded match.
        monkeypatch.setattr(rg, "by_ref", {})
        assert rg.repo_of_ref("DEV-99") == "jira"

    def test_a_hyphenated_word_that_is_not_a_key_is_not_jira(self, monkeypatch):
        # The negative that keeps the regex honest: lowercase, and no trailing number, so a repo or
        # branch name carrying a hyphen must not be swallowed as an issue key.
        monkeypatch.setattr(rg, "by_ref", {})
        assert rg.repo_of_ref("some-branch-name") == "some-branch-name"
        assert rg.repo_of_ref("RELEASE-NOTES") == "RELEASE-NOTES"

    def test_space_separated_ref_splits_on_space(self, monkeypatch):
        monkeypatch.setattr(rg, "by_ref", {})
        assert rg.repo_of_ref("someproject item-x") == "someproject"

    def test_bare_ref_with_no_delimiter_returns_ref_itself(self, monkeypatch):
        monkeypatch.setattr(rg, "by_ref", {})
        assert rg.repo_of_ref("bareref") == "bareref"


# --------------------------------------------------------------------------
# derive_workstream
# --------------------------------------------------------------------------


class TestDeriveWorkstream:
    def test_counts_items_and_blocked_reasons(self, monkeypatch):
        monkeypatch.setattr(rg, "by_ref", {})
        monkeypatch.setattr(rg, "actions", {})
        ws = {"items": ["a#1", "a#2"], "blocked_by": ["x", "y", "z"]}
        rg.derive_workstream(ws)
        assert ws["n_items"] == 2
        assert ws["n_blocked_reasons"] == 3

    def test_missing_items_and_blocked_by_default_to_zero(self, monkeypatch):
        monkeypatch.setattr(rg, "by_ref", {})
        monkeypatch.setattr(rg, "actions", {})
        ws = {}
        rg.derive_workstream(ws)
        assert ws["n_items"] == 0
        assert ws["n_blocked_reasons"] == 0
        assert ws["entry"] is None
        assert ws["max_urgency"] == 0

    def test_needs_you_true_when_any_item_bucket_is_needs_you(self, monkeypatch):
        monkeypatch.setattr(rg, "by_ref", {"a#1": {"bucket": "needs-you"}, "a#2": {"bucket": "standalone"}})
        monkeypatch.setattr(rg, "actions", {})
        ws = {"items": ["a#1", "a#2"]}
        rg.derive_workstream(ws)
        assert ws["needs_you"] is True

    def test_needs_you_false_when_no_item_matches(self, monkeypatch):
        monkeypatch.setattr(rg, "by_ref", {"a#1": {"bucket": "standalone"}})
        monkeypatch.setattr(rg, "actions", {})
        ws = {"items": ["a#1"]}
        rg.derive_workstream(ws)
        assert ws["needs_you"] is False

    def test_entry_prefers_entrypoint_item(self, monkeypatch):
        monkeypatch.setattr(
            rg,
            "by_ref",
            {"a#1": {"is_entrypoint": False}, "a#2": {"is_entrypoint": True}},
        )
        monkeypatch.setattr(rg, "actions", {})
        ws = {"items": ["a#1", "a#2"]}
        rg.derive_workstream(ws)
        assert ws["entry"] == "a#2"

    def test_entry_falls_back_to_item_with_an_action_when_no_entrypoint(self, monkeypatch):
        monkeypatch.setattr(rg, "by_ref", {"a#1": {}, "a#2": {}})
        monkeypatch.setattr(rg, "actions", {"a#2": {"label": "do it"}})
        ws = {"items": ["a#1", "a#2"]}
        rg.derive_workstream(ws)
        assert ws["entry"] == "a#2"

    def test_entry_falls_back_to_first_item_when_nothing_else_matches(self, monkeypatch):
        monkeypatch.setattr(rg, "by_ref", {"a#1": {}, "a#2": {}})
        monkeypatch.setattr(rg, "actions", {})
        ws = {"items": ["a#1", "a#2"]}
        rg.derive_workstream(ws)
        assert ws["entry"] == "a#1"

    def test_max_urgency_is_max_across_known_items_ignoring_unknown_refs(self, monkeypatch):
        monkeypatch.setattr(rg, "by_ref", {"a#1": {"urgency": 30}, "a#2": {"urgency": 88}})
        monkeypatch.setattr(rg, "actions", {})
        ws = {"items": ["a#1", "a#2", "unknown#9"]}
        rg.derive_workstream(ws)
        assert ws["max_urgency"] == 88

    def test_item_with_falsy_urgency_counts_as_zero_not_dropped(self, monkeypatch):
        monkeypatch.setattr(rg, "by_ref", {"a#1": {"urgency": None}})
        monkeypatch.setattr(rg, "actions", {})
        ws = {"items": ["a#1"]}
        rg.derive_workstream(ws)
        assert ws["max_urgency"] == 0


# --------------------------------------------------------------------------
# hero_index
# --------------------------------------------------------------------------


class TestHeroIndex:
    def test_empty_list_returns_none(self):
        assert rg.hero_index([]) is None

    def test_in_flight_and_needs_you_wins_first(self):
        wss = [
            {"state": "blocked", "needs_you": False},
            {"state": "in-flight", "needs_you": True},
        ]
        assert rg.hero_index(wss) == 1

    def test_in_flight_without_needs_you_does_not_win_the_first_pass(self):
        wss = [
            {"state": "ready-to-start", "needs_you": False},
            {"state": "in-flight", "needs_you": False},
        ]
        # Falls through to the state-priority scan; ready-to-start is checked before in-flight.
        assert rg.hero_index(wss) == 0

    def test_falls_back_to_state_priority_order(self):
        wss = [
            {"state": "pending", "needs_you": False},
            {"state": "blocked", "needs_you": False},
        ]
        assert rg.hero_index(wss) == 1

    def test_falls_back_to_zero_when_no_priority_state_matches(self):
        wss = [{"state": "done", "needs_you": False}]
        assert rg.hero_index(wss) == 0


# --------------------------------------------------------------------------
# derive_project
# --------------------------------------------------------------------------


class TestDeriveProject:
    def test_meter_counts_workstreams_per_state(self, monkeypatch):
        monkeypatch.setattr(rg, "by_ref", {})
        monkeypatch.setattr(rg, "actions", {})
        p = {
            "id": "some-project",
            "workstreams": [
                {"state": "ready-to-start", "items": []},
                {"state": "ready-to-start", "items": []},
                {"state": "in-flight", "items": []},
            ],
        }
        rg.derive_project(p)
        assert p["meter"]["ready-to-start"] == 2
        assert p["meter"]["in-flight"] == 1
        assert p["meter"]["blocked"] == 0
        assert p["meter_total"] == 3

    def test_workstream_state_outside_known_order_is_not_counted_but_not_an_error(self, monkeypatch):
        monkeypatch.setattr(rg, "by_ref", {})
        monkeypatch.setattr(rg, "actions", {})
        p = {"id": "x", "workstreams": [{"state": "mystery-state", "items": []}]}
        rg.derive_project(p)
        assert p["meter_total"] == 0

    def test_repos_are_deduped_and_sorted_across_workstreams(self, monkeypatch):
        monkeypatch.setattr(rg, "by_ref", {})
        monkeypatch.setattr(rg, "actions", {})
        p = {
            "id": "x",
            "workstreams": [
                {"state": "in-flight", "items": ["zzz#1", "aaa#2"]},
                {"state": "pending", "items": ["aaa#2"]},
            ],
        }
        rg.derive_project(p)
        assert p["repos"] == ["aaa", "zzz"]

    def test_named_true_when_id_in_named_ids(self, monkeypatch):
        monkeypatch.setattr(rg, "by_ref", {})
        monkeypatch.setattr(rg, "actions", {})
        p = {"id": rg.NAMED_IDS[0], "workstreams": []}
        rg.derive_project(p)
        assert p["named"] is True

    def test_named_false_when_id_not_in_named_ids(self, monkeypatch):
        monkeypatch.setattr(rg, "by_ref", {})
        monkeypatch.setattr(rg, "actions", {})
        p = {"id": "some-unnamed-project", "workstreams": []}
        rg.derive_project(p)
        assert p["named"] is False

    def test_any_needs_you_true_when_a_workstream_needs_you(self, monkeypatch):
        monkeypatch.setattr(rg, "by_ref", {"a#1": {"bucket": "needs-you"}})
        monkeypatch.setattr(rg, "actions", {})
        p = {"id": "x", "workstreams": [{"state": "in-flight", "items": ["a#1"]}]}
        rg.derive_project(p)
        assert p["any_needs_you"] is True

    def test_any_needs_you_false_when_no_workstream_needs_you(self, monkeypatch):
        monkeypatch.setattr(rg, "by_ref", {"a#1": {"bucket": "standalone"}})
        monkeypatch.setattr(rg, "actions", {})
        p = {"id": "x", "workstreams": [{"state": "in-flight", "items": ["a#1"]}]}
        rg.derive_project(p)
        assert p["any_needs_you"] is False

    def test_next_idx_reflects_hero_index_of_derived_workstreams(self, monkeypatch):
        monkeypatch.setattr(rg, "by_ref", {"a#1": {"bucket": "needs-you"}})
        monkeypatch.setattr(rg, "actions", {})
        p = {
            "id": "x",
            "workstreams": [
                {"state": "blocked", "items": []},
                {"state": "in-flight", "items": ["a#1"]},
            ],
        }
        rg.derive_project(p)
        assert p["next_idx"] == 1

    def test_missing_workstreams_key_does_not_error(self, monkeypatch):
        monkeypatch.setattr(rg, "by_ref", {})
        monkeypatch.setattr(rg, "actions", {})
        p = {"id": "x"}
        rg.derive_project(p)
        assert p["meter_total"] == 0
        assert p["repos"] == []
        assert p["next_idx"] is None


# --------------------------------------------------------------------------
# apply_annotations
# --------------------------------------------------------------------------


class TestApplyAnnotations:
    def test_overlay_only_whitelisted_keys(self):
        rows = [{"ref": "a#1", "title": "old", "url": "https://keep-me"}]
        ann = {"a#1": {"title": "new", "url": "https://should-not-apply"}}
        rg.apply_annotations(rows, ann)
        assert rows[0]["title"] == "new"
        assert rows[0]["url"] == "https://keep-me"

    def test_no_annotation_for_ref_leaves_row_untouched(self):
        rows = [{"ref": "a#1", "title": "old"}]
        rg.apply_annotations(rows, {})
        assert rows[0]["title"] == "old"

    def test_non_dict_annotation_value_is_ignored(self):
        rows = [{"ref": "a#1", "title": "old"}]
        rg.apply_annotations(rows, {"a#1": "not-a-dict"})
        assert rows[0]["title"] == "old"


# --------------------------------------------------------------------------
# trimmed_item
# --------------------------------------------------------------------------


class TestTrimmedItem:
    def test_defaults_when_optional_fields_missing(self, monkeypatch):
        monkeypatch.setattr(rg, "actions", {})
        out = rg.trimmed_item({"ref": "a#1"})
        assert out["title"] == ""
        assert out["is_entrypoint"] is False
        assert out["blocked"] is False
        assert out["action"] is None

    def test_url_is_sanitized_via_safe_url(self, monkeypatch):
        monkeypatch.setattr(rg, "actions", {})
        out = rg.trimmed_item({"ref": "a#1", "url": "javascript:alert(1)"})
        assert out["url"] == ""

    def test_action_included_when_present_for_ref(self, monkeypatch):
        monkeypatch.setattr(rg, "actions", {"a#1": {"label": "l", "command": "c", "class": "confirm"}})
        out = rg.trimmed_item({"ref": "a#1"})
        assert out["action"] == {"label": "l", "command": "c", "class": "confirm"}

    def test_no_action_when_ref_absent_from_actions(self, monkeypatch):
        monkeypatch.setattr(rg, "actions", {})
        out = rg.trimmed_item({"ref": "a#1"})
        assert out["action"] is None


# --------------------------------------------------------------------------
# safe_url / esc (small pure helpers, cheap to lock in alongside the above)
# --------------------------------------------------------------------------


class TestSafeUrl:
    @pytest.mark.parametrize(
        "url,expected",
        [
            ("https://example.com", "https://example.com"),
            ("http://example.com", "http://example.com"),
            ("javascript:alert(1)", ""),
            ("", ""),
            (None, ""),
            ("  https://example.com  ", "https://example.com"),
        ],
    )
    def test_safe_url_cases(self, url, expected):
        assert rg.safe_url(url) == expected


class TestEsc:
    def test_escapes_html_special_chars(self):
        assert rg.esc("<script>") == "&lt;script&gt;"

    def test_none_becomes_empty_string(self):
        assert rg.esc(None) == ""

    def test_non_string_is_stringified_first(self):
        assert rg.esc(42) == "42"
