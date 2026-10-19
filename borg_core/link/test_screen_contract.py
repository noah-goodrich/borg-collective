"""The screen contract for the Queen's page (doorways S2, AC2): it fits one screen however much exists.

These read the limits and the words from `render` (`PAGE_LINES`, `PAGE_COLUMNS`, `GLYPH_LEGEND`, `STATUS_WORDS`), so
the contract and the page cannot drift apart. The two limits are ALSO asserted as the literals the directive approved
(30 and 100): a constant edited to make the page pass would otherwise take the test with it.

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


def test_waiting_on_you_prints_four_rows_and_counts_the_rest_on_one_line():
    page = plain(render.document(_queen(stacks=1, waiting=40))).split("\n")
    start = next(i for i, line in enumerate(page) if line.startswith("▸ WAITING ON YOU"))
    body = [line for line in page[start + 1 :] if line.strip()]
    assert sum("▶" in line for line in body) == 4
    assert sum("parking:" in line for line in body) == 1, "a due parked thought keeps one of the four slots"
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


def test_waiting_on_you_shows_as_many_rows_as_the_chooser_offers():
    """The board and `/borg-next` read the same rows, so the cap is pinned to the skill's own option count."""
    skill = (Path(__file__).resolve().parents[2] / "skills" / "borg-next" / "SKILL.md").read_text()
    match = re.search(r"up to (\d+) options", skill)
    assert match, "the chooser skill states its option count"
    assert render.CHOOSER_OPTIONS == int(match.group(1)) == render._WAITING_CAP  # pylint: disable=protected-access


def test_the_next_action_line_never_cuts_its_command_and_waiting_rows_never_cut_their_ref():
    """The action line holds the literal, runnable command. A long owner/repo makes the full ref too wide for the
    page, so the label is `#N` (and is cut in its middle when even that does not fit) and the command is whole."""
    owner = "an-organisation-name/a-repository-name-quite-long"
    ref = f"{owner}#12345"
    row = {"project": "p" * 30, "item": "t" * 200, "next_step": "merge", "owner": "YOU", "ref": ref}
    document = _queen(stacks=1, waiting=0)
    document["waiting"] = {"rows": [row], "hidden": {}, "hidden_lines": [], "degraded": None}
    page = plain(render.document(document)).split("\n")
    last = [line for line in page if line.strip()][-1]
    command = render._next_action_command(ref)  # pylint: disable=protected-access
    assert command == f"gh pr view 12345 -R {owner}"
    assert last.endswith(command) and picture.visible_len(last) <= 100
    assert last.startswith("  next  #12345")
    waiting = next(line for line in page if "▶" in line and "#12345" in line)
    assert "#12345" in waiting and picture.visible_len(waiting) <= 100 and waiting.rstrip().endswith("…")
    # A non-GitHub label too long for the line is cut in the middle, never the command.
    document["waiting"]["rows"] = [{**row, "ref": "", "item": "s" * 150}]
    tail = [line for line in plain(render.document(document)).split("\n") if line.strip()][-1]
    assert tail.endswith("borg next") and picture.visible_len(tail) <= 100


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
    assert max(picture.visible_len(line) for line in painted.split("\n")) <= 100


def test_the_repository_page_cuts_free_text_with_an_ellipsis_and_keeps_every_other_line_whole():
    page = plain(render.document(_painted_repository_doc()))
    cut = [line for line in page.split("\n") if line.endswith("…")]
    assert any("tl;dr" in line for line in cut), "the 302-column checkpoint line is cut"
    assert all(picture.visible_len(line) <= 100 for line in page.split("\n"))
    assert "short" in page and "borg link --overview" in page


def test_the_repository_page_never_cuts_a_command_or_a_ref():
    """The pointer line and the waiting row hold literal commands and refs. They are not free text, so the fit
    does not touch them, even where they are wider than the page (here a path past 100 columns)."""
    ref = "an-organisation-name/a-repository-name-quite-long#12345"
    long_path = "/ws/" + "deeply-nested-directory/" * 6 + "p"
    document = _painted_repository_doc()
    document["focus"]["entry"]["path"] = long_path
    document["waiting"] = {
        "rows": [{"project": "p", "item": "session", "next_step": f"gh pr view -R {ref}", "owner": "YOU", "ref": None}],
        "hidden": {},
        "hidden_lines": [],
        "degraded": None,
    }
    page = plain(render.document(document))
    assert long_path in page, "a path is a ref, never cut"
    assert "borg link --overview" in page
    assert f"gh pr view -R {ref}" in page


def test_the_repository_page_never_cuts_the_map_directory_in_its_no_map_line():
    document = _painted_repository_doc()
    map_dir = "/ws/" + "a-deeply-nested-map-directory/" * 5 + "map"
    document["compass"] = {"found": False, "map_dir": map_dir}
    page = plain(render.document(document))
    line = next(line for line in page.split("\n") if "Compass: no map at" in line)
    assert line.strip().endswith(map_dir) and picture.visible_len(line) > 100
