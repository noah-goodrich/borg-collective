"""The screen contract for the Queen's page (doorways S2, AC2): it fits one screen however much exists.

These read the limits and the words from `render` (`PAGE_LINES`, `PAGE_COLUMNS`, `GLYPH_LEGEND`, `STATUS_WORDS`), so
the contract and the page cannot drift apart. The two limits are ALSO asserted as the literals the directive approved
(30 and 100): a constant edited to make the page pass would otherwise take the test with it.

EVERY FIXTURE IS SYNTHETIC. The live board carries private-repository titles and this repository is public.
"""

import copy
import re
import unicodedata

import pytest

from borg_core.compass import core as compass_core
from borg_core.link import cli, core as link_core, grid as link_grid, picture, render
from borg_core.link.test_picture import fork_manifest, plain, swept
from borg_core.link.test_render import _doc, _repository_doc
from borg_core.link.test_render_compass import _compass

# The marks that are structure, not vocabulary: the section marker and the board's rule.
_STRUCTURE = {"▸", "─"}
_BOARD_ROW = re.compile(r"^[ *](?:└ )?\S+\s+\[[CDX]\]\s+(\S+)")


def _stack(index: int, repositories: int) -> dict:
    """One synthetic stack: the approved fork shape under its own owner, with a decision gate on a READY row.

    Row 3 (`warehouse#87`) is open under a merged parent, so it is READY, and its `decision` gate routes it to `yours`
    (WAITING ON YOU). The rest of the READY set is ungated, hence `mine`.
    """
    manifest = copy.deepcopy(fork_manifest())
    manifest["program"] = manifest["_id"] = f"stack-{index}"
    for row in manifest["rows"]:
        row["ref"] = row["ref"].replace("acme/", f"org{index}/")
        row["after"] = [ref.replace("acme/", f"org{index}/") for ref in row.get("after") or []]
        if row["order"] == "3":
            row["gate"] = {"kind": "decision", "blocked_by": f"pick the rollout window {index}", "resolved_by": "owner"}
    block = link_grid.grid_manifest(manifest, swept(manifest), {})
    block["path"] = f"/ws/repo-{index % repositories}/.stacks/stack-{index}.json"
    return block


def _you_row(number: int) -> dict:
    return {
        "project": f"repo-{number % 3}",
        "item": f"Synthetic pull request {number} with a title long enough to be cut",
        "next_step": "merge",
        "owner": "YOU",
        "ref": f"example/repo-{number % 3}#{number}",
    }


def _queen(*, stacks: int, directives: int = 3, waiting: int = 0, repositories: int = 6, **overrides) -> dict:
    """A Queen document with `stacks` stacks, `directives` queued directives and `waiting` YOU rows."""
    names = (["widgets", "gadgets", "gizmos", "doodads", "orphan"] + [f"repo-{n}" for n in range(repositories)])[
        :repositories
    ]
    projects = {
        name: {
            "source": "cli",
            "status": ("active", "waiting", "idle")[n % 3],
            "relative_activity": f"{n}d ago",
            "path": f"/ws/{name}",
            "summary": "A synthetic summary that runs well past any sensible width for one board row, " * 3,
        }
        for n, name in enumerate(names)
    }
    manifests = [_stack(n, repositories) for n in range(stacks)]
    grid = {
        **_doc()["grid"],
        "manifests": manifests,
        "declared": sum(len(m["nodes"]) for m in manifests),
        "unresolved": 0,
        "swept": True,
        "since": "2026-07-01T00:00:00Z",
        "picture_width": 114,
        "warnings": [f"synthetic warning {n}: " + "w" * 200 for n in range(4)],
    }
    document = _doc(
        total_projects=repositories,
        order=names,
        projects=projects,
        directives=[
            {"project": names[n % repositories], "title": f"Directive {n} " + "t" * 150} for n in range(directives)
        ],
        assimilated=[
            {"project": "widgets", "title": "Shipped " + "s" * 150, "ship_date": "2026-10-01"} for _ in range(3)
        ],
        capacity={"active": 5, "limit": 3, "over_limit": True},
        waiting={
            "rows": [_you_row(n) for n in range(waiting)],
            "hidden": {},
            "hidden_lines": ["+5 more decisions", "+9 agent tasks", "+2 stale drafts"] if waiting else [],
            "degraded": "synthetic degraded reason " + "d" * 150 if waiting else None,
        },
        grid=grid,
        compass=_compass(),
        **overrides,
    )
    return document


def _outside_repositories(page: str) -> list[str]:
    """Every plain line of `page` that is not inside the `▸ REPOSITORIES` block (its header, rows and blank)."""
    kept: list[str] = []
    inside = False
    for line in plain(page).split("\n")[:-1]:
        if line.startswith(render.SECTION_MARK):
            inside = line.startswith(f"{render.SECTION_MARK}REPOSITORIES")
        if not inside:
            kept.append(line)
    return kept


