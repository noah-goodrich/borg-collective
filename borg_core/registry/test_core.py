"""Unit tests for borg_core.registry.core (pure logic)."""

from borg_core.registry import core


# ── strip_control_chars ───────────────────────────────────────────────────────


def test_strip_control_chars_keeps_tab_lf_cr():
    text = "a\tb\nc\rd"
    assert core.strip_control_chars(text) == text


def test_strip_control_chars_removes_other_c0_controls():
    text = "a\x00b\x01c\x1fd"
    assert core.strip_control_chars(text) == "abcd"


def test_strip_control_chars_leaves_printable_text_untouched():
    text = '{"path": "/Users/noah/dev/troth", "summary": null}'
    assert core.strip_control_chars(text) == text


def test_strip_control_chars_empty_string():
    assert core.strip_control_chars("") == ""


# ── merge_entry ────────────────────────────────────────────────────────────────


def test_merge_entry_with_no_existing_entry_returns_new_data():
    assert core.merge_entry(None, {"path": "/a"}) == {"path": "/a"}


def test_merge_entry_shallow_merges_new_fields_over_existing():
    existing = {"path": "/old", "pinned": True, "color": "red"}
    data = {"path": "/new", "summary": None}
    result = core.merge_entry(existing, data)
    assert result == {"path": "/new", "pinned": True, "color": "red", "summary": None}


def test_merge_entry_does_not_mutate_existing_dict():
    existing = {"path": "/old"}
    core.merge_entry(existing, {"path": "/new"})
    assert existing == {"path": "/old"}


def test_merge_entry_with_empty_dict_existing():
    assert core.merge_entry({}, {"path": "/a"}) == {"path": "/a"}


# ── build_add_entry ──────────────────────────────────────────────────────────


def test_build_add_entry_full_fields():
    entry = core.build_add_entry(
        path="/Users/noah/dev/troth",
        source="cli",
        tmux_session="borg",
        tmux_window="troth",
        session_id="abc-123",
        last_activity="2026-08-12T20:00:00Z",
        repo="/Users/noah/dev/troth/.git",
    )
    assert entry == {
        "path": "/Users/noah/dev/troth",
        "source": "cli",
        "tmux_session": "borg",
        "tmux_window": "troth",
        "claude_session_id": "abc-123",
        "last_activity": "2026-08-12T20:00:00Z",
        "summary": None,
        "repo": "/Users/noah/dev/troth/.git",
    }


def test_build_add_entry_omitted_repo_is_null_not_missing():
    # THE EXPAND PHASE'S CONTRACT. `repo` defaults, so a caller that has not been taught the field
    # still produces a valid entry -- but the key is PRESENT and null rather than absent, so the
    # difference between "not in a git repository" and "written before the field existed" stays
    # readable in the JSON. `link.core.repo_sources` treats both as a group of one.
    entry = core.build_add_entry(
        path="/Users/noah/dev/troth",
        source="cli",
        tmux_session="borg",
        tmux_window=None,
        session_id=None,
        last_activity=None,
    )
    assert entry["repo"] is None
    assert "repo" in entry


def test_build_add_entry_no_session_or_tmux_window_yields_null_fields():
    entry = core.build_add_entry(
        path="/Users/noah/dev/fresh",
        source="cli",
        tmux_session="borg",
        tmux_window=None,
        session_id=None,
        last_activity=None,
    )
    assert entry["tmux_window"] is None
    assert entry["claude_session_id"] is None
    assert entry["last_activity"] is None
    assert entry["summary"] is None


def test_build_add_entry_empty_string_tmux_window_normalizes_to_none():
    entry = core.build_add_entry(
        path="/p", source="cli", tmux_session="borg", tmux_window="", session_id="", last_activity=""
    )
    assert entry["tmux_window"] is None
    assert entry["claude_session_id"] is None
    assert entry["last_activity"] is None
