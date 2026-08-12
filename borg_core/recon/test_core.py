"""Unit tests for borg_core.recon.core (pure logic, no I/O)."""

from borg_core.recon import core

VALID_ITEM = {
    "project": "p",
    "source": "s",
    "ref": "r#1",
    "title": "t",
    "state": "open",
    "changed": "c",
    "owner": "you",
    "action_needed": True,
    "urgency": "now",
    "one_line": "ol",
}


def _item(**overrides):
    item = dict(VALID_ITEM)
    item.update(overrides)
    return item


# ── epoch/since ──────────────────────────────────────────────────────────────


def test_epoch_to_iso():
    assert core.epoch_to_iso(1704171845) == "2024-01-02T05:04:05Z"


def test_resolve_since_explicit_wins():
    assert core.resolve_since("2025-01-02T03:04:05Z", 111, "marker", 222) == "2025-01-02T03:04:05Z"


def test_resolve_since_checkpoint_epoch_when_no_explicit():
    result = core.resolve_since("", 1704171845, "marker", 222)
    assert result == "2024-01-02T05:04:05Z"


def test_resolve_since_marker_when_no_checkpoint():
    assert core.resolve_since("", None, "2023-05-05T05:05:05Z", 222) == "2023-05-05T05:05:05Z"


def test_resolve_since_fallback_when_nothing_else():
    result = core.resolve_since("", None, None, 1704171845)
    assert result == "2024-01-02T05:04:05Z"


def test_resolve_since_empty_marker_falls_through_to_fallback():
    result = core.resolve_since("", None, "", 1704171845)
    assert result == "2024-01-02T05:04:05Z"


# ── adapter dedup ────────────────────────────────────────────────────────────


def test_dedup_adapters_first_wins():
    candidates = [("dup", "/user/recon-adapter-dup"), ("dup", "/repo/recon-adapter-dup")]
    assert core.dedup_adapters(candidates) == [("dup", "/user/recon-adapter-dup")]


def test_dedup_adapters_preserves_order_of_distinct_sources():
    candidates = [("alpha", "/a"), ("beta", "/b")]
    assert core.dedup_adapters(candidates) == [("alpha", "/a"), ("beta", "/b")]


def test_dedup_adapters_empty():
    assert core.dedup_adapters([]) == []


# ── schema validation ────────────────────────────────────────────────────────


def test_validate_item_accepts_well_formed_item():
    assert core.validate_item(VALID_ITEM) is True


def test_validate_item_rejects_bad_owner_enum():
    assert core.validate_item(_item(owner="boss")) is False


def test_validate_item_rejects_bad_urgency_enum():
    assert core.validate_item(_item(urgency="soon")) is False


def test_validate_item_rejects_missing_required_field():
    item = dict(VALID_ITEM)
    del item["ref"]
    assert core.validate_item(item) is False


def test_validate_item_rejects_non_dict():
    assert core.validate_item("not a dict") is False


def test_validate_item_rejects_non_bool_action_needed():
    assert core.validate_item(_item(action_needed="yes")) is False


def test_validate_track_accepts_track_object():
    assert core.validate_track({"source": "s", "summary": "ok", "items": []}) is True


def test_validate_track_rejects_non_dict():
    assert core.validate_track("RAW LOG DUMP not json") is False


def test_validate_track_rejects_missing_items_array():
    assert core.validate_track({"source": "s", "summary": "ok"}) is False


# ── adapter output processing ───────────────────────────────────────────────


def test_process_adapter_output_valid_track_marked_ok():
    raw = f'{{"source":"demo","summary":"1 item","items":[{_item_json()}]}}'
    result = core.process_adapter_output("demo", raw, 0)
    assert result["ok"] is True
    assert len(result["items"]) == 1
    assert result["dropped"] == 0


def _item_json():
    import json

    return json.dumps(VALID_ITEM)


def test_process_adapter_output_nonzero_rc_is_failed_track():
    result = core.process_adapter_output("broken", "RAW LOG DUMP not json", 1)
    assert result["ok"] is False
    assert result["items"] == []


def test_process_adapter_output_malformed_json_is_failed_track():
    result = core.process_adapter_output("broken", "RAW LOG DUMP not json", 0)
    assert result["ok"] is False


def test_process_adapter_output_empty_stdout_is_failed_track():
    result = core.process_adapter_output("empty", "", 0)
    assert result["ok"] is False


def test_process_adapter_output_drops_malformed_items_and_counts_them():
    bad = _item(owner="BOGUS")
    import json

    raw = json.dumps({"source": "mix", "summary": "m", "items": [VALID_ITEM, bad]})
    result = core.process_adapter_output("mix", raw, 0)
    assert len(result["items"]) == 1
    assert result["dropped"] == 1