# 1 and 40 stacks are the directive's own pair; 0 is the empty case; 200 directives is "however many".
_SIZES = [(0, 0), (1, 3), (40, 3), (40, 200), (1, 200)]


@pytest.mark.parametrize("stacks,directives", _SIZES)
@pytest.mark.parametrize("waiting", [0, 40])
def test_the_page_outside_repositories_is_at_most_thirty_lines(stacks, directives, waiting):
    """AC2. MUTATION: render STACKS (or QUEUED, NEXT, WAITING ON YOU) uncapped on the compact page and this goes red
    on the 40-stack and 200-directive rows, because every one of them grows with its input."""
    page = render.document(_queen(stacks=stacks, directives=directives, waiting=waiting))
    assert render.PAGE_LINES == 30
    assert len(_outside_repositories(page)) <= 30


@pytest.mark.parametrize("stacks,directives", _SIZES)
def test_the_page_does_not_grow_with_its_input(stacks, directives):
    """The compact page is the same length at 1 stack as at 40, and at 3 directives as at 200: counts, not lists."""
    small = _outside_repositories(render.document(_queen(stacks=max(stacks, 1), directives=3, waiting=40)))
    this = _outside_repositories(render.document(_queen(stacks=stacks, directives=directives, waiting=40)))
    assert abs(len(this) - len(small)) <= 3, "only the empty-section placeholders may differ"


@pytest.mark.parametrize("stacks,directives", _SIZES)
@pytest.mark.parametrize("waiting", [0, 40])
def test_every_line_is_at_most_a_hundred_visible_columns(stacks, directives, waiting):
    """AC2, measured with `visible_len` and never `len`: the raw rows carry SGR and OSC-8 bytes."""
    page = render.document(_queen(stacks=stacks, directives=directives, waiting=waiting))
    assert render.PAGE_COLUMNS == 100
    lines = page.split("\n")
    assert all(picture.visible_len(line) <= 100 for line in lines), [
        (picture.visible_len(line), plain(line)) for line in lines if picture.visible_len(line) > 100
    ]
    assert any(len(line) > picture.visible_len(line) for line in lines), (
        "the fixture exercises escapes, so len would lie"
    )


def test_a_long_summary_is_cut_with_an_ellipsis_and_the_row_stays_on_the_board():
    page = plain(render.document(_queen(stacks=1)))
    rows = [line for line in page.split("\n") if _BOARD_ROW.match(line)]
    assert len(rows) == 6, "every repository stays on the board"
    assert all(row.endswith("…") for row in rows)


def test_a_long_repository_name_is_cut_so_its_destination_state_still_fits():
    """The suffix (`· late`) outranks the name: a name past the cap is shortened, not the state pushed off the screen."""
    long_name = "w" * 60
    names = [long_name, "gadgets"]
    destinations = [
        ("destinations/alpha.md", f"---\nid: alpha\nstatus: active\nrepositories:\n  - {long_name}\n---\n"),
    ]
    compass = compass_core.build_compass(
        "/maps/synthetic",
        "2026-03-10",
        "",
        destinations,
        "| Destination | Due |\n|---|---|\n| alpha | 2026-03-09 |\n",
        None,
        names,
    )
    entry = {"source": "cli", "status": "idle", "relative_activity": "1d ago", "summary": "s" * 80}
    doc = _doc(total_projects=2, order=names, projects={name: dict(entry) for name in names}, compass=compass)
    page = plain(render.document(doc)).split("\n")
    row = next(line for line in page if line.lstrip(" *").startswith("w"))
    assert " · late" in row and "…" in row.split(" · late")[0], row
    assert picture.visible_len(row) <= 100
    assert long_name in plain(render.document(doc, full=True)), "--full prints the name whole"


def test_the_legend_is_one_line_and_names_every_glyph_in_the_closed_set():
    page = plain(render.document(_queen(stacks=1))).split("\n")
    legend = [line for line in page if "merged" in line and "worktree" in line]
    assert len(legend) == 1
    for glyph, word in render.GLYPH_LEGEND:
        assert f"{glyph} {word}" in legend[0]
    assert picture.visible_len(legend[0]) <= 100


def test_the_state_glyph_words_are_in_the_closed_status_vocabulary():
    """Both readers of the set agree: every word the legend pairs with a state glyph is a status word."""
    for _glyph, word in render.STATE_GLYPHS:
        assert word in render.STATUS_WORDS
    assert len(set(render.STATUS_WORDS)) == len(render.STATUS_WORDS), "a closed set has no duplicates"


