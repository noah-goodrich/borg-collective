"""Unit tests for borg_core.link.core (pure logic).

The first section is THE PYTHON HALF OF THE SHARED REAP CASE TABLE: it reads
tests/fixtures/reaper-cases.tsv -- the same file tests/reaper_cases.bats reads -- and asserts the
same expected column against core.should_reap and core.reap_overlay. PROJECT_PLAN.md's Risks section
names shared-helper divergence as this port's crux; two readers over one table is the mitigation it
specifies. Changing an expected value here changes it for zsh too.
"""

from pathlib import Path

import pytest

from borg_core.link import core

CASES = Path(__file__).resolve().parent.parent.parent / "tests" / "fixtures" / "reaper-cases.tsv"

NOW = 1_800_000_000  # a fixed "now"; the table expresses every age relative to it


def _iso(epoch: int) -> str:
    from datetime import datetime, timezone  # noqa: PLC0415 — test-local, keeps core import surface honest

    return datetime.fromtimestamp(epoch, tz=timezone.utc).strftime(core.ISO_FORMAT)


def _age_to_timestamp(token: str) -> str:
    if token == "EMPTY":
        return ""
    if token == "NULL":
        return "null"
    if token == "GARBAGE":
        return "not-a-timestamp"
    if token.startswith("NOW-"):
        return _iso(NOW - int(token[len("NOW-") :]))
    if token.startswith("NOW+"):
        return _iso(NOW + int(token[len("NOW+") :]))
    return token


def _load_cases() -> list[dict]:
    rows = []
    for line in CASES.read_text(encoding="utf-8").split("\n"):
        if not line or line.startswith("#"):
            continue
        fields = line.split("\t")
        if fields[0] == "id":
            continue
        case_id, status, age, live, threshold, expect, why = fields
        rows.append(
            {
                "id": case_id,
                "status": "" if status == "EMPTY" else status,
                "last_activity": _age_to_timestamp(age),
                "live": live == "1",
                "threshold": None if threshold == "GARBAGE" else int(threshold),
                "expect": expect == "REAP",
                "why": why,
            }
        )
    return rows


CASE_ROWS = _load_cases()


def test_case_table_is_not_empty():
    # A parse bug that silently yielded zero rows would make every parametrized test below vanish
    # while the suite stayed green -- the shape of blindness this repo keeps getting bitten by.
    assert len(CASE_ROWS) >= 20


@pytest.mark.parametrize("case", CASE_ROWS, ids=[c["id"] for c in CASE_ROWS])
def test_should_reap_matches_the_shared_case_table(case):
    actual = core.should_reap(case["status"], case["last_activity"], case["live"], NOW, case["threshold"])
    assert actual is case["expect"], case["why"]


@pytest.mark.parametrize(
    "window_field,live_windows,expect_reaped",
    [
        (None, ["proj"], False),
        (None, ["other"], True),
        ("-", ["proj"], False),
        ("explicit", ["explicit"], False),
        ("explicit", ["proj"], True),
    ],
)
def test_reap_overlay_window_resolution(window_field, live_windows, expect_reaped):
    # The half the case table's first section cannot see: should_reap never receives a tmux_window,
    # because the overlay resolves it first. tests/reaper_cases.bats runs these same five rows
    # against the live zsh via borg_registry_with_state.
    registry = {
        "projects": {
            "proj": {
                "path": None,
                "status": "active",
                "last_activity": _iso(NOW - 999999),
                "tmux_window": window_field,
            }
        }
    }
    result = core.reap_overlay(registry, live_windows, NOW, 12)
    assert (result["projects"]["proj"]["status"] == "idle") is expect_reaped


def test_reap_overlay_liveness_is_literal_not_a_regex():
    # zsh matched with `grep -qx` and no -F, so `dotted.name` matched a live `dotted-name`. That was
    # fixed in zsh (lib/registry.zsh) rather than reproduced here; this pins that the two agree.
    registry = {
        "projects": {
            "dotted.name": {"status": "active", "last_activity": _iso(NOW - 999999)},
        }
    }
    result = core.reap_overlay(registry, ["dotted-name"], NOW, 12)
    assert result["projects"]["dotted.name"]["status"] == "idle"


