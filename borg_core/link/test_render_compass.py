"""The compass on the human page: IN FOCUS, the board's destination suffix, WAITING ON YOU's parking rows.

Every compass block here is BUILT BY THE READER (`compass.core.build_compass`) from synthetic map text, never typed
as a dict: a fixture that handed the renderer the block's shape would prove nothing about the shape the reader
actually puts on the wire. The map is synthetic and invented; no real map is read.
"""

from borg_core.compass import core as compass_core
from borg_core.link import render
from borg_core.link.test_picture import plain
from borg_core.link.test_render import _doc, _focus, _repository_doc

TODAY = "2026-03-10"
MAP_DIR = "/maps/synthetic"

LOG = "## Today's leg\n\n- Wire up alpha reporting\n"
README = (
    "| Destination | Due |\n|---|---|\n"
    "| alpha | 2026-03-09 |\n| beta | 2026-04-30 |\n| gamma | TBD |\n| delta | TBD |\n"
)
DESTINATIONS = [
    ("destinations/alpha.md", "---\nid: alpha\nstatus: active\nrepositories:\n  - widgets\n---\n"),
    ("destinations/beta.md", "---\nid: beta\nstatus: active\nrepositories:\n  - gadgets\n---\n"),
    ("destinations/gamma.md", "---\nid: gamma\nstatus: active\nrepositories:\n  - gizmos\n---\n"),
    ("destinations/delta.md", "---\nid: delta\nstatus: frozen\nrepositories:\n  - doodads\n---\n"),
]
PARKING = (
    "- [ ] revisit the cache design | parked: 2026-02-01 | look: 2026-03-01 | seen: 2\n"
    "- [ ] not yet | parked: 2026-03-01 | look: 2026-12-01 | seen: 0\n"
    "- [ ] older thought | parked: 2026-01-01 | look: 2026-02-01 | seen: 5\n"
    "- [x] already handled | parked: 2026-01-01 | look: 2026-02-01 | seen: 1\n"
)
NAMES = ["widgets", "gadgets", "gizmos", "doodads", "orphan"]


def _compass(log=LOG, parking=PARKING, names=None) -> dict:
    return compass_core.build_compass(
        MAP_DIR, TODAY, log, DESTINATIONS, README, parking, NAMES if names is None else names
    )


def _entry(summary="s") -> dict:
    return {"source": "cli", "status": "idle", "relative_activity": "1d ago", "summary": summary}


def _queen(compass, projects=None, **overrides) -> dict:
    repositories = projects if projects is not None else {name: _entry() for name in NAMES}
    return _doc(
        total_projects=len(repositories),
        order=sorted(repositories),
        projects=repositories,
        compass=compass,
        **overrides,
    )


def _section_lines(rendered: str, title: str) -> list[str]:
    """The plain lines of one `▸ <title>` section, header and trailing blank excluded."""
    lines = plain(rendered).split("\n")
    start = next(i for i, line in enumerate(lines) if line.startswith(f"{render.SECTION_MARK}{title}"))
    end = next((i for i in range(start + 1, len(lines)) if not lines[i].strip()), len(lines))
    return lines[start + 1 : end]


# -- IN FOCUS, the Queen ------------------------------------------------------------------------------------------


def test_queen_in_focus_carries_the_leg_and_the_tally_without_zero_buckets():
    lines = _section_lines(render.document(_queen(_compass())), "IN FOCUS")
    assert lines == ["  Compass: Wire up alpha reporting · on track 1 · late 1 · undated 1"]


def test_queen_in_focus_without_a_leg_says_none_was_chosen():
    lines = _section_lines(render.document(_queen(_compass(log=None))), "IN FOCUS")
    assert lines == ["  Compass: no leg chosen · on track 1 · late 1 · undated 1"]


def test_queen_in_focus_with_a_not_chosen_yet_leg_says_none_was_chosen():
    log = "## Today's leg\n\n- Not chosen yet\n"
    assert _section_lines(render.document(_queen(_compass(log=log))), "IN FOCUS")[0].startswith(
        "  Compass: no leg chosen"
    )