def test_the_set_covers_the_compasss_states_and_the_registrys_statuses():
    """Tied to the sources, not restated: a state the map or the registry can print must be a status word."""
    assert {words for _, words in render._COMPASS_STATES} <= set(render.STATUS_WORDS)  # pylint: disable=protected-access
    assert set(compass_core.STATUSES) - {"active"} <= set(render.STATUS_WORDS)
    assert {link_core.DEFAULT_STATUS, render._JQ_ABSENT_STATUS} <= set(render.STATUS_WORDS)  # pylint: disable=protected-access


@pytest.mark.parametrize("full", [False, True])
def test_every_status_word_on_the_board_is_in_the_closed_set(full):
    """The board's STATUS column and its `· <state>` suffixes come from `STATUS_WORDS`, and nothing else is printed.

    Statuses are read off the rendered rows; destination states off `_board_suffix` and then looked for in the
    rendered row, because a suffix is followed by free-text summary that a pattern could not tell apart.
    """
    document = _queen(stacks=2)
    document["projects"]["gizmos"]["status"] = "archived"
    page = plain(render.document(document, full=full)).split("\n")
    rows = [m.group(1) for line in page if (m := _BOARD_ROW.match(line))]
    assert set(rows) <= set(render.STATUS_WORDS), set(rows) - set(render.STATUS_WORDS)
    compass = document["compass"]
    seen = 0
    for name in document["projects"]:
        suffix = render._board_suffix(compass, name)  # pylint: disable=protected-access
        if suffix:
            assert suffix.removeprefix("· ") in render.STATUS_WORDS, suffix
            assert any(suffix in line for line in page if line.lstrip(" *").startswith(name + " "))
            seen += 1
    assert seen, "the fixture carries at least one destination state"


def test_every_glyph_the_page_prints_is_in_the_legend():
    """MUTATION: print a symbol the legend does not name (a new status mark) and it shows up here.

    The unbudgeted page also draws the stacks' pictures, whose connectors are box drawing (U+2500 to U+257F): those are
    geometry rather than vocabulary, so they are the one family exempted, on `--full` only.
    """
    named = {glyph for glyph, _ in render.GLYPH_LEGEND} | _STRUCTURE
    document = _queen(stacks=3, waiting=5)
    document["cortex_pending"] = [{"project": "widgets", "reset_at": "x", "countdown": "1h 0m"}]
    document["projects"]["gadgets"]["repo"] = "common"
    document["projects"]["widgets"]["repo"] = "common"
    for full in (False, True):
        symbols = {ch for ch in plain(render.document(document, full=full)) if unicodedata.category(ch) == "So"}
        if full:
            symbols = {ch for ch in symbols if not "\u2500" <= ch <= "\u257f"} | (symbols & named)
        assert symbols <= named, symbols - named
    compact = {ch for ch in plain(render.document(document)) if unicodedata.category(ch) == "So"}
    assert {"▶", "⏸", "└"} <= compact, "the fixture exercises the page's own marks"


def test_the_page_says_how_many_stacks_and_directives_and_how_to_see_them():
    page = plain(render.document(_queen(stacks=40, directives=200)))
    assert "▸ STACKS  40 stacks" in page and "▸ QUEUED  200 directives" in page
    assert page.count(render.EXPAND_COMMAND) >= 2
    assert render.EXPAND_COMMAND == "borg link --overview --full"


def test_full_prints_every_stack_and_every_directive():
    document = _queen(stacks=40, directives=200)
    full = plain(render.document(document, full=True))
    assert all(f"stack-{n}" in full for n in range(40))
    assert full.count("Directive ") == 200
    assert len(full.split("\n")) > 800, "the unbudgeted page is the long one, and it is only asked for by name"


def test_the_compact_page_is_the_full_page_with_the_same_sections_in_the_same_order():
    document = _queen(stacks=5)
    titles = [title for title, _ in render.SECTIONS]
    assert titles == [title for title, _ in render.FULL_SECTIONS]
    def heads(page):
        return [
            line.split("  ")[0] for line in plain(page).split("\n") if line.startswith(render.SECTION_MARK)
        ]
    assert heads(render.document(document)) == heads(render.document(document, full=True))


def test_waiting_on_you_prints_two_rows_and_counts_the_rest_on_one_line():
    page = plain(render.document(_queen(stacks=1, waiting=40))).split("\n")
    start = next(i for i, line in enumerate(page) if line.startswith("▸ WAITING ON YOU"))
    body = [line for line in page[start + 1 :] if line.strip()]
    assert sum("▶" in line for line in body) == 2
    assert sum("parking:" in line for line in body) == 1, "a due parked thought keeps one of the two slots"
    more = next(line for line in body if "more" in line)
    assert more.strip().startswith("+") and "borg next" in more
    assert "+5 more decisions" in more and "+9 agent tasks" in more, "the chooser's hidden counts share the line"
    assert body[-1].startswith("  next  "), "the page still ends on the next action"