def test_reap_overlay_records_the_previous_status_and_does_not_mutate():
    registry = {"projects": {"p": {"status": "waiting", "last_activity": None}}}
    result = core.reap_overlay(registry, [], NOW, 12)
    assert result["projects"]["p"]["_reaped_from"] == "waiting"
    assert result["projects"]["p"]["status"] == "idle"
    assert registry["projects"]["p"]["status"] == "waiting"


def test_reap_overlay_maps_the_tsv_sentinel_in_last_activity():
    # "-" is jq's empty-column sentinel, mapped back to "" by the shell loop; it must mean "no
    # timestamp" (and therefore reap), not "an unparseable timestamp".
    registry = {"projects": {"p": {"status": "active", "last_activity": "-"}}}
    result = core.reap_overlay(registry, [], NOW, 12)
    assert result["projects"]["p"]["status"] == "idle"


def test_reap_overlay_leaves_unreapable_projects_alone():
    registry = {"projects": {"p": {"status": "idle", "last_activity": None}}}
    result = core.reap_overlay(registry, [], NOW, 12)
    assert "_reaped_from" not in result["projects"]["p"]


def test_reap_overlay_handles_a_registry_with_no_projects_key():
    assert core.reap_overlay({}, [], NOW, 12) == {"projects": {}}


# ── relative_time ────────────────────────────────────────────────────────────


@pytest.mark.parametrize(
    "delta,expected",
    [
        (0, "just now"),
        (59, "just now"),
        (60, "1m ago"),
        (3599, "59m ago"),
        (3600, "1h ago"),
        (86399, "23h ago"),
        (86400, "yesterday"),
        (172799, "yesterday"),
        (172800, "2d ago"),
        (432000, "5d ago"),
    ],
)
def test_relative_time_buckets(delta, expected):
    assert core.relative_time(_iso(NOW - delta), NOW) == expected


@pytest.mark.parametrize("value", ["", None, "null"])
def test_relative_time_absent_is_never(value):
    assert core.relative_time(value, NOW) == "never"


def test_relative_time_echoes_an_unparseable_value_verbatim():
    # Deliberately NOT "never" -- zsh's `|| { echo "$ts"; return; }` echoes the input back, and
    # should_reap treats the same condition oppositely.
    assert core.relative_time("garbage", NOW) == "garbage"


def test_relative_time_treats_the_future_as_just_now():
    assert core.relative_time(_iso(NOW + 99999), NOW) == "just now"


# ── iso_to_epoch ─────────────────────────────────────────────────────────────


def test_iso_to_epoch_roundtrips():
    assert core.iso_to_epoch(_iso(NOW)) == NOW


@pytest.mark.parametrize(
    "value",
    ["", None, "garbage", "2026-08-01", "2026-08-01T10:00:00", "2026-08-01T10:00:00Zextra"],
)
def test_iso_to_epoch_rejects_everything_outside_the_strict_grammar(value):
    # The signed-off deviation: BSD `date -j -u -f` accepts trailing garbage and GNU `date -d`
    # accepts a far larger grammar, so the two platforms already disagree. One strict grammar
    # normalizes that split rather than adding a third behavior.
    assert core.iso_to_epoch(value) is None


def test_iso_to_epoch_rejects_an_out_of_range_date():
    assert core.iso_to_epoch("2026-02-30T00:00:00Z") is None


# ── countdown ────────────────────────────────────────────────────────────────


@pytest.mark.parametrize(
    "delta,expected",
    [
        (7200, "2h 0m"),  # the zero minute is NOT suppressed
        (7260, "2h 1m"),
        (3600, "1h 0m"),
        (125, "2m 5s"),
        (59, "59s"),
        (0, "now"),
        (-10, "now"),
    ],
)
def test_countdown(delta, expected):
    assert core.countdown(_iso(NOW + delta), NOW) == expected


@pytest.mark.parametrize("value", ["", None, "garbage"])
def test_countdown_unparseable_is_a_question_mark(value):
    assert core.countdown(value, NOW) == "?"


# ── state overlay ────────────────────────────────────────────────────────────


def test_overlay_state_lets_state_win():
    merged = core.overlay_state({"status": "idle", "summary": "old"}, {"status": "active"})
    assert merged["status"] == "active"
    assert merged["summary"] == "old"


