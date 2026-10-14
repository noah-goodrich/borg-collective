"""Tests for the pure compass reader. Every fixture is synthetic text; nothing here reads a file."""

from __future__ import annotations

import ast
import datetime
from pathlib import Path

import pytest

from borg_core.compass import core

TODAY = "2026-03-10"
TODAY_DATE = datetime.date.fromisoformat(TODAY)


def _destination(ident="alpha", status="active", extra="", body="", definition="approved", target="2026-04-01"):
    return (
        f"---\nid: {ident}\ndomain: work\nstatus: {status}\ndefinition: {definition}\ntarget: {target}\n"
        f"{extra}---\n\n# {ident}\n\n{body}"
    )


_BODY = (
    "### W1 Foundations\n- status: done\n- [x] one\n- [x] two\n\n"
    "### W2 Build the thing\n- status: active\n- [x] first\n- [ ] second\n- [ ] third\n\n"
    "### W3 Ship\n- status: proposed\n- [ ] ship it\n"
)


def _readme(*rows: tuple[str, str]) -> str:
    table = "| Destination | Domain | Due |\n|---|---|---|\n"
    return "# Map\n\n" + table + "".join(f"| {name} | work | {date} |\n" for name, date in rows)


def _build(destinations=(), readme=None, log=None, parking=None, names=()) -> dict:
    files = [(f"destinations/{i}.md", text) for i, text in enumerate(destinations)]
    return core.build_compass("/map", TODAY, log, files, readme, parking, list(names))


def test_an_absent_map_directory_is_found_false_and_nothing_else():
    assert core.absent("/nowhere") == {"found": False, "map_dir": "/nowhere"}


def test_an_empty_but_present_map_reports_found_true_with_empty_collections():
    compass = _build()
    assert compass == {
        "found": True,
        "map_dir": "/map",
        "today": TODAY,
        "leg": None,
        "destinations": [],
        "parking": [],
        "repositories": {},
        "warnings": [],
    }


# -- the leg -----------------------------------------------------------------------------------------------------


def test_a_chosen_leg_is_the_first_bullet_under_the_heading():
    log = "# 2026-03-10\n\n## Morning\n- unrelated\n\n## Today's leg\n\n- Ship the reader\n- a second bullet\n"
    assert core.parse_leg(log) == {"text": "Ship the reader"}


def test_not_chosen_yet_and_a_missing_log_both_mean_no_leg():
    assert core.parse_leg("## Today's leg\n- Not chosen yet\n") is None
    assert core.parse_leg("## Today's leg\n- not chosen yet (ask in the morning)\n") is None
    assert core.parse_leg(None) is None
    assert core.parse_leg("") is None


def test_a_log_without_the_heading_or_without_a_bullet_has_no_leg():
    assert core.parse_leg("# a day\n- a bullet outside any section\n") is None
    assert core.parse_leg("## Today's leg\n\nprose, no bullet\n\n## Evening\n- not the leg\n") is None


def test_a_curly_apostrophe_heading_is_still_the_leg_heading():
    assert core.parse_leg("## Today’s leg\n- curly\n") == {"text": "curly"}


# -- destinations ------------------------------------------------------------------------------------------------


def test_a_destination_parses_its_frontmatter_and_picks_the_active_waypoint():
    compass = _build([_destination(body=_BODY)], _readme(("alpha", "2026-06-01")))
    (destination,) = compass["destinations"]
    assert destination == {
        "id": "alpha",
        "domain": "work",
        "status": "active",
        "definition": "approved",
        "target": "2026-04-01",
        "repositories": [],
        "next_waypoint": {"name": "Build the thing", "status": "active", "done": 1, "total": 3},
        "due": "2026-06-01",
        "state": "on-track",
    }


def test_with_no_active_waypoint_the_first_proposed_one_is_next():
    body = "### W1 Done already\n- status: done\n- [x] a\n\n### W2 Later\n- status: proposed\n- [ ] b\n- [x] c\n"
    waypoint = _build([_destination(body=body)])["destinations"][0]["next_waypoint"]
    assert waypoint == {"name": "Later", "status": "proposed", "done": 1, "total": 2}


def test_no_open_waypoint_means_next_waypoint_null():
    body = "### W1 Done\n- status: done\n- [x] a\n\n### W2 Cut\n- status: dropped\n- [ ] b\n"
    assert _build([_destination(body=body)])["destinations"][0]["next_waypoint"] is None
    assert _build([_destination()])["destinations"][0]["next_waypoint"] is None