def test_three_state_honesty_survives_the_compact_page():
    """S1's rule: never claim nothing when nobody looked. An unswept board says so in NEXT and WAITING ON YOU."""
    document = _queen(stacks=0)
    document["compass"] = _compass(parking=None)
    unlooked = link_grid.grid_manifest(fork_manifest() | {"_id": "u"}, {}, {})
    document["grid"].update(
        {"manifests": [unlooked], "declared": len(unlooked["nodes"]), "unresolved": 7, "swept": False}
    )
    page = plain(render.document(document))
    assert "▸ NEXT  nobody looked" in page
    assert "▸ WAITING ON YOU  nobody looked" in page
    assert "nothing waits on you" not in page


def test_an_empty_grid_still_says_why_rather_than_collapsing_to_a_count():
    page = plain(render.document(_queen(stacks=0)))
    assert "no stack manifests in the registry yet" in page
    assert render.EXPAND_COMMAND not in page.split("▸ STACKS")[1].split("▸ QUEUED")[0]


def test_signals_past_the_cap_are_counted_and_the_ladders_gap_stays_last():
    page = plain(render.document(_queen(stacks=1))).split("\n")
    start = next(i for i, line in enumerate(page) if line.startswith("▸ SIGNALS"))
    assert "signals · borg link --overview --full" in page[start]
    body = [line for line in page[start + 1 :] if line.strip()][:3]
    assert body[-1].strip() == "— 18 of 18 declared refs resolved." or "declared refs resolved" in body[-1]


def test_every_repository_stays_on_the_board_at_forty_repositories():
    """L4 (idle collapse) was rejected: the board is the one section whose length is the registry's."""
    page = plain(render.document(_queen(stacks=1, repositories=40)))
    assert len([line for line in page.split("\n") if _BOARD_ROW.match(line)]) == 40
    assert len(_outside_repositories(render.document(_queen(stacks=1, repositories=40)))) <= 30


def test_the_page_ends_on_its_last_line_and_not_on_a_blank():
    assert not render.document(_queen(stacks=1)).endswith("\n\n")


def test_the_directory_page_is_untouched_by_the_flag_and_by_the_budget():
    """Out of scope: REPOSITORY_SECTIONS, and the one waiting builder it shares, behave as they did."""
    document = _repository_doc()
    assert render.document(document) == render.document(document, full=True)
    assert render._sections_for(document) is render.REPOSITORY_SECTIONS  # pylint: disable=protected-access


def test_full_flag_is_parsed_and_changes_no_wire_key():
    assert cli._build_parser().parse_args(["--overview", "--full"]).full is True  # pylint: disable=protected-access
    assert cli._build_parser().parse_args([]).full is False  # pylint: disable=protected-access
    assert link_core.DOCUMENT_VERSION == 2


class TestFitLine:
    """`_fit_line` cuts at a visible width and never through an escape."""

    def test_a_line_within_the_limit_is_returned_unchanged(self):
        line = f"{picture.BOLD}short{picture.NC}\n"
        assert render._fit_line(line, 100) == line  # pylint: disable=protected-access

    def test_a_long_line_ends_in_an_ellipsis_at_the_limit_in_visible_columns(self):
        line = f"  {picture.DIM}{'x' * 300}{picture.NC}\n"
        cut = render._fit_line(line, 40)  # pylint: disable=protected-access
        assert picture.visible_len(cut.rstrip("\n")) == 40 and plain(cut).endswith("…\n")

    def test_an_osc8_link_is_never_cut_through_and_is_closed(self):
        link = picture.link_ref("example/repo#1", "example/repo#1")
        cut = render._fit_line(f"{link}  " + "y" * 200 + "\n", 30)  # pylint: disable=protected-access
        assert cut.count("\033]8;;") == 2, "the link closed before the cut, so the cut adds no escape of its own"
        assert plain(cut).startswith("example/repo#1  y")
        inside = render._fit_line(f"{link}\n", 8)  # pylint: disable=protected-access
        assert plain(inside) == "example…\n" and inside.endswith("\033]8;;\033\\\n")

    def test_a_cut_line_resets_its_colour(self):
        cut = render._fit_line(f"{picture.YELLOW}{'z' * 200}\n", 20)  # pylint: disable=protected-access
        assert picture.NC in cut
        assert "\033]8" not in cut, "a line with no link gains no link escape (NO_COLOR parity)"

    def test_text_is_cut_line_by_line_including_blank_lines(self):
        text = "a" * 150 + "\n\nbb\n"
        fitted = render._fit_text(text, 50)  # pylint: disable=protected-access
        assert [picture.visible_len(line) for line in fitted.split("\n")] == [50, 0, 2, 0]