def test_a_map_with_no_active_destination_prints_the_leg_alone():
    block = compass_core.build_compass(MAP_DIR, TODAY, LOG, [DESTINATIONS[3]], README, None, NAMES)
    assert _section_lines(render.document(_queen(block)), "IN FOCUS") == ["  Compass: Wire up alpha reporting"]


def test_no_map_is_exactly_one_in_focus_line_in_both_scopes():
    absent = compass_core.absent(MAP_DIR)
    assert _section_lines(render.document(_queen(absent)), "IN FOCUS") == [f"  Compass: no map at {MAP_DIR}"]
    page = render.document(_repository_doc(compass=absent))
    assert plain(page).count("Compass:") == 1
    assert f"  Compass: no map at {MAP_DIR}" in plain(page).split("\n")


def test_a_document_with_no_compass_key_renders_as_it_did_before():
    queen = render.document(_doc())
    assert "Compass" not in plain(queen)
    assert "no repository in focus" in plain(queen)
    assert "Compass" not in plain(render.document(_repository_doc()))


def test_control_characters_in_the_leg_never_reach_the_page():
    log = "## Today's leg\n\n- ship \x1b[31mred\x1b[0m\ttext\n"
    rendered = render.document(_queen(_compass(log=log)))
    assert "\x1b[31m" not in rendered
    assert "ship  [31mred [0m text" in _section_lines(rendered, "IN FOCUS")[0]


# -- IN FOCUS, a repository ----------------------------------------------------------------------------------------


def _card(name, compass, identity=None) -> str:
    focus = _focus(name=name, entry={"path": "null", "status": "idle"}, identity=identity or {})
    doc = _repository_doc(focus=focus, compass=compass)
    doc["scope"]["repository"] = name
    return plain(render.document(doc))


def test_a_repository_on_the_leg_gets_the_leg_and_no_off_route_line():
    page = _card("widgets", _compass())
    assert "  Compass: Wire up alpha reporting\n" in page
    assert "off route" not in page


def test_a_repository_whose_destination_is_not_on_the_leg_is_off_route():
    page = _card("gadgets", _compass())
    assert "  Compass: Wire up alpha reporting\n" in page
    assert "  off route: gadgets is not on today's leg\n" in page


def test_a_repository_no_destination_claims_is_never_off_route():
    assert "off route" not in _card("orphan", _compass())


def test_nothing_is_off_route_when_no_leg_was_chosen():
    page = _card("gadgets", _compass(log=None))
    assert "  Compass: no leg chosen\n" in page
    assert "off route" not in page


def test_a_worktree_is_judged_by_the_repository_it_is_a_worktree_of():
    identity = {"kind": "worktree", "branch": "x", "worktree_of": "gadgets"}
    assert "off route: gadgets is not on today's leg" in _card("gadgets-wt", _compass(), identity)


def test_the_compass_lines_come_after_the_status_line_and_the_card_has_no_tally():
    page = _card("gadgets", _compass())
    assert page.index("Status:") < page.index("Compass:")
    assert "on track" not in page


# -- the REPOSITORIES board -----------------------------------------------------------------------------------------


def _board(rendered: str) -> dict[str, str]:
    """Each repository's board row, by name (the first token of the row after the pin column)."""
    rows = {}
    for line in plain(rendered).split("\n"):
        stripped = line.strip(" *")
        for name in NAMES:
            if stripped.startswith(name + " "):
                rows[name] = line
    return rows


def test_board_rows_end_with_their_destination_state_and_unmapped_rows_with_nothing():
    rows = _board(render.document(_queen(_compass())))
    assert rows["widgets"].endswith("· late")
    assert rows["gadgets"].endswith("· off leg")
    assert rows["gizmos"].endswith("· off leg")
    assert rows["doodads"].endswith("· frozen")
    assert "·" not in rows["orphan"]