def test_overlay_state_protects_archived_status_only():
    merged = core.overlay_state(
        {"status": "archived", "last_activity": "old"},
        {"status": "active", "last_activity": "new"},
    )
    assert merged["status"] == "archived"
    assert merged["last_activity"] == "new"


def test_overlay_state_does_not_mutate():
    entry = {"status": "idle"}
    core.overlay_state(entry, {"status": "active"})
    assert entry["status"] == "idle"


def test_with_state_applies_overlays_and_defaults_missing_status():
    registry = {"projects": {"a": {"path": "/a"}, "b": {"path": "/b", "status": "waiting"}}}
    result = core.with_state(registry, {"b": {"status": "active"}})
    assert result["projects"]["a"]["status"] == "idle"
    assert result["projects"]["b"]["status"] == "active"


@pytest.mark.parametrize("falsy", [None, False])
def test_with_state_replaces_every_falsy_status(falsy):
    # jq's `//=` replaces false as well as null; reproduced deliberately.
    result = core.with_state({"projects": {"a": {"status": falsy}}}, {})
    assert result["projects"]["a"]["status"] == "idle"


def test_with_state_leaves_empty_string_status_alone():
    # An empty string is jq-truthy, so `//=` does NOT replace it -- confirmed live against jq:
    # `{"a":{"status":""}} | .a.status //= "idle"` yields `""`, unchanged.
    result = core.with_state({"projects": {"a": {"status": ""}}}, {})
    assert result["projects"]["a"]["status"] == ""


def test_with_state_does_not_mutate_the_input():
    registry = {"projects": {"a": {"path": "/a"}}}
    core.with_state(registry, {"a": {"status": "active"}})
    assert "status" not in registry["projects"]["a"]


def test_with_state_handles_an_empty_registry():
    assert core.with_state({}, {}) == {"projects": {}}


# ── small primitives ─────────────────────────────────────────────────────────


def test_active_count_counts_waiting_and_active_only():
    registry = {
        "projects": {
            "a": {"status": "active"},
            "b": {"status": "waiting"},
            "c": {"status": "idle"},
            "d": {"status": "archived"},
        }
    }
    assert core.active_count(registry) == 2


def test_project_paths_preserves_insertion_order_and_blanks_nulls():
    registry = {"projects": {"z": {"path": "/z"}, "a": {"path": None}, "m": {}}}
    assert core.project_paths(registry) == [("z", "/z"), ("a", ""), ("m", "")]


def test_resolve_window_falls_back_to_the_project_name():
    for value in (None, "", "null", "-"):
        assert core.resolve_window("proj", {"tmux_window": value}) == "proj"
    assert core.resolve_window("proj", {}) == "proj"
    assert core.resolve_window("proj", {"tmux_window": "win"}) == "win"


@pytest.mark.parametrize(
    "text,expected",
    [
        ("# Title\nbody", "Title"),
        ("## Title", "Title"),
        ("#Title", "Title"),
        ("   Title", "Title"),
        ("", ""),
        ("\t# X", "\t# X"),
        ("# Title\r\nbody", "Title\r"),
    ],
)
def test_heading_title(text, expected):
    assert core.heading_title(text) == expected


def test_heading_title_ignores_unicode_line_separators():
    # `head -1` breaks on \n only; str.splitlines() would also break on \x0b, \x0c and U+2028.
    assert core.heading_title("# A B") == "A B"


@pytest.mark.parametrize(
    "text,expected",
    [
        ("# T\nShipped: 2026-03-01\n", "2026-03-01"),
        ("Shipped: 2026-03-01 by someone", "2026-03-01"),
        ("Shipped:2026-03-01", "2026-03-01"),
        ("prefix Shipped: A Shipped: B", "B"),
        ("no date here", ""),
        ("", ""),
    ],
)
def test_ship_date(text, expected):
    assert core.ship_date(text) == expected


@pytest.mark.parametrize(
    "name,expected",
    [("a.md", "a"), ("a.txt", "a.txt"), ("a.md.md", "a.md"), ("a", "a"), (".md", "")],
)
def test_slug_from_filename(name, expected):
    assert core.slug_from_filename(name) == expected


