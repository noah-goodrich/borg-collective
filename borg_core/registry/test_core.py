"""Unit tests for borg_core.registry.core (pure logic)."""

import pytest

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


# ── short tmux window names ────────────────────────────────────────────────────────────────────


def _reg(**windows):
    """Registry projects dict: name -> entry; a value of None means no tmux_window."""
    return {name: ({"tmux_window": w} if w else {}) for name, w in windows.items()}


@pytest.mark.parametrize(
    "candidate, needle",
    [
        ("", "empty"),
        ("a.b", "'.' or ':'"),
        ("a:b", "'.' or ':'"),
        ("borg", "session name"),
        ("widget", "name of project 'widget'"),
        ("wf", "tmux window of project 'other'"),
    ],
)
def test_validate_rejects_with_reason(candidate, needle):
    projects = _reg(me=None, widget=None, other="wf")
    reason = core.validate_window_name(candidate, "me", "borg", projects)
    assert reason is not None and needle in reason


def test_validate_accepts_free_name_and_own_name_and_own_window():
    projects = _reg(me="old", widget=None)
    assert core.validate_window_name("fresh", "me", "borg", projects) is None
    assert core.validate_window_name("me", "me", "borg", projects) is None
    assert core.validate_window_name("old", "me", "borg", projects) is None


def test_validate_tolerates_null_entries():
    assert core.validate_window_name("x", "me", "borg", {"me": None, "o": None}) is None


def test_derive_short_name_is_kept():
    assert core.derive_window_name("widget", "borg", {}) == "widget"


def test_derive_three_segments_gives_initials():
    assert core.derive_window_name("alpha-beta-gamma", "borg", {}) == "abg"
    assert core.derive_window_name("alpha_beta-gamma-delta", "borg", {}) == "abgd"


def test_derive_two_segments_takes_six_chars_trimmed():
    assert core.derive_window_name("widget-factory", "borg", {}) == "widget"
    assert core.derive_window_name("abcde-fghijk", "borg", {}) == "abcde"


def test_derive_borg_collective_avoids_session_name():
    assert core.derive_window_name("borg-collective", "borg", {}) == "borg-c"
    assert core.validate_window_name("borg", "borg-collective", "work", {}) is None
    assert core.derive_window_name("borg-collective", "work", {}) == "borg-c"


def test_derive_session_collision_grows_prefix():
    # the 6-char base "borgxy" equals the session, so the 7-char prefix wins
    assert core.derive_window_name("borgxy-thing", "borgxy", {}) == "borgxy-t"


def test_derive_prefix_growth_on_other_projects_name():
    projects = _reg(widget=None, mine=None)
    assert core.derive_window_name("widget-factory", "borg", projects) == "widget-f"


def test_derive_prefix_growth_on_other_projects_window():
    projects = _reg(other="widget")
    assert core.derive_window_name("widget-factory", "borg", projects) == "widget-f"


def test_derive_initials_collision_grows_prefix():
    projects = _reg(other="abg")
    assert core.derive_window_name("alpha-beta-gamma", "borg", projects) == "alpha-b"


def test_derive_falls_back_to_full_name_when_every_prefix_taken():
    name = "alpha-beta-gamma"
    taken = {f"p{n}": name[:n].rstrip("-") for n in range(7, len(name))}
    projects = _reg(abg="abg", **taken)
    assert core.derive_window_name(name, "borg", projects) == name


def test_derive_trims_trailing_separator_on_grown_prefix():
    # the 7-char prefix "alphab_" ends in a separator: it is trimmed to "alphab", which is the
    # (blocked) base again, so growth continues to "alphab_c"
    assert core.derive_window_name("alphab_cdef", "alphab", {}) == "alphab_c"


def test_derive_is_deterministic():
    projects = _reg(x=None)
    assert core.derive_window_name("alpha-beta-gamma", "borg", projects) == core.derive_window_name(
        "alpha-beta-gamma", "borg", projects
    )


@pytest.mark.parametrize(
    "entry, expected",
    [
        (None, True),
        ({}, True),
        ({"tmux_window": None}, True),
        ({"tmux_window": ""}, True),
        ({"tmux_window": "proj"}, True),
        ({"tmux_window": "pj"}, False),
    ],
)
def test_needs_derivation(entry, expected):
    assert core.needs_derivation(entry, "proj") is expected