def test_with_no_leg_a_calm_state_is_named_not_called_off_leg():
    rows = _board(render.document(_queen(_compass(log=None))))
    assert rows["gadgets"].endswith("· on track")
    assert rows["gizmos"].endswith("· undated")


def test_a_late_repository_off_the_leg_still_reads_late():
    names = ["widgets", "gadgets"]
    log = "## Today's leg\n\n- Wire up beta reporting\n"
    rows = _board(render.document(_queen(_compass(log=log, names=names), {n: _entry() for n in names})))
    assert rows["widgets"].endswith("· late")
    assert rows["gadgets"].endswith("· on track")


def test_the_suffix_is_dropped_for_a_row_that_would_pass_the_boards_width_and_never_wraps():
    projects = {name: _entry() for name in NAMES}
    projects["gadgets"] = _entry("x" * 80)
    with_map = render.document(_queen(_compass(), projects))
    without_map = render.document(_queen(None, projects))
    widest = max(len(row) for row in _board(without_map).values())
    rows = _board(with_map)
    assert "·" not in rows["gadgets"]
    assert rows["widgets"].endswith("· late")
    assert max(len(row) for row in rows.values()) <= max(widest, render._BOARD_RULE)  # pylint: disable=protected-access
    assert len(_section_lines(with_map, "REPOSITORIES")) == len(_section_lines(without_map, "REPOSITORIES"))


def test_a_board_without_a_map_is_the_board_there_always_was():
    projects = {name: _entry() for name in NAMES}
    plain_board = _section_lines(render.document(_queen(None, projects)), "REPOSITORIES")
    assert (
        _section_lines(render.document(_queen(compass_core.absent(MAP_DIR), projects)), "REPOSITORIES") == plain_board
    )


# -- WAITING ON YOU -------------------------------------------------------------------------------------------------


def test_due_parking_items_are_listed_oldest_look_first_and_a_future_look_is_not():
    lines = _section_lines(render.document(_queen(_compass())), "WAITING ON YOU")
    parked = [line for line in lines if "parking:" in line]
    assert parked == [
        "  ▶ parking: older thought (look again 2026-02-01, seen 5)",
        "  ▶ parking: revisit the cache design (look again 2026-03-01, seen 2)",
    ]
    assert not any("not yet" in line or "already handled" in line for line in lines)


def test_a_due_parking_item_means_something_waits_on_you():
    page = plain(render.document(_queen(_compass())))
    assert "nothing waits on you" not in page
    assert "2 items" in page


def test_with_no_due_parking_and_nothing_else_nothing_waits_on_you():
    parking = "- [ ] not yet | parked: 2026-03-01 | look: 2026-12-01 | seen: 0\n"
    page = plain(render.document(_queen(_compass(parking=parking))))
    assert "nothing waits on you" in page
    assert "parking:" not in page


def test_parking_rows_are_the_queens_and_the_page_of_a_directory_has_none():
    assert "parking:" not in _card("widgets", _compass())


def test_parking_rows_are_capped_and_the_rest_counted():
    many = "".join(f"- [ ] thought {n} | parked: 2026-01-01 | look: 2026-02-0{n} | seen: {n}\n" for n in range(1, 8))
    lines = _section_lines(render.document(_queen(_compass(parking=many))), "WAITING ON YOU")
    assert sum("parking:" in line for line in lines) == 5
    assert any(line.strip() == "+2 more parked items due" for line in lines)


def test_a_parking_item_is_not_the_next_action_and_does_not_hide_it():
    lines = render.document(_queen(_compass())).split("\n")
    last = plain([line for line in lines if line.strip()][-1])
    assert last.startswith("  next  ") and "parking" not in last


# -- the wire is not widened ----------------------------------------------------------------------------------------


def test_porcelain_ignores_the_compass():
    projects = {name: _entry() for name in NAMES}
    assert render.porcelain(_queen(_compass(), projects)) == render.porcelain(_queen(None, projects))