def test_sort_assimilated_is_filename_descending_with_a_tie_break():
    entries = [
        {"filename": "2026-01-01-a.md", "path": "/x", "project": "p"},
        {"filename": "2026-03-01-c.md", "path": "/z", "project": "p"},
        {"filename": "2026-02-01-b.md", "path": "/y", "project": "p"},
        {"filename": "2026-02-01-b.md", "path": "/y2", "project": "p"},
    ]
    result = core.sort_assimilated(entries)
    assert [e["filename"] for e in result] == [
        "2026-03-01-c.md",
        "2026-02-01-b.md",
        "2026-02-01-b.md",
        "2026-01-01-a.md",
    ]
    assert result[1]["path"] == "/y2"


def test_sort_checkpoints_is_name_descending_and_capped():
    names = ["2026-08-01.md", "2026-08-05.md", "2026-08-03.md", "2026-08-04.md"]
    assert core.sort_checkpoints(names) == ["2026-08-05.md", "2026-08-04.md", "2026-08-03.md"]
    assert core.sort_checkpoints(names, limit=1) == ["2026-08-05.md"]
    assert core.sort_checkpoints([]) == []


PLAN = """# Project Plan: X

## Objective

The objective line.

## Acceptance Criteria

- [x] done one
- [ ] not done
- [ ] also not done
"""


def test_plan_objective_takes_the_first_non_blank_line_within_two():
    assert core.plan_objective(PLAN) == "The objective line."


def test_plan_objective_misses_an_objective_more_than_two_lines_down():
    # grep -A2 only yields two lines after the heading; preserved deliberately.
    text = "## Objective\n\n\nToo far down.\n"
    assert core.plan_objective(text) == ""


def test_plan_objective_absent_heading():
    assert core.plan_objective("# X\n\nno heading here") == ""


def test_plan_progress_counts_met_and_total():
    assert core.plan_progress(PLAN) == (1, 3)


def test_plan_progress_with_nothing_met():
    # The shell renders this as "Progress: 0\n0/2 criteria met" across two lines; returning ints is
    # the signed-off deviation.
    text = "- [ ] one\n- [ ] two\n"
    assert core.plan_progress(text) == (0, 2)


def test_plan_progress_with_no_criteria_at_all():
    assert core.plan_progress("# X\n\nnothing\n") == (0, 0)


@pytest.mark.parametrize(
    "value,expected",
    [(None, "null"), (True, "true"), (False, "false"), ("x", "x"), (3, "3")],
)
def test_jq_interp(value, expected):
    assert core.jq_interp(value) == expected


# ── Phase 2: document primitives ─────────────────────────────────────────────


def _porcelain_projects():
    """Mirrors tests/cli_contract.bats:1443-1465's _link_setup_porcelain fixture."""
    return {
        "echo": {"status": "idle", "pinned": True, "last_activity": "2026-08-05T10:00:00Z"},
        "bravo": {"status": "waiting", "pinned": False, "last_activity": "2026-08-04T10:00:00Z"},
        "charlie": {"status": "active", "pinned": False, "last_activity": "2026-08-03T10:00:00Z"},
        "delta": {"status": "archived", "pinned": False, "last_activity": "2026-08-02T10:00:00Z"},
        "alpha": {"status": "idle", "pinned": False, "last_activity": "2026-08-01T00:00:00Z"},
        "foxtrot": {"status": "idle", "pinned": False, "last_activity": "2026-07-01T00:00:00Z"},
        "golf": {"status": "idle", "pinned": False, "last_activity": "2026-06-01T00:00:00Z"},
    }


def test_order_projects_matches_the_jq_three_key_sort():
    projects = _porcelain_projects()
    visible = {name: entry for name, entry in projects.items() if entry["status"] != "archived"}
    assert core.order_projects(visible) == ["echo", "bravo", "charlie", "golf", "foxtrot", "alpha"]


def test_order_projects_treats_string_true_as_unpinned():
    projects = {
        "a": {"status": "idle", "pinned": "true", "last_activity": "2026-08-01T00:00:00Z"},
        "b": {"status": "idle", "pinned": 1, "last_activity": "2026-08-02T00:00:00Z"},
        "c": {"status": "idle", "pinned": True, "last_activity": "2026-08-03T00:00:00Z"},
    }
    # Only "c" is a real JSON boolean true, so it sorts first; "a" and "b" stay in the unpinned
    # bucket and are ordered by their last_activity like any other unpinned row.
    assert core.order_projects(projects) == ["c", "a", "b"]