def test_a_heading_with_no_name_falls_back_to_the_waypoint_number():
    body = "### W4\n- status: active\n- [ ] a\n"
    assert _build([_destination(body=body)])["destinations"][0]["next_waypoint"]["name"] == "W4"


def test_repositories_is_a_yaml_list_of_dash_lines():
    extra = "repositories:\n  - first-repo\n  - 'second-repo'\n"
    assert _build([_destination(extra=extra)])["destinations"][0]["repositories"] == ["first-repo", "second-repo"]


def test_an_inline_list_and_a_missing_key_are_both_tolerated():
    assert _build([_destination(extra="repositories: [a, b]\n")])["destinations"][0]["repositories"] == ["a", "b"]
    assert _build([_destination()])["destinations"][0]["repositories"] == []


def test_optional_frontmatter_keys_may_be_absent():
    text = "---\nid: bare\nstatus: proposed\n---\n"
    (destination,) = _build([text])["destinations"]
    assert (destination["domain"], destination["definition"], destination["target"]) == (None, None, None)


@pytest.mark.parametrize(
    ("text", "reason"),
    [
        ("# just a heading, no frontmatter\n", "no frontmatter"),
        ("---\nid: unclosed\nstatus: active\n", "no frontmatter"),
        ("---\nstatus: active\n---\n", "no id"),
        ("---\nid: odd\nstatus: sideways\n---\n", "not one of"),
        ("---\nid: odd\n---\n", "not one of"),
        ("", "no frontmatter"),
    ],
)
def test_a_malformed_destination_is_skipped_with_a_warning_and_never_raises(text, reason):
    good = _destination("good")
    compass = _build([text, good])
    assert [d["id"] for d in compass["destinations"]] == ["good"]
    (warning,) = compass["warnings"]
    assert warning.startswith("destinations/0.md:")
    assert reason in warning


def test_a_duplicate_id_is_skipped_with_a_warning():
    compass = _build([_destination("same"), _destination("same", status="frozen")])
    assert [d["status"] for d in compass["destinations"]] == ["active"]
    assert "already declared" in compass["warnings"][0]


# -- due dates from the README -----------------------------------------------------------------------------------


def test_due_comes_from_the_readme_row_whose_first_cell_names_the_id():
    readme = _readme(("**alpha** (the first)", "2026-05-01"), ("beta", "TBD"), ("gamma", "TBD - not agreed"))
    dues, warnings = core.parse_due_dates(readme, ["alpha", "beta", "gamma", "delta"])
    assert dues == {"alpha": "2026-05-01", "beta": None, "gamma": None}
    assert warnings == []


def test_a_destination_without_a_readme_row_has_due_null():
    compass = _build([_destination("alpha"), _destination("beta")], _readme(("alpha", "2026-05-01")))
    assert [d["due"] for d in compass["destinations"]] == ["2026-05-01", None]


def test_an_id_that_is_the_prefix_of_another_does_not_steal_its_row():
    readme = _readme(("home-reno", "2026-09-01"), ("home", "2026-04-01"))
    dues, _ = core.parse_due_dates(readme, ["home", "home-reno"])
    assert dues == {"home": "2026-04-01", "home-reno": "2026-09-01"}


def test_the_date_column_may_be_headed_date_and_sit_before_the_destination_column_header():
    readme = "| Destination | Notes | Target date |\n| --- | --- | --- |\n| alpha | x | 2026-07-04 |\n"
    assert core.parse_due_dates(readme, ["alpha"])[0] == {"alpha": "2026-07-04"}


def test_the_id_is_matched_in_the_first_cell_only():
    readme = "| Date | Destination |\n| --- | --- |\n| 2026-07-04 | alpha |\n"
    assert core.parse_due_dates(readme, ["alpha"])[0] == {}


def test_a_readme_with_no_destinations_table_warns_instead_of_raising():
    dues, warnings = core.parse_due_dates("# Map\n\nNo table here.\n", ["alpha"])
    assert dues == {}
    assert "no destinations table" in warnings[0]
    assert core.parse_due_dates(None, ["alpha"]) == ({}, [])


def test_an_impossible_date_in_the_readme_is_due_null():
    dues, _ = core.parse_due_dates(_readme(("alpha", "2026-13-45")), ["alpha"])
    assert dues == {"alpha": None}


# -- the state rule ----------------------------------------------------------------------------------------------


def _state(status="active", due=None, done=1, total=3, waypoint=True) -> str:
    next_waypoint = {"name": "n", "status": "active", "done": done, "total": total} if waypoint else None
    destination = {"status": status, "due": due, "next_waypoint": next_waypoint}
    return core.destination_state(destination, TODAY_DATE)