def test_build_failed_track_shape():
    track = core.build_failed_track("src", 1)
    assert track == {
        "source": "src",
        "summary": "track failed (rc=1) or emitted malformed output",
        "items": [],
        "ok": False,
    }


def test_build_postprocess_failed_track_shape():
    track = core.build_postprocess_failed_track("src")
    assert track["ok"] is False
    assert track["summary"] == "post-processing failed"


# ── merge by project ─────────────────────────────────────────────────────────


def test_merge_by_project_groups_items_under_project_key():
    t1 = {"items": [_item(project="alpha")]}
    t2 = {"items": [_item(project="beta"), _item(project="alpha", ref="r#9")]}
    result = core.merge_by_project([t1, t2])
    assert len(result["alpha"]) == 2
    assert len(result["beta"]) == 1


def test_merge_by_project_skips_items_without_project():
    t1 = {"items": [{"source": "s"}]}
    assert core.merge_by_project([t1]) == {}


# ── checkpoint blockers extraction ──────────────────────────────────────────


def test_extract_checkpoint_blockers_captures_section():
    text = "# checkpoint\n## 4. Blockers\n- repo#7 waiting on review\n## 5. Next Session\ndo stuff\n"
    result = core.extract_checkpoint_blockers(text)
    assert "repo#7 waiting on review" in result
    assert "do stuff" not in result


def test_extract_checkpoint_blockers_no_heading():
    assert core.extract_checkpoint_blockers("# checkpoint\nnothing here\n") == ""


# ── contradiction detection ─────────────────────────────────────────────────


def test_project_contradictions_flags_resolved_item_still_blocking():
    items = [_item(project="alpha", ref="repo#7", state="merged")]
    result = core.project_contradictions("alpha", "- repo#7 waiting on review", items)
    assert len(result) == 1
    assert result[0]["ref"] == "repo#7"


def test_project_contradictions_empty_when_item_not_resolved():
    items = [_item(ref="repo#7", state="open")]
    result = core.project_contradictions("alpha", "- repo#7 waiting on review", items)
    assert result == []


def test_project_contradictions_empty_when_no_blockers():
    items = [_item(state="merged")]
    assert core.project_contradictions("alpha", "", items) == []


def test_project_contradictions_ignores_non_string_state_or_ref():
    items = [{"state": None, "ref": "repo#7"}]
    assert core.project_contradictions("alpha", "- repo#7", items) == []


# ── assemble + digest ───────────────────────────────────────────────────────


def test_assemble_builds_expected_shape():
    doc = core.assemble("since", "gen", [{"source": "s"}], {"alpha": []}, [])
    assert doc == {
        "since": "since",
        "generated_at": "gen",
        "sources": [{"source": "s"}],
        "items_by_project": {"alpha": []},
        "contradictions": [],
    }


def test_build_sources_summary():
    tracks = [{"source": "s", "summary": "ok", "items": [VALID_ITEM], "dropped": 2}]
    result = core.build_sources_summary(tracks)
    assert result == [{"source": "s", "summary": "ok", "ok": True, "count": 1, "dropped": 2}]


def test_render_digest_quiet_sweep():
    doc = core.assemble("2025-01-01T00:00:00Z", "2025-01-02T00:00:00Z", [], {}, [])
    output = core.render_digest(doc)
    assert "quiet sweep" in output
    assert "since 2025-01-01T00:00:00Z" in output


def test_render_digest_with_items_and_contradictions():
    doc = core.assemble(
        "since",
        "gen",
        [{"source": "github", "summary": "ok", "ok": True, "count": 1, "dropped": 0}],
        {"alpha": [VALID_ITEM]},
        [{"project": "alpha", "ref": "repo#7", "note": "confirm and update"}],
    )
    output = core.render_digest(doc)
    assert "github: ok" in output
    assert "Contradictions to resolve (1):" in output
    assert "alpha" in output
    assert "ol" in output


def test_render_digest_marks_failed_source():
    doc = core.assemble("since", "gen", [{"source": "s", "summary": "boom", "ok": False, "dropped": 0}], {}, [])
    output = core.render_digest(doc)
    assert "[FAILED]" in output


def test_render_digest_notes_dropped_items():
    doc = core.assemble("since", "gen", [{"source": "s", "summary": "ok", "ok": True, "dropped": 3}], {}, [])
    output = core.render_digest(doc)
    assert "dropped 3 malformed" in output