def test_project_sort_key_activity_sentinel_only_replaces_jq_falsy():
    missing = core.project_sort_key({"status": "idle"})
    explicit_null = core.project_sort_key({"status": "idle", "last_activity": None})
    empty_string = core.project_sort_key({"status": "idle", "last_activity": ""})
    unparseable = core.project_sort_key({"status": "idle", "last_activity": "2026-1-01T00:00:00Z"})

    assert missing[2] == "0"
    assert explicit_null[2] == "0"
    assert empty_string[2] == ""
    assert empty_string[2] < missing[2]  # "" sorts before "0"
    assert unparseable[2] == "2026-1-01T00:00:00Z"  # raw string, never epoch-parsed, never raises


def test_visible_projects_filters_archived_and_show_all_restores_it():
    registry = {"projects": _porcelain_projects()}
    now = 1_800_000_000

    hidden = core.visible_projects(registry, False, now)
    assert "delta" not in hidden
    assert len(hidden) == 6

    shown = core.visible_projects(registry, True, now)
    assert "delta" in shown
    assert len(shown) == 7
    assert core.order_projects(shown)[-1] == "delta"  # archived sorts last (rank 3)


def test_visible_projects_strips_internal_keys_and_adds_relative_activity():
    now = 1_800_007_200  # 7200s after the entry's last_activity
    entry = {
        "status": "idle",
        "last_activity": core.format_iso(1_800_000_000),
        "_reaped_from": "active",
    }
    registry = {"projects": {"proj": entry}}

    public = core.visible_projects(registry, False, now)["proj"]
    assert "_reaped_from" not in public
    assert public["relative_activity"] == "2h ago"


def test_assemble_emits_the_thirteen_keys_and_keeps_order_and_projects_in_lockstep():
    projects = {"a": {"status": "idle"}, "b": {"status": "idle"}}
    order = ["b", "a"]
    doc = core.assemble(
        generated_at="2026-08-13T00:00:00Z",
        show_all=False,
        total_projects=2,
        capacity=core.capacity(0, 3),
        projects=projects,
        order=order,
        directives=[],
        assimilated=[],
        cortex_pending=[],
        focus=None,
    )
    assert list(doc) == [
        "version",
        "generated_at",
        "show_all",
        "total_projects",
        "capacity",
        "order",
        "projects",
        "directives",
        "assimilated",
        "cortex_pending",
        "focus",
        "scope",
        "grid",
    ]
    # `scope` (S1) and `grid` (S3) are both additive: a caller that passes neither still gets both
    # keys, valued None, and the version deliberately stays 2 because nothing that existed before
    # them changed meaning. `.order`, `.projects` and `.focus` still cover the WHOLE registry in
    # every scope -- the sweep narrows the GRID and nothing else. The bump belongs to whichever step
    # first narrows a pre-existing key (AC2), and assemble's docstring records that the earlier
    # forecast, which put it here with the sweep fold, was wrong.
    assert doc["scope"] is None
    assert doc["grid"] is None
    assert doc["version"] == 2
    assert doc["total_projects"] == 2
    assert list(doc["projects"]) == doc["order"] == order

    # a name absent from `order` is dropped from the emitted map, not desynchronized.
    doc2 = core.assemble(
        generated_at="x",
        show_all=False,
        total_projects=2,
        capacity=core.capacity(0, 3),
        projects=projects,
        order=["b"],
        directives=[],
        assimilated=[],
        cortex_pending=[],
        focus=None,
    )
    assert list(doc2["projects"]) == ["b"]
    assert len(doc2["order"]) == len(doc2["projects"])


def test_assemble_total_projects_is_independent_of_order_and_projects():
    # The whole reason total_projects is a wire key rather than derived: an empty registry and an
    # all-archived one both emit order=[]/projects={}, but must be distinguishable.
    doc = core.assemble(
        generated_at="x",
        show_all=False,
        total_projects=3,
        capacity=core.capacity(0, 3),
        projects={},
        order=[],
        directives=[],
        assimilated=[],
        cortex_pending=[],
        focus=None,
    )
    assert doc["total_projects"] == 3
    assert doc["order"] == []
    assert doc["projects"] == {}