@pytest.mark.parametrize("status", ["done", "killed", "frozen", "proposed"])
def test_a_non_active_status_gives_that_word_whatever_the_due_date(status):
    assert _state(status=status, due="2020-01-01") == status


def test_active_with_no_due_date_is_undated():
    assert _state(due=None) == "undated"


def test_due_before_today_is_late_even_when_the_waypoint_is_complete():
    assert _state(due="2026-03-09", done=3, total=3) == "late"


def test_due_today_is_not_late():
    assert _state(due=TODAY) == "at-risk"


def test_due_within_seven_days_with_the_waypoint_unfinished_is_at_risk():
    assert _state(due="2026-03-17") == "at-risk"


def test_due_in_eight_days_is_on_track():
    assert _state(due="2026-03-18") == "on-track"


def test_due_soon_with_the_waypoint_complete_is_on_track():
    assert _state(due="2026-03-12", done=3, total=3) == "on-track"


def test_due_soon_with_a_criteria_less_waypoint_is_at_risk_because_zero_of_zero_is_not_complete():
    assert _state(due="2026-03-12", done=0, total=0) == "at-risk"


def test_due_soon_with_no_next_waypoint_is_at_risk_because_nothing_shows_progress():
    assert _state(due="2026-03-12", waypoint=False) == "at-risk"


def test_every_state_is_reachable_end_to_end_from_text():
    texts = [
        _destination("d-done", status="done"),
        _destination("d-killed", status="killed"),
        _destination("d-frozen", status="frozen"),
        _destination("d-proposed", status="proposed"),
        _destination("d-undated", body=_BODY),
        _destination("d-late", body=_BODY),
        _destination("d-risk", body=_BODY),
        _destination("d-track", body=_BODY),
    ]
    readme = _readme(
        ("d-late", "2026-03-01"), ("d-risk", "2026-03-15"), ("d-track", "2026-12-01"), ("d-undated", "TBD")
    )
    states = {d["id"]: d["state"] for d in _build(texts, readme)["destinations"]}
    assert states == {
        "d-done": "done",
        "d-killed": "killed",
        "d-frozen": "frozen",
        "d-proposed": "proposed",
        "d-undated": "undated",
        "d-late": "late",
        "d-risk": "at-risk",
        "d-track": "on-track",
    }


# -- the parking lot ---------------------------------------------------------------------------------------------

_PARKING = (
    "# Parking lot\n\n"
    "- [ ] due item | parked: 2026-01-01 | look: 2026-03-10 | seen: 2 | last: 2026-02-01\n"
    "- [ ] overdue item | parked: 2026-01-01 | look: 2026-03-01 | seen: 0 | last: 2026-01-01\n"
    "- [ ] future item | parked: 2026-03-01 | look: 2026-04-01 | seen: 1 | last: 2026-03-01\n"
    "- [x] resolved item | parked: 2026-01-01 | look: 2026-01-02 | seen: 9 | last: 2026-01-02\n"
    "not a list item\n"
)


def test_parking_items_are_parsed_and_due_means_look_on_or_before_today():
    items = core.parse_parking(_PARKING, TODAY_DATE)
    assert [(i["text"], i["due"]) for i in items] == [
        ("due item", True),
        ("overdue item", True),
        ("future item", False),
    ]
    assert items[0] == {
        "text": "due item",
        "parked": "2026-01-01",
        "look": "2026-03-10",
        "seen": 2,
        "last": "2026-02-01",
        "due": True,
    }


def test_a_parking_line_with_missing_or_bad_fields_is_kept_with_nulls_and_is_not_due():
    (bare, garbled) = core.parse_parking("- [ ] bare\n- [ ] garbled | look: soon | seen: many\n", TODAY_DATE)
    assert bare == {"text": "bare", "parked": None, "look": None, "seen": 0, "last": None, "due": False}
    assert (garbled["look"], garbled["seen"], garbled["due"]) == (None, 0, False)
    assert core.parse_parking(None, TODAY_DATE) == []


@pytest.mark.parametrize("seen", ["²", "¹²", "٣²", "-3", "1" * 5000])
def test_a_seen_value_int_would_reject_or_that_is_not_a_plain_count_is_zero_and_never_raises(seen):
    (item,) = core.parse_parking(f"- [ ] odd | seen: {seen}\n", TODAY_DATE)
    assert item["seen"] == 0


# -- repositories ------------------------------------------------------------------------------------------------


