"""The screen contract for the Queen's page (doorways S2, AC2): it fits one screen however much exists.

These read the limits and the words from `render` (`PAGE_LINES`, `PAGE_COLUMNS`, `GLYPH_LEGEND`, `STATUS_WORDS`), so
the contract and the page cannot drift apart. The two limits are ALSO asserted as literals (30, and 98 columns, within the directive's approved 100): a constant edited to make the page pass would otherwise take the test with it.

EVERY FIXTURE IS SYNTHETIC. The live board carries private-repository titles and this repository is public.
"""

import copy
from pathlib import Path
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
            "hidden_lines": ["+5 more decisions", "+9 agent tasks", "+4 unowned", "+2 stale drafts"] if waiting else [],
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
    assert render.PAGE_COLUMNS == 98
    lines = page.split("\n")
    assert all(picture.visible_len(line) <= 98 for line in lines), [
        (picture.visible_len(line), plain(line)) for line in lines if picture.visible_len(line) > 98
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
    assert picture.visible_len(row) <= 98
    assert long_name in plain(render.document(doc, full=True)), "--full prints the name whole"


def test_the_legend_is_one_line_and_names_every_glyph_in_the_closed_set():
    page = plain(render.document(_queen(stacks=1))).split("\n")
    legend = [line for line in page if "merged" in line and "worktree" in line]
    assert len(legend) == 1
    for glyph, word in render.GLYPH_LEGEND:
        assert f"{glyph} {word}" in legend[0]
    assert picture.visible_len(legend[0]) <= 98


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
        return [line.split("  ")[0] for line in plain(page).split("\n") if line.startswith(render.SECTION_MARK)]

    assert heads(render.document(document)) == heads(render.document(document, full=True))


def test_waiting_on_you_prints_four_rows_and_counts_the_rest_on_one_line():
    page = plain(render.document(_queen(stacks=1, waiting=40))).split("\n")
    start = next(i for i, line in enumerate(page) if line.startswith("▸ WAITING ON YOU"))
    body = [line for line in page[start + 1 :] if line.strip()]
    assert sum("▶" in line for line in body) == 4
    assert sum("parking:" in line for line in body) == 1, "a due parked thought keeps one of the four slots"
    more = next(line for line in body if "more" in line)
    assert more.strip().startswith("+") and "borg next" in more
    assert "+5 more decisions" in more and "+9 agent tasks" in more, "the chooser's hidden counts share the line"
    assert "+9 agent tasks · +4 unowned · +2 stale drafts" in more, "unowned sits between agent tasks and stale drafts"
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
    body = [line for line in page[start + 1 :] if line.strip()][:2]
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
    assert render._sections_for(document)[0] is render.REPOSITORY_SECTIONS  # pylint: disable=protected-access


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


def test_waiting_on_you_shows_as_many_rows_as_the_chooser_offers():
    """The board and `/borg-next` read the same rows, so the cap is pinned to the skill's own option count."""
    skill = (Path(__file__).resolve().parents[2] / "skills" / "borg-next" / "SKILL.md").read_text()
    match = re.search(r"up to (\d+) options", skill)
    assert match, "the chooser skill states its option count"
    assert render.CHOOSER_OPTIONS == int(match.group(1))


def test_the_next_action_line_never_cuts_its_command_and_waiting_rows_never_cut_their_ref():
    """The action line holds the literal, runnable command. A long owner/repo makes the full ref too wide for the
    page, so the label is `#N` (and is cut in its middle when even that does not fit) and the command is whole."""
    owner = "an-organisation-name/a-repository-name-quite-long"
    ref = f"{owner}#12345"
    row = {"project": "p" * 30, "item": "t" * 200, "next_step": "merge", "owner": "YOU", "ref": ref}
    document = _queen(stacks=1, waiting=0)
    document["waiting"] = {"rows": [row], "hidden": {}, "hidden_lines": [], "degraded": None}
    page = plain(render.document(document)).split("\n")
    block = page[next(i for i, line in enumerate(page) if line.startswith("  next  ")) :]
    block = [line for line in block if line.strip()]
    command = render._next_action_command(ref)  # pylint: disable=protected-access
    assert command == f"gh pr view 12345 -R {owner}"
    flat = " ".join(" ".join(block).split())
    assert block[-1].strip() == command and picture.visible_len(block[-1]) <= 98
    assert block[0].startswith("  next  #12345") and f"({'p' * 30})" in flat and "…" not in flat
    waiting = next(line for line in page if "▶" in line and "#12345" in line)
    assert "#12345" in waiting and picture.visible_len(waiting) <= 98 and waiting.rstrip().endswith("…")
    # A non-GitHub label too long for the line wraps whole (AC5), and the command is still the last thing on the page.
    document["waiting"]["rows"] = [{**row, "ref": "", "item": "session", "next_step": "s" * 150}]
    tail = [line for line in plain(render.document(document)).split("\n") if line.strip()]
    assert tail[-1].endswith("borg next") and all(picture.visible_len(line) <= 98 for line in tail)
    assert "s" * 150 in "".join(line.strip() for line in tail[-3:])


# ── Doorways S3 (AC3): the page is painted verbatim, so both scopes must fit the paint ───────────────────────────


def _painted_repository_doc(**overrides) -> dict:
    """A directory's document whose free text is far wider than the page: a 302-column checkpoint line, a long
    summary, a long leg and a long scope label, the shapes the live repository page held on 2026-10-19."""
    head = "tl;dr: " + "a checkpoint line that runs on and on " * 8 + "\n" + "- " + "y" * 150 + "\nshort"
    focus = {
        "name": "p",
        "entry": {"path": "/ws/p", "status": "idle", "summary": "s" * 400, "claude_session_id": "abc"},
        "identity": {"kind": "main", "branch": "main"},
        "plan": None,
        "checkpoints": ["2026-10-19-101627-0e958b.md"],
        "checkpoint_head": head,
        "directives": [],
        "assimilated": [],
    }
    return _repository_doc(focus=focus, **overrides)


@pytest.mark.parametrize("scope", ["queen", "repository"])
def test_the_painted_page_has_no_escape_byte_and_no_line_over_a_hundred_columns(scope):
    """AC3: the skill injects `NO_COLOR=1 borg link`, and the model reproduces it in a fenced block. An ESC byte
    there is mojibake on the user's screen, and a line past 100 columns wraps and breaks the fence's alignment."""
    document = _queen(stacks=3, waiting=2) if scope == "queen" else _painted_repository_doc()
    coloured = render.document(document)
    assert "\033" in coloured, "the fixture must carry escapes, or the assertion below proves nothing"
    painted = cli._page(coloured, False)  # pylint: disable=protected-access
    assert "\033" not in painted
    assert max(picture.visible_len(line) for line in painted.split("\n")) <= 98


def test_the_queen_boards_table_rows_cut_free_text_with_an_ellipsis_and_keep_every_other_line_whole():
    """AC5 narrowed this from the repository page to the Queen's board rows (Non-Goal: the table rows keep their cut)."""
    page = plain(render.document(_queen(stacks=1, waiting=2)))
    lines = page.split("\n")
    rows = [line for line in lines if _BOARD_ROW.match(line)]
    assert rows and all(line.endswith("…") for line in rows), "every board row's long summary is cut"
    assert all(picture.visible_len(line) <= 98 for line in lines)


def test_the_repository_page_cuts_nothing_and_shows_fewer_things():
    """AC5: the 302-column checkpoint line, the 400-character summary and the fields are no longer on the page."""
    page = plain(render.document(_painted_repository_doc()))
    assert "…" not in page.replace("(p)", "") or page.count("…") == 1  # only the waiting row's own clip may remain
    assert all(picture.visible_len(line) <= 98 for line in page.split("\n"))
    for left in ("tl;dr", "Source:", "Path:", "tmux window:", "Session ID:", "Recent Checkpoints", "2026-10-19-101627"):
        assert left not in page, left
    assert "s" * 400 in page.replace("\n", "").replace(" ", ""), "the summary is whole across wrapped lines"
    assert "borg link --overview" in page


def test_the_repository_page_never_cuts_a_command_or_a_ref():
    """The pointer line, the waiting row and the parent repository hold literal commands and refs. They are not free
    text, so the fit does not touch them, even where they are wider than the page (here a path past 100 columns)."""
    ref = "an-organisation-name/a-repository-name-quite-long#12345"
    long_path = "/ws/" + "deeply-nested-directory/" * 6 + "p"
    document = _painted_repository_doc()
    document["focus"]["identity"] = {"kind": "worktree", "branch": "b", "worktree_of": long_path}
    document["waiting"] = {
        "rows": [{"project": "p", "item": "session", "next_step": f"gh pr view -R {ref}", "owner": "YOU", "ref": None}],
        "hidden": {},
        "hidden_lines": [],
        "degraded": None,
    }
    page = plain(render.document(document))
    assert f"Worktree of:  {long_path}\n" in page, "a path is a ref, never cut"
    assert "borg link --overview" in page
    assert f"gh pr view -R {ref}" in page


def test_the_repository_page_never_cuts_the_map_directory_in_its_no_map_line():
    document = _painted_repository_doc()
    map_dir = "/ws/" + "a-deeply-nested-map-directory/" * 5 + "map"
    document["compass"] = {"found": False, "map_dir": map_dir}
    page = plain(render.document(document))
    line = next(line for line in page.split("\n") if "Compass: no map at" in line)
    assert line.strip().endswith(map_dir) and picture.visible_len(line) > 100


# ── AC4 of 2026-10-20-one-owned-next-list: every "next" surface reads ONE document and none contradicts it ────────

_YOU_CHECKPOINT = (
    "tl;dr synthetic\n\n## 4. Blockers\n\nWaits on you:\n- Approve the invented budget\n\n"
    "## 5. Next Session\n\n1. Build the synthetic widget\n"
)
_NEXT_ONLY_CHECKPOINT = (
    "tl;dr synthetic\n\n## 4. Blockers\n\nNo blockers.\n\n## 5. Next Session\n\n1. Build the synthetic widget\n"
)


def _checkpoint_documents(tmp_path, monkeypatch, text: str) -> tuple[dict, dict]:
    """`(repository page document, Queen page document)` built over ONE registry whose only data is a checkpoint file.

    THE ROWS COME THROUGH THE REAL PATH: the file is written to disk and read by `nextpick.shell`, then built into
    `waiting` by `link.cli._waiting` (the function `borg link` calls). Nothing here hands in a derived value.
    """
    from borg_core.link.test_render import _focus  # pylint: disable=import-outside-toplevel

    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", str(tmp_path / "no-queen"))
    store = tmp_path / "p" / ".borg" / "checkpoints"
    store.mkdir(parents=True)
    name = "2026-10-19-162310-abcdef.md"
    (store / name).write_text(text)
    entry = {"status": "idle", "last_activity": "2026-10-19", "path": str(tmp_path / "p")}
    repositories = {"p": entry}
    repo_scope = {"kind": "repository", "repository": "p", "local": True}
    queen_scope = {"kind": "orchestrator", "repository": None, "local": True}
    shown = {**entry, "relative_activity": "3h ago", "summary": "synthetic"}
    focus = _focus(name="p", entry=shown, checkpoints=[name], checkpoint_head=text)
    repository_doc = _repository_doc(
        focus=focus,
        projects={"p": shown},
        waiting=cli._waiting(repositories, repo_scope, True, []),  # pylint: disable=protected-access
    )
    queen_doc = _doc(projects={"p": shown}, waiting=cli._waiting(repositories, queen_scope, True, []))  # pylint: disable=protected-access
    return repository_doc, queen_doc


def _last_line(page: str) -> str:
    return [line for line in plain(page).split("\n") if line.strip()][-1].strip()


def test_a_you_row_in_the_checkpoint_is_never_called_nothing_by_the_page_the_glance_line_or_the_brief(
    tmp_path, monkeypatch
):
    """MUTATION: let `_next_action_line` fall straight to "nothing is ready" and the page and the brief go red."""
    from borg_core.link import arrival  # pylint: disable=import-outside-toplevel

    repository_doc, queen_doc = _checkpoint_documents(tmp_path, monkeypatch, _YOU_CHECKPOINT)
    assert [r["owner"] for r in queen_doc["waiting"]["rows"]] == ["YOU"], "the file reached the document as a YOU row"
    pages = [plain(render.document(repository_doc)), plain(render.document(queen_doc))]
    glance = render.glance_line(queen_doc, False)
    brief = arrival.brief(repository_doc)
    for surface in (*pages, glance or "", brief):
        assert "nothing is ready" not in surface and "nothing waits on you" not in surface, surface
    assert glance is not None and "Approve the invented budget" in glance
    assert "Approve the invented budget" in _last_line(render.document(queen_doc))
    next_line = next(line for line in brief.split("\n") if line.startswith(" next"))
    assert "Approve the invented budget" in next_line and next_line.endswith("owner: yours")


def test_a_checkpoint_with_only_a_next_session_item_gives_every_surface_that_item_and_an_owner(tmp_path, monkeypatch):
    """Nothing WAITS on the reader here (the item is an agent's), so `nothing waits on you` is true and allowed;
    `nothing is ready` is not, because the document holds a next item. MUTATION: drop `waiting.next` from the
    document and the page's last line and the brief's next line both say `nothing is ready`."""
    from borg_core.link import arrival  # pylint: disable=import-outside-toplevel

    repository_doc, queen_doc = _checkpoint_documents(tmp_path, monkeypatch, _NEXT_ONLY_CHECKPOINT)
    assert queen_doc["waiting"]["rows"] == [], "an AGENT item is not a YOU row"
    assert queen_doc["waiting"]["next"]["owner"] == "AGENT"
    pages = [render.document(repository_doc), render.document(queen_doc)]
    glance = render.glance_line(queen_doc, False)
    brief = arrival.brief(repository_doc)
    for surface in (*(plain(page) for page in pages), glance or "", brief):
        assert "nothing is ready" not in surface, surface
    for page in pages:
        assert "Build the synthetic widget" in _last_line(page)
    next_line = next(line for line in brief.split("\n") if line.startswith(" next"))
    assert "Build the synthetic widget" in next_line and next_line.endswith("owner: mine")
    assert len(next_line) <= render.PAGE_COLUMNS


def test_an_empty_checkpoint_still_says_nothing_is_ready_and_carries_no_owner(tmp_path, monkeypatch):
    """The phrase stays legitimate when the document holds no YOU row and no next item."""
    from borg_core.link import arrival  # pylint: disable=import-outside-toplevel

    repository_doc, queen_doc = _checkpoint_documents(
        tmp_path, monkeypatch, "tl;dr synthetic\n\n## 4. Blockers\n\nNo blockers.\n\n## 5. Next Session\n\nnone\n"
    )
    assert queen_doc["waiting"]["next"] is None
    assert _last_line(render.document(repository_doc)) == "next  nothing is ready  borg next"
    brief_next = next(line for line in arrival.brief(repository_doc).split("\n") if line.startswith(" next"))
    assert "nothing is ready" in brief_next and "owner:" not in brief_next


# ── AC5 of 2026-10-20-one-owned-next-list: the repository page shows fewer things, whole ──────────────────────────


def _words(count: int, stem: str = "word") -> str:
    return " ".join(f"{stem}{n}" for n in range(count))


def _wide_checkpoint(waits: list[str], nexts: list[str]) -> str:
    return (
        "tl;dr synthetic\n\n## 4. Blockers\n\nWaits on you:\n"
        + "".join(f"- {text}\n" for text in waits)
        + "\n## 5. Next Session\n\n"
        + "".join(f"{n}. {text}\n" for n, text in enumerate(nexts, start=1))
    )


def _item_lines(page: str, heading: str) -> list[str]:
    """The lines under `heading` on a plain page, up to the next blank line."""
    lines = page.split("\n")
    start = lines.index(f"  {heading}") + 1
    end = next((i for i in range(start, len(lines)) if not lines[i].strip()), len(lines))
    return lines[start:end]


def test_a_three_hundred_character_wait_item_renders_whole_across_wrapped_lines(tmp_path, monkeypatch):
    """AC5. The item travels the real path (a file on disk, `nextpick.shell`, `link.cli._waiting`). MUTATION: put
    `_fit_text` back over the list and the item ends in an ellipsis; drop the wrap and one line passes 98 columns."""
    item = " ".join(f"tok{n:02d}" for n in range(50))
    assert len(item) == 299
    repository_doc, _ = _checkpoint_documents(tmp_path, monkeypatch, _wide_checkpoint([item], ["Build the widget"]))
    page = plain(render.document(repository_doc))
    block = _item_lines(page, "Waits on you")
    assert len(block) >= 4 and block[0].startswith("  1 ")
    assert all(line.startswith("    ") for line in block[1:]), "a hanging indent under the text"
    assert " ".join(" ".join(block).replace("1 ", "", 1).split()) == item
    assert "…" not in page and all(picture.visible_len(line) <= render.PAGE_COLUMNS for line in page.split("\n"))
    assert "Next · AGENT" in page and "  1 Build the widget" in page


def test_the_page_caps_items_by_whole_items_and_counts_the_rest_with_the_command_that_prints_them(
    tmp_path, monkeypatch
):
    waits = [_words(40, f"w{n}x") for n in range(4)]
    nexts = [f"Next number {n} {_words(20, 'n')} end{n}" for n in range(5)]
    repository_doc, _ = _checkpoint_documents(tmp_path, monkeypatch, _wide_checkpoint(waits, nexts))
    page = plain(render.document(repository_doc))
    block_w, block_n = _item_lines(page, "Waits on you"), _item_lines(page, "Next · AGENT")
    shown = block_w + block_n
    assert len(shown) <= render.PAGE_ITEM_LINES + len(block_n), "the budget holds (the Next list keeps its first item)"
    kept_w = sum(1 for line in block_w if re.match(r"^  \d ", line))
    kept_n = sum(1 for line in block_n if re.match(r"^  \d ", line))
    more = next(line for line in page.split("\n") if "more" in line and "borg link --full" in line)
    assert more.strip() == f"+{len(waits) + len(nexts) - kept_w - kept_n} more  borg link --full"
    for items, block, kept in ((waits, block_w, kept_w), (nexts, block_n, kept_n)):
        joined = " ".join(" ".join(block).split())
        for index, item in enumerate(items):
            assert (item in joined) == (index < kept), "an item is whole or absent, never cut"
            assert (index < kept) or item.split()[-1] not in joined.split()
    assert 0 < kept_w < len(waits) and kept_n >= 1
    assert "…" not in page
    full = plain(render.document(repository_doc, full=True))
    assert "more  borg link --full" not in full
    assert sum(1 for line in full.split("\n") if re.match(r"^  \d ", line)) == len(waits) + len(nexts)
    assert all(picture.visible_len(line) <= render.PAGE_COLUMNS for line in full.split("\n"))


def test_the_first_item_of_each_list_is_kept_even_when_the_budget_is_spent(tmp_path, monkeypatch):
    waits = [_words(400, "a"), _words(10, "b")]
    repository_doc, _ = _checkpoint_documents(tmp_path, monkeypatch, _wide_checkpoint(waits, ["Still shown"]))
    page = plain(render.document(repository_doc))
    assert len(_item_lines(page, "Waits on you")) > render.PAGE_ITEM_LINES, "one long item is never cut to fit"
    assert "  1 Still shown" in page and "+1 more  borg link --full" in page


def test_the_repository_page_stays_on_one_screen_with_busy_lists(tmp_path, monkeypatch):
    waits = [_words(35, f"w{n}") for n in range(12)]
    nexts = [_words(35, f"n{n}") for n in range(12)]
    repository_doc, _ = _checkpoint_documents(tmp_path, monkeypatch, _wide_checkpoint(waits, nexts))
    repository_doc["focus"]["entry"]["summary"] = _words(45, "last")
    assert 280 <= len(repository_doc["focus"]["entry"]["summary"]) <= 340
    lines = plain(render.document(repository_doc)).split("\n")
    # The worst page the budget allows: 5 identity lines, a 4-line `Last time`, 8 item lines plus the first Next item
    # the budget always keeps, their headings, the count line, the pointer and a 4-line WAITING ON YOU. A number
    # edited to make the page pass would hide a lost cap, so it is a literal here.
    assert len(lines) <= 34, len(lines)


def test_the_page_fields_leave_but_the_document_keeps_every_key(tmp_path, monkeypatch):
    repository_doc, _ = _checkpoint_documents(tmp_path, monkeypatch, _wide_checkpoint(["Wait one"], ["Do one"]))
    focus = repository_doc["focus"]
    focus["entry"].update({"tmux_window": "w", "claude_session_id": "sid", "source": "cli"})
    before = copy.deepcopy(repository_doc)
    page = plain(render.document(repository_doc))
    for left in ("Source:", "Path:", "tmux window:", "Session ID:", "Checkpoints", ".md", "tl;dr"):
        assert left not in page, left
    assert repository_doc == before, "rendering reads the document and never edits it"
    assert focus["checkpoints"] and focus["checkpoint_head"] and focus["entry"]["claude_session_id"] == "sid"


def test_waiting_on_you_does_not_contradict_the_listed_wait_items(tmp_path, monkeypatch):
    repository_doc, _ = _checkpoint_documents(tmp_path, monkeypatch, _wide_checkpoint(["Wait one"], ["Do one"]))
    page = plain(render.document(repository_doc))
    assert "  1 Wait one" in page and "nothing waits on you" not in page and "nothing here waits" not in page
    assert "what waits on you is listed above" in page


def test_checkpoint_rows_on_the_queen_page_are_named_by_their_repository_not_session(tmp_path, monkeypatch):
    """Defect 2a. A checkpoint wait item has no ref and no item of its own; the renderer called it `session`.
    MUTATION: restore `or "session"` in `_chooser_item` and the row reads `▶ session`."""
    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", str(tmp_path / "queen-root"))
    store = tmp_path / "queen-root" / ".borg" / "checkpoints"
    store.mkdir(parents=True)
    (store / "2026-10-19-162310-abcdef.md").write_text(_wide_checkpoint(["Pick the synthetic colour"], ["Go"]))
    queen_doc = _doc(waiting=cli._waiting({}, {"kind": "orchestrator", "repository": None, "local": True}, True, []))  # pylint: disable=protected-access
    page = plain(render.document(queen_doc))
    row = next(line for line in page.split("\n") if "Pick the synthetic colour" in line and "▶" in line)
    assert "queen" in row and "session" not in row
    assert "session" not in page


def test_the_queen_page_waiting_on_you_shows_queen_rows_when_one_repository_has_six_you_rows(tmp_path, monkeypatch):
    """AC7. MUTATION: take the first five YOU rows in rank order again and the Queen's two rows vanish from the page."""
    root = tmp_path / "queen-root"
    (root / ".borg" / "checkpoints").mkdir(parents=True)
    queen_text = "tl;dr synthetic\n\n## 4. Blockers\n\nWaits on you:\n- Rotate the invented credential\n\n## 5. Next Session\n\n1. Go\n"
    (root / ".borg" / "checkpoints" / "2026-10-20-090000-abcdef.md").write_text(queen_text)
    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", str(root))
    store = tmp_path / "p" / ".borg" / "checkpoints"
    store.mkdir(parents=True)
    waits = "".join(f"- Decide invented thing {n}\n" for n in range(1, 7))
    (store / "2026-10-19-162310-abcdef.md").write_text(
        f"tl;dr synthetic\n\n## 4. Blockers\n\nWaits on you:\n{waits}\n## 5. Next Session\n\n1. Go\n"
    )
    entry = {"status": "idle", "last_activity": "2026-10-19", "path": str(tmp_path / "p")}
    queen_scope = {"kind": "orchestrator", "repository": None, "local": True}
    waiting = cli._waiting({"p": entry}, queen_scope, True, [])  # pylint: disable=protected-access
    assert [r["project"] for r in waiting["rows"]] == ["p", "p", "p", "p", "queen"]
    page = plain(
        render.document(_doc(projects={"p": {**entry, "relative_activity": "3h ago", "summary": "s"}}, waiting=waiting))
    )
    assert "Rotate the invented credential" in page