@pytest.mark.parametrize(
    "value,default,expected",
    [
        (None, "X", "X"),
        (False, "X", "X"),
        ("", "X", ""),
        (0, "X", 0),
        ("text", "X", "text"),
    ],
)
def test_jq_default_reproduces_jqs_alternative_operator(value, default, expected):
    # jq's `//` replaces null / false / missing ONLY -- NOT the empty string, NOT 0. Measured live:
    # `echo '{"a":""}' | jq '.a // "X"'` -> "", and `{"a":0}` -> 0. A bare `value or default` would
    # fail the "" and 0 cases here.
    assert core.jq_default(value, default) == expected


@pytest.mark.parametrize(
    "last_activity",
    [1_754_000_000, False, None, "2026-08-01T00:00:00Z"],
)
def test_public_entry_relative_activity_is_always_a_str(last_activity):
    entry = {"status": "idle", "last_activity": last_activity}
    public = core.public_entry(entry, now_epoch=1_800_000_000)
    assert isinstance(public["relative_activity"], str)


def test_format_iso_round_trips_with_iso_to_epoch():
    epoch = 1_800_000_000
    formatted = core.format_iso(epoch)
    assert formatted == "2027-01-15T08:00:00Z"
    assert core.iso_to_epoch(formatted) == epoch


def test_format_iso_is_the_shared_timefmt_function():
    # AC5: format_iso used to duplicate the same strftime shape as recon.core.epoch_to_iso and an
    # inline literal in recon/cli.py. Fails before this dedup (a locally-defined function); after,
    # this name is a re-export of the one shared definition in borg_core.timefmt.
    from borg_core import timefmt  # noqa: PLC0415 -- test-local, mirrors module's own import

    assert core.format_iso is timefmt.epoch_to_iso


# Phase 3 entry gate, test 1: capacity's `active > limit` is strict, mirroring borg.zsh:408's
# `(( active_count > BORG_MAX_ACTIVE ))`. Every prior exercise of core.capacity() passed 0 or a
# non-boundary pair as the active count (e.g. `capacity(0, 3)` at :502/:529), which is mutation-blind
# by construction: `>` and `>=` agree everywhere except exactly on the boundary. This asserts the
# boundary directly, in both directions, so mutating `>` to `>=` fails here even though nothing else
# in this file would move.
@pytest.mark.parametrize(
    ("active", "limit", "expected_over_limit"),
    [
        (3, 3, False),
        (4, 4, False),
        (4, 3, True),
        (5, 4, True),
    ],
)
def test_capacity_over_limit_boundary_is_strictly_greater_than(active, limit, expected_over_limit):
    result = core.capacity(active, limit)
    assert result["over_limit"] is expected_over_limit
    assert result["active"] == active
    assert result["limit"] == limit


# --- core.scope_for (S1) ---------------------------------------------------------------------
#
# Every case below traces to a defect the blind adversarial review found in the first-pass design;
# see docs/plans/directives/2026-08-25-link-front-door-hardened-spec.md for the full list.

PATHS = [
    ("borg-collective", "/Users/noah/dev/borg-collective"),
    ("ingle", "/Users/noah/dev/ingle"),
    ("ingle-site", "/Users/noah/dev/ingle-site"),
    ("nested", "/Users/noah/dev/ingle/packages/nested"),
    ("pathless", ""),
]
ROOT = "/Users/noah/dev"


def test_scope_for_exact_orchestrator_root_is_orchestrator():
    scope = core.scope_for(ROOT, ROOT, PATHS)
    assert scope == {"kind": "orchestrator", "repository": None, "local": False}


def test_scope_for_cwd_inside_a_registered_repository_resolves_to_it():
    scope = core.scope_for("/Users/noah/dev/ingle/src/deep", ROOT, PATHS)
    assert scope["kind"] == "repository"
    assert scope["repository"] == "ingle"


def test_scope_for_repository_root_itself_resolves_to_that_repository():
    scope = core.scope_for("/Users/noah/dev/ingle", ROOT, PATHS)
    assert scope["repository"] == "ingle"