def test_a_repository_maps_through_a_destinations_repositories_list():
    owner = _destination("alpha", extra="repositories:\n  - widgets\n")
    other = _destination("beta")
    mapped = _build([owner, other], names=["widgets", "beta", "stray"])["repositories"]
    assert mapped == {
        "widgets": {"destination": "alpha", "on_leg": False},
        "beta": {"destination": "beta", "on_leg": False},
        "stray": {"destination": None, "on_leg": False},
    }


def test_a_repository_maps_by_id_when_the_destination_lists_nothing():
    assert _build([_destination("widgets")], names=["widgets"])["repositories"]["widgets"]["destination"] == "widgets"


def test_the_list_wins_over_an_id_match():
    listed = _destination("alpha", extra="repositories:\n  - widgets\n")
    by_id = _destination("widgets")
    assert _build([by_id, listed], names=["widgets"])["repositories"]["widgets"]["destination"] == "alpha"


def test_on_leg_is_a_whole_word_match_on_the_destination_id_or_the_repository_name():
    owner = _destination("alpha", extra="repositories:\n  - widgets\n")
    log = "## Today's leg\n- Wire up alpha reporting\n"
    assert _build([owner], log=log, names=["widgets"])["repositories"]["widgets"]["on_leg"] is True
    log = "## Today's leg\n- Fix the widgets cache\n"
    assert _build([owner], log=log, names=["widgets"])["repositories"]["widgets"]["on_leg"] is True
    log = "## Today's leg\n- Replace widgets-v2 and alphabet soup\n"
    assert _build([owner], log=log, names=["widgets"])["repositories"]["widgets"]["on_leg"] is False


def test_on_leg_is_false_when_there_is_no_leg():
    owner = _destination("alpha", extra="repositories:\n  - widgets\n")
    assert _build([owner], names=["widgets"])["repositories"]["widgets"]["on_leg"] is False


def test_an_unowned_repository_can_still_be_on_the_leg_by_name():
    log = "## Today's leg\n- tidy stray\n"
    assert _build(log=log, names=["stray"])["repositories"]["stray"] == {"destination": None, "on_leg": True}


# -- purity ------------------------------------------------------------------------------------------------------


def test_core_imports_only_the_standard_pure_modules():
    """The module's whole claim is that a map file cannot reach the filesystem, environment or clock through it.

    W9004's allow-list permits `pathlib`, `json` and `datetime`, so the linter is the coarser gate; an exact
    ROOT set is what blocks `os`, `pathlib`, `time`, `subprocess` and the aliased spellings of them.
    """
    tree = ast.parse(Path(core.__file__).read_text(encoding="utf-8"))
    roots = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            roots.update(alias.name.split(".")[0] for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.level == 0 and node.module:
            roots.add(node.module.split(".")[0])
    assert roots == {"__future__", "datetime", "re"}


def test_core_never_reads_the_clock():
    source = Path(core.__file__).read_text(encoding="utf-8")
    for needle in ("now(", "today()", "utcnow", "time.time", "os.environ", "open("):
        assert needle not in source


# -- leg_priority: the sort prefix `borg next` ranks by ------------------------------------------------------------


def _prioritised(log, destinations, readme, names):
    block = core.build_compass("/m", TODAY, log, destinations, readme, None, names)
    return {name: core.leg_priority(block, name) for name in names}


def test_leg_priority_buckets_and_due_dates():
    readme = "| Destination | Due |\n|---|---|\n| alpha | 2026-04-01 |\n| beta | TBD |\n"
    destinations = [
        ("destinations/alpha.md", _destination("alpha", extra="repositories:\n  - dated\n")),
        ("destinations/beta.md", _destination("beta", extra="repositories:\n  - open\n")),
        ("destinations/gamma.md", _destination("gamma", status="frozen", extra="repositories:\n  - cold\n")),
        ("destinations/legged.md", _destination("legged", extra="repositories:\n  - hot\n")),
    ]
    log = "## Today's leg\n\n- work on legged\n"
    got = _prioritised(log, destinations, readme, ["dated", "open", "cold", "hot", "nobody"])
    assert got == {
        "dated": (1, "2026-04-01"),
        "open": (2, ""),
        "cold": (3, ""),
        "hot": (0, ""),
        "nobody": (3, ""),
    }


@pytest.mark.parametrize("block", [None, {}, {"found": False, "map_dir": "/m"}])
def test_leg_priority_is_a_constant_without_a_map(block):
    assert core.leg_priority(block, "anything") == (0, "")