def test_scope_for_nested_repository_wins_over_its_parent():
    # Longest matching prefix, not first match: /dev/ingle/packages/nested is inside /dev/ingle,
    # and the inner repository is the one you are standing in.
    scope = core.scope_for("/Users/noah/dev/ingle/packages/nested/src", ROOT, PATHS)
    assert scope["repository"] == "nested"


def test_scope_for_prefix_match_respects_path_component_boundaries():
    # THE BUG A RAW str.startswith WOULD SHIP: "/Users/noah/dev/ingle-site" starts with
    # "/Users/noah/dev/ingle", so a string-prefix match resolves ingle-site's cwd to `ingle` and
    # renders one repository's facts under another's name.
    scope = core.scope_for("/Users/noah/dev/ingle-site/app", ROOT, PATHS)
    assert scope["repository"] == "ingle-site"


def test_scope_for_unregistered_cwd_falls_back_to_orchestrator():
    scope = core.scope_for("/Users/noah/somewhere/else", ROOT, PATHS)
    assert scope["kind"] == "orchestrator"
    assert scope["repository"] is None


def test_scope_for_subdirectory_of_orchestrator_root_is_not_the_orchestrator():
    # The orchestrator test is EXACT equality, mirroring _borg_session_mode. An unregistered
    # subdirectory of the workspace root is not the orchestrator session -- it is simply unscoped.
    scope = core.scope_for("/Users/noah/dev/scratch", ROOT, PATHS)
    assert scope["kind"] == "orchestrator"


def test_scope_for_ignores_registry_entries_with_no_path():
    # The ("pathless", "") entry must never match, and must never raise.
    scope = core.scope_for("/Users/noah/dev/ingle", ROOT, PATHS)
    assert scope["repository"] == "ingle"


def test_scope_for_explicit_project_dominates_cwd():
    # B3, found independently by all three reviewers. `borg link ingle` from inside
    # borg-collective must scope to ingle -- otherwise it sweeps borg-collective and renders those
    # nodes under ingle's header. A wrong answer, not a missing one.
    scope = core.scope_for("/Users/noah/dev/borg-collective", ROOT, PATHS, requested_project="ingle")
    assert scope["repository"] == "ingle"


def test_scope_for_explicit_project_dominates_even_from_the_orchestrator_root():
    scope = core.scope_for(ROOT, ROOT, PATHS, requested_project="ingle")
    assert scope["kind"] == "repository"
    assert scope["repository"] == "ingle"


def test_scope_for_unknown_requested_project_falls_through_to_cwd():
    # scope must not invent a repository the registry has never heard of; _focus raises
    # ProjectNotFound for this case and that is the single place the error belongs.
    scope = core.scope_for("/Users/noah/dev/ingle", ROOT, PATHS, requested_project="nosuchproject")
    assert scope["repository"] == "ingle"


def test_scope_for_records_local_without_changing_resolution():
    swept = core.scope_for("/Users/noah/dev/ingle", ROOT, PATHS, local=False)
    opted = core.scope_for("/Users/noah/dev/ingle", ROOT, PATHS, local=True)
    assert opted["local"] is True
    assert swept["local"] is False
    assert opted["repository"] == swept["repository"] == "ingle"


def test_scope_for_empty_registry_is_orchestrator():
    assert core.scope_for("/Users/noah/dev/ingle", ROOT, [])["kind"] == "orchestrator"


def test_scope_for_longest_prefix_wins_regardless_of_registry_order():
    # Ordering independence: registry.json preserves JSON insertion order, so whether the nested
    # repository happens to be registered before or after its parent is an accident of when someone
    # ran `borg add`. Both orders must resolve to the inner repository.
    inner_first = [
        ("nested", "/Users/noah/dev/ingle/packages/nested"),
        ("ingle", "/Users/noah/dev/ingle"),
    ]
    outer_first = list(reversed(inner_first))
    cwd = "/Users/noah/dev/ingle/packages/nested/src"
    assert core.scope_for(cwd, ROOT, inner_first)["repository"] == "nested"
    assert core.scope_for(cwd, ROOT, outer_first)["repository"] == "nested"
