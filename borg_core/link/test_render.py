"""Unit tests for borg_core.link.render -- the one human document and the untouched porcelain TSV.

These pin the sub-behaviours a byte-exact golden diff cannot localize: which branch fired, which
default applied, where a fold broke, which of three diagnoses a placeholder chose. The goldens under
tests/fixtures/link/ remain the primary oracle (exercised end to end via tests/cli_contract.bats);
these are the microscope.
"""

import ast
import datetime
import inspect
import json
import os
import re
import shutil
import subprocess
import time
from pathlib import Path

import pytest

from borg_core.link import cli, core as link_core, picture, render
from borg_core.link import grid as link_grid
from borg_core.manifest import core as manifest_core
from borg_core.manifest import shell as manifest_shell
from borg_core.link.test_picture import fork_manifest, plain


def _doc(**overrides) -> dict:
    base = {
        "total_projects": 0,
        "order": [],
        "projects": {},
        "directives": [],
        "assimilated": [],
        "cortex_pending": [],
        "capacity": {"active": 0, "limit": 3, "over_limit": False},
        "focus": None,
        "scope": {"kind": "orchestrator", "repository": None, "local": False},
        "grid": {
            "slug": "",
            "scope_kind": "orchestrator",
            "swept": False,
            "since": "",
            "sources": [],
            "fetch": {"attempted": False, "status": "skipped", "requested": 0, "resolved": 0},
            "manifests": [],
            "declared": 0,
            "unresolved": 0,
            "picture_width": 0,
            "warnings": [],
        },
    }
    base.update(overrides)
    # SUMMARY IS FLATTENED HERE BECAUSE THE REAL DOCUMENT FLATTENS IT HERE. `core.assemble` applies
    # `flatten_summary` once, at the chokepoint, so a fixture handing a renderer a raw control
    # character tests a state no document can produce. Mirroring the one line rather than calling
    # `assemble` keeps `_doc`'s shape overridable field by field, which most cases rely on.
    repositories = base.get("projects")
    if isinstance(repositories, dict):
        base["projects"] = {
            name: (
                {**entry, "summary": link_core.flatten_summary(entry["summary"])}
                if isinstance(entry, dict) and isinstance(entry.get("summary"), str)
                else entry
            )
            for name, entry in repositories.items()
        }
    return base


def _full(doc: dict) -> str:
    """The Queen's page with no budget (`--full`): what the tests that pin a section's UNBUDGETED form read. The
    budgeted page is pinned by `test_screen_contract.py`; a directory's page ignores the flag."""
    return render.document(doc, full=True)


def _focus(**overrides) -> dict:
    base: dict = {
        "name": "p",
        "entry": {"path": "null"},
        "plan": None,
        "checkpoints": [],
        "checkpoint_head": "",
        "directives": [],
        "assimilated": [],
    }
    base.update(overrides)
    return base


def _repository_doc(**overrides) -> dict:
    overrides.setdefault("focus", _focus())
    overrides["scope"] = {"kind": "repository", "repository": "p", "local": False}
    return _doc(**overrides)


def _headers(rendered: str) -> list[str]:
    """The ordered `▸ ` section TITLES in a rendering, ANSI stripped and shorn of their dim notes.

    The note is separated from the title by two spaces and is context-dependent by design (a row
    count, a sweep mark); the TITLE is what must be byte-identical in both contexts.
    """
    return [
        line[len(render.SECTION_MARK) :].split("  ")[0]
        for line in plain(rendered).split("\n")
        if line.startswith(render.SECTION_MARK)
    ]


# ── R1/R2: one entry point, named once ────────────────────────────────────────────────────────────


def test_render_exposes_exactly_one_human_entry_point():
    """AC2's whole claim in one assertion. `overview` and `deep` are deleted, not deprecated: a
    module that still exports them is a module a caller can still route around `document()` with,
    and the two-modes-of-one-command failure comes back the first time somebody does."""
    public = {
        name
        for name, value in vars(render).items()
        if not name.startswith("_") and callable(value) and getattr(value, "__module__", "") == render.__name__
    }
    # route_kind is a routing seam for borg_core.nextpick, not a second way to render the page.
    assert public == {"document", "porcelain", "route_kind"}


def test_the_human_arm_names_render_document_exactly_once():
    """Source-text, not behavioural, and deliberately so: a second `render.document(doc)` call in
    `_run` would render identically and cost twice, and no output assertion can see it."""
    source = inspect.getsource(cli._run)  # pylint: disable=protected-access
    assert source.count("render.document(") == 1
    assert "render.overview" not in source
    assert "render.deep" not in source


# ── R3/R4: the spine, and the empty-section rule that makes it assertable ──────────────────────────


def test_every_section_renders_its_header_on_each_page():
    """The invariant compares each page against ITS OWN section list, never against the other page: a header
    diff between two renderings goes green if both drift together. Since 2026-10-13 there are two lists --
    the Queen's `SECTIONS` and a directory's `REPOSITORY_SECTIONS` -- and `scope.kind` picks between them."""
    expected = [title for title, _ in render.SECTIONS if title]
    # A9. NINE SECTIONS SINCE THE BOARD (WAITING ON YOU, last: link-unification L3). EIGHT SINCE AC4. This list going red is the reviewable event AC2's directive chose
    # over reserving an always-empty slot for yours-vs-mine ahead of time -- "a section that renders
    # only a placeholder in every context for a whole release is the exact 'reads as broken' failure
    # Q10 exists to prevent". NEXT sits below SHIPPED so the page reads history-then-future, and
    # above SIGNALS so the honest "nobody looked" line is the last word on a `--local` render.
    assert expected == ["IN FOCUS", "REPOSITORIES", "STACKS", "QUEUED", "SHIPPED", "NEXT", "SIGNALS", "WAITING ON YOU"]
    assert _headers(render.document(_doc())) == expected
    # THE DIRECTORY'S PAGE: strictly one directory -- its card, then what waits on it. MUTATION: add "REPOSITORIES"
    # (or any repository-level section) to REPOSITORY_SECTIONS and this goes red, which is the point.
    directory = [title for title, _ in render.REPOSITORY_SECTIONS if title]
    assert directory == ["IN FOCUS", "WAITING ON YOU"]
    assert _headers(render.document(_repository_doc())) == directory


def test_an_empty_section_renders_exactly_one_placeholder_line():
    """Exactly one, never zero (a header with nothing under it reads as broken) and never two."""
    body_text = plain(render.document(_doc()))
    body: dict[str, list[str]] = {}
    current = None
    for line in body_text.split("\n"):
        if line.startswith(render.SECTION_MARK):
            current = line[2:].split("  ")[0]
            body[current] = []
        elif current is not None and line.strip():
            body[current].append(line)
    for title in ("IN FOCUS", "STACKS", "QUEUED", "SHIPPED", "SIGNALS"):
        assert len(body[title]) == 1, f"{title} rendered {body[title]}"
        assert body[title][0].startswith("  — "), body[title][0]
    # REPOSITORIES on an empty registry is the same rule with the zsh original's own sentence.
    assert body["REPOSITORIES"] == ["  — No repositories registered. Run: borg scan"]


# ── R5: three diagnoses, not one sentence ─────────────────────────────────────────────────────────


# EVERY CASE HERE CARRIES A `scope_kind`, and the orchestrator one carries the EMPTY slug that
# `grid.repository_dir` actually produces there rather than a plausible-looking one. Varying `slug`
# alone -- which is how the spec states this ladder -- passes against a hand-built block while the
# third arm is unreachable in production, because orchestrator scope has no slug by contract.
_STACKS_CASES = [
    ({"scope_kind": "orchestrator", "slug": ""}, "no stack manifests in the registry yet"),
    ({"scope_kind": "repository", "slug": ""}, "no GitHub origin"),
    ({"scope_kind": "repository", "slug": "acme/ledger"}, "no stack manifest declares work in acme/ledger"),
    # FOURTH ARM, and it carries a slug precisely so it cannot pass by falling through to an earlier
    # one: a refused manifest in a fully-resolved repository is the case every other arm reports as
    # manifest-less.
    ({"scope_kind": "repository", "slug": "acme/ledger", "refused": 1}, "1 manifest could not be read"),
]


@pytest.mark.parametrize("grid_overrides,expected", _STACKS_CASES)
def test_the_four_stacks_placeholders_are_four_different_diagnoses(grid_overrides, expected):
    """An empty STACKS section is the MODAL case -- 13 of ~14 registered repositories have no
    manifest -- so which of the four it is has to be readable off the page, not inferred."""
    doc = _doc()
    doc["grid"].update(grid_overrides)
    assert expected in render.document(doc)


def test_the_four_stacks_placeholders_are_actually_distinct():
    sentences = set()
    for overrides, _ in _STACKS_CASES:
        doc = _doc()
        doc["grid"].update(overrides)
        sentences.add(render._grid_placeholder(doc["grid"]))  # pylint: disable=protected-access
    assert len(sentences) == 4


def test_a_refused_manifest_is_not_reported_as_no_manifest_at_all():
    """The arm's whole reason to exist, stated as the sentence it must NOT print.

    A repository whose only manifest was refused used to render "no stack manifests in the registry
    yet. Run /borg-plan in any repository." -- false, and it points the reader at scaffolding a second
    manifest beside the broken one. Asserting the absence rather than only the presence is what stops
    a future reordering of the ladder from silently restoring the old answer.
    """
    doc = _doc()
    doc["grid"].update({"scope_kind": "repository", "slug": "acme/ledger", "refused": 2})
    page = render.document(doc)
    assert "2 manifests could not be read" in page
    assert "no stack manifests in the registry yet" not in page
    assert "no stack manifest declares work in acme/ledger" not in page


def test_a_refused_count_of_zero_falls_through_to_the_older_arms():
    """`refused` is an ordinary absent-or-zero key, not a tristate. A block that never carried it --
    every `--json` document written before this arm existed -- must read exactly as it did."""
    doc = _doc()
    doc["grid"].update({"scope_kind": "repository", "slug": "acme/ledger", "refused": 0})
    assert "no stack manifest declares work in acme/ledger" in render.document(doc)
    doc_without = _doc()
    doc_without["grid"].update({"scope_kind": "repository", "slug": "acme/ledger"})
    assert render.document(doc_without) == render.document(doc)


def test_the_refused_arm_outranks_the_registry_wide_sentence():
    """PINS THE LADDER'S ORDER at the one place it is observable.

    `refused` is counted for whatever scope resolved -- the whole registry in orchestrator scope --
    so an orchestrator page with unreadable manifests on disk must not print "no stack manifests in
    the registry yet". Every other placeholder case is repository-scoped, so without this the arm
    could be moved below the scope check and no test would notice.
    """
    doc = _doc()
    doc["grid"].update({"scope_kind": "orchestrator", "slug": "", "refused": 3})
    page = render.document(doc)
    assert "3 manifests could not be read" in page
    assert "no stack manifests in the registry yet" not in page


def test_orchestrator_scope_never_reaches_the_no_origin_diagnosis():
    """The regression guard for the ladder's ORDER. `grid.repository_dir` returns "" for orchestrator
    scope by contract, so a slug-first ladder answers "this directory has no GitHub origin" for
    `borg link` run from the workspace root -- a diagnosis about a directory, on the one invocation
    that is not about a directory."""
    doc = _doc()
    doc["grid"].update({"scope_kind": "orchestrator", "slug": ""})
    out = render.document(doc)
    assert "no GitHub origin" not in out
    assert "no stack manifests in the registry yet" in out


# ── R6: the two sentences the empty-registry early returns used to print ───────────────────────────


def test_empty_registry_and_all_archived_print_their_two_sentences():
    """Adapted from the three assertions that used to sit on `render.overview`. The sentences are
    verbatim; only the leading `▸` is gone, so `▸ ` stays an unambiguous section marker."""
    empty = render.document(_doc(total_projects=0))
    assert "No repositories registered. Run: borg scan" in empty

    all_archived = render.document(_doc(total_projects=2, order=[], projects={}))
    assert "No repositories to show. Run: borg link --all" in all_archived
    assert "No repositories registered" not in all_archived


def test_discovery_tip_gated_on_total_projects_not_len_order():
    # One visible + one archived: total_projects is 2 (unfiltered), so the tip must NOT appear even
    # though len(order) == 1.
    doc = _doc(
        total_projects=2,
        order=["solo"],
        projects={"solo": {"source": "cli", "status": "idle", "relative_activity": "never"}},
    )
    out = render.document(doc)
    assert "Tip: run 'borg scan'" not in out
    assert "solo" in out


def test_lone_archived_prints_both_tip_and_all_filtered_sentence():
    out = render.document(_doc(total_projects=1, order=[], projects={}))
    assert "Tip: run 'borg scan'" in out
    assert "No repositories to show. Run: borg link --all" in out


# ── R7/R8: what scope narrows, and what it must not ───────────────────────────────────────────────


def test_the_board_is_the_queens_page_alone():
    """REPOSITORIES is the cross-repository overview and the overview is the Queen's (2026-10-13). A directory's
    page names no other repository, however many the document carries -- the document is registry-wide, the
    page is not. skills/borg-switch gets its cross-repository list from `--overview` instead."""
    repositories = {
        "p": {"source": "cli", "status": "active", "relative_activity": "2h ago", "summary": "Mine."},
        "other": {"source": "cli", "status": "idle", "relative_activity": "1d ago", "summary": "Theirs."},
    }
    repository = render.document(_repository_doc(total_projects=2, order=["p", "other"], projects=repositories))
    assert "other" not in repository
    assert "Theirs." not in repository
    assert "REPOSITORY" not in repository

    queen = render.document(_doc(total_projects=2, order=["p", "other"], projects=repositories))
    assert "other" in queen and "Theirs." in queen


def test_queued_is_the_queens_aggregate_and_a_directory_page_has_none():
    """QUEUED is repository-level (it lists filed directives), so only the Queen's page prints it. The directory's
    own directives still ride in `--json` as `focus.directives`; the page stops rendering them."""
    aggregate = [{"project": "other", "title": "Someone else's directive"}]
    scoped = [{"title": "My directive"}]

    repository = _full(_repository_doc(directives=aggregate, focus=_focus(directives=scoped)))
    assert "My directive" not in repository
    assert "Someone else's directive" not in repository
    assert "QUEUED" not in repository

    orchestrator = _full(_doc(directives=aggregate))
    assert "[other] Someone else's directive" in orchestrator


def test_shipped_follows_the_same_rule_as_queued():
    aggregate = [{"project": "other", "title": "Their ship", "ship_date": "2026-01-01"}]
    scoped = [{"title": "My ship", "ship_date": "2026-02-02"}]

    repository = render.document(_repository_doc(assimilated=aggregate, focus=_focus(assimilated=scoped)))
    assert "My ship" not in repository
    assert "Their ship" not in repository
    assert "SHIPPED" not in repository

    orchestrator = render.document(_doc(assimilated=aggregate))
    assert "[other] Their ship (2026-01-01)" in orchestrator


# ── the transcribed IN FOCUS card (was `deep`) ────────────────────────────────────────────────────


def test_focus_path_line_omitted_entirely_when_path_is_the_string_null():
    out = render.document(_repository_doc())
    assert "Path:" not in out


def test_status_line_appears_exactly_once_on_the_whole_page_and_ends_in_the_status_word():
    """drone.zsh:964's `grep -m1 'Status:'` reads this line. The fixture below puts the literal
    `Status:` inside a PR title in STACKS of the Queen's page, which is the poisoning shape a real sweep
    produces. A directory's page does not render STACKS at all, so there the card's line is the only one
    and it is FIRST by construction; the Queen's page has no card, hence no `Status:` line of its own."""
    doc = _repository_doc(focus=_focus(entry={"path": "null", "status": "active"}))
    doc["grid"]["manifests"] = [
        {
            "id": "m",
            "desc": "",
            "repos": [],
            "levels": [["a/b#1"]],
            "gates": [],
            "nodes": {
                "a/b#1": {
                    "ref": "a/b#1",
                    "title": "chore(auth): Status: normalise the rollout report",
                    "state": "open",
                    "state_source": "swept",
                    "level": 0,
                    "seq": 0,
                    "parents": [],
                    "children": [],
                    "gate": None,
                    "why": "",
                }
            },
        }
    ]
    out = _full(doc)
    body_text = plain(out)
    status_lines = [line for line in body_text.split("\n") if "Status:" in line]
    assert len(status_lines) == 1  # the card's own line; the poisoned PR title is not on this page
    assert status_lines[0].startswith("  Status:")
    assert status_lines[0].endswith("active")

    # On the Queen's page the poisoned title IS rendered, and it is the only `Status:` there: the Queen has no card.
    queen = plain(_full({**doc, "focus": None, "scope": {"kind": "orchestrator"}})).split("\n")
    assert [line for line in queen if "Status:" in line] == [line for line in queen if "normalise the rollout" in line]
    assert len([line for line in queen if "Status:" in line]) == 1


def test_the_plan_is_not_on_a_directorys_page():
    """The Active Plan block left the page with the repository-level sections (2026-10-13). `focus.plan` still
    rides in `--json`, so a consumer that wants it has it; the human page is strictly the directory's card."""
    doc = _repository_doc(focus=_focus(plan={"objective": "Ship the thing.", "met": 1, "total": 2}))
    out = render.document(doc)
    assert "Active Plan" not in out
    assert "Ship the thing." not in out
    assert "criteria met" not in out


def test_focus_renders_checkpoints_and_the_latest_head():
    doc = _repository_doc(
        focus=_focus(checkpoints=["2026-08-01.md"], checkpoint_head="line one\nline two"),
    )
    out = render.document(doc)
    assert "2026-08-01.md" in out
    assert "line one" in out


def test_checkpoint_head_indents_blank_lines_to_two_spaces():
    head = "# Checkpoint\n\nBody.\n"[:-1]  # mirrors shell.read_latest_checkpoint_head's join
    out = render._checkpoint_head_block(head)  # pylint: disable=protected-access
    lines = out.split("\n")
    assert lines[1] == "  "


def test_checkpoint_head_no_spurious_trailing_blank_for_a_short_checkpoint():
    text = "# Checkpoint one\n\nBody one.\n"
    head = "\n".join(text.split("\n")[:20])
    out = render._checkpoint_head_block(head)  # pylint: disable=protected-access
    assert out.count("\n") == 3


# ── the untouched porcelain surface ───────────────────────────────────────────────────────────────


def test_porcelain_empty_returns_exactly_empty_string():
    assert render.porcelain(_doc()) == ""


def test_porcelain_cuts_at_80_with_no_ellipsis():
    long_summary = "x" * 90
    doc = _doc(
        order=["a"],
        projects={"a": {"source": "cli", "status": "idle", "last_activity": "", "summary": long_summary}},
    )
    row = render.porcelain(doc)
    field = row.split("\t")[4].rstrip("\n")
    assert field == "x" * 80
    assert "..." not in field


def test_porcelain_carries_no_box_drawing_and_no_ansi():
    """`--porcelain` is fzf's INPUT LIST, not a page. A `▸`, a box character or an SGR sequence in
    this stream breaks `borg switch`'s `--delimiter '\\t' --with-nth 1,3,5` outright."""
    doc = _doc(
        order=["a"],
        projects={"a": {"source": "cli", "status": "waiting", "last_activity": "x", "summary": "s"}},
    )
    row = render.porcelain(doc)
    assert "\033" not in row
    assert not set(row) & set("▸│─├┤┬┴┼┌┐└┘✔✗○●◌")


@pytest.mark.parametrize("length,expect_ellipsis", [(49, False), (50, False), (51, True)])
def test_board_summary_truncation_boundary_and_ellipsis(length, expect_ellipsis):
    summary = "x" * length
    doc = _doc(
        total_projects=1,
        order=["a"],
        projects={"a": {"source": "cli", "status": "idle", "relative_activity": "never", "summary": summary}},
    )
    out = _full(doc)
    if expect_ellipsis:
        assert "x" * 50 + "..." in out
    else:
        assert summary in out
        assert "x" * length + "..." not in out


def test_the_grid_state_token_is_never_the_registry_status_fallback():
    """Q8's structural half on this side of the split: the literal appears here exactly ONCE -- the
    named constant -- and picture.py imports `grid.STATE_SOURCE_UNKNOWN` rather than restating it,
    so the two modules cannot drift. The five pre-existing jq-parity sites are call sites of the
    constant, not copies of the string."""
    source = inspect.getsource(render)
    assert source.count('"unknown"') == 1
    assert render._JQ_ABSENT_STATUS == "unknown"  # pylint: disable=protected-access


# ── shared bullet loops, capacity, cortex ─────────────────────────────────────────────────────────


def test_queued_and_shipped_share_one_bullet_loop_differing_only_by_the_repository_tag():
    """QUEUED and SHIPPED were two byte-identical-except-for-the-tag loops until AC2 took the last
    difference out: the zsh original's per-block header lines are gone, and `_ship_date_suffix` reads
    an ABSENT key as "" -- so a directive and a shipped plan render through the same call."""
    directives = [{"project": "a", "title": "One"}]
    assimilated = [{"project": "a", "title": "Shipped", "ship_date": "2026-01-01"}]

    tagged = render._bullet_lines(directives, show_repository=True)  # pylint: disable=protected-access
    untagged = render._bullet_lines(directives, show_repository=False)  # pylint: disable=protected-access
    assert len(tagged) == len(untagged) == 1
    assert "[a]" in tagged[0]
    assert "[a]" not in untagged[0]
    assert tagged[0].replace("[a] ", "") == untagged[0]

    # A directive carries no ship date, and its bullet must not grow an empty "()" for the lack.
    assert "(" not in plain(untagged[0])
    shipped = render._bullet_lines(assimilated, show_repository=False)  # pylint: disable=protected-access
    assert plain(shipped[0]) == "    - Shipped (2026-01-01)\n"

    # No `Directives:` / `Recently assimilated:` header survives -- the count lives on the section
    # header's note, and printing it twice is what this asserts against.
    joined = "".join(render._bullet_lines(directives + assimilated, True))  # pylint: disable=protected-access
    assert "Directives:" not in joined
    assert "assimilated" not in joined


def test_board_row_variants_capacity_and_cortex_all_render():
    doc = _doc(
        total_projects=2,
        order=["a", "b"],
        projects={
            "a": {"source": "desktop", "status": "active", "relative_activity": "2h ago", "summary": "s"},
            "b": {"source": "coco", "status": "waiting", "relative_activity": "1h ago", "summary": "s"},
        },
        directives=[{"project": "a", "title": "Directive one"}],
        assimilated=[{"project": "a", "title": "Shipped one", "ship_date": "2026-01-01"}],
        cortex_pending=[{"project": "a", "reset_at": "x", "countdown": "1h 0m"}],
        capacity={"active": 5, "limit": 3, "over_limit": True},
    )
    out = _full(doc)
    assert "[D]" in out
    assert "[X]" in out
    assert "waiting <<<" in out
    assert "Directive one" in out
    assert "Shipped one" in out
    assert "resumes in 1h 0m" in out
    assert "sessions need attention" in out
    # The capacity warning lost its `▸` so the section marker stays unambiguous.
    assert "▸ 5 sessions" not in out
    # "Need attention" on the board note is the WAITING count, not capacity.active.
    assert "2 repositories · 1 need attention" in out


def test_the_board_header_still_describes_its_rows_when_a_name_overflows_the_column():
    """MUTATION: pad the header and the rows from `_COL_REPOSITORY` again instead of `_board_width`.

    `_COL_REPOSITORY` was used as a MINIMUM (`{display:<{_COL_REPOSITORY}}`) with no truncation anywhere,
    so a name longer than 20 pushed SRC / STATUS / LAST ACTIVE / SUMMARY right by the overflow while
    the header line, padded from the same constant, did not move. Every column label then sat over
    the wrong column, on EVERY render in both scopes. Two registered repositories trigger it today
    (`pytest-coverage-impact` 22, `reveal-data-consistency` 23), which is why no fixture ever saw it:
    every fixture name is short.

    THE ASSERTION IS AN OFFSET, NOT A STRING. It finds where `SRC` starts on the header and where
    each row's `[C]` badge starts, and requires them equal. That is the property "the header
    describes its rows" stated in the only terms that can actually go red, and it holds for any
    width rule that is internally consistent -- including a future truncating one.

    THE DISPLAY NAME IS WHAT COUNTS, not the registry key: `_board_width` measures the same string
    `_overview_row` pads, or a renamed repository reintroduces the bug through the other door.
    """
    long_display = "reveal-data-consistency"  # 23 -- the longest name in the real registry today
    assert len(long_display) > render._COL_REPOSITORY  # pylint: disable=protected-access
    doc = _doc(
        total_projects=2,
        order=["a", "b"],
        projects={
            "a": {"source": "cli", "status": "idle", "relative_activity": "2h ago", "summary": "s"},
            "b": {
                "source": "cli",
                "status": "idle",
                "display_name": long_display,
                "relative_activity": "1h ago",
                "summary": "s",
            },
        },
    )
    board = [line for line in plain(render.document(doc)).split("\n") if " [C] " in line or " SRC " in line]
    assert len(board) == 3, board

    offsets = {line.index("SRC") if " SRC " in line else line.index("[C]") for line in board}
    assert len(offsets) == 1, f"the header and its rows disagree about where SRC starts: {board}"
    assert long_display in "\n".join(board), "the name is printed whole, never cut to fit"

    # ...and the cortex continuation follows the SAME width rather than its own hardcoded indent.
    doc["cortex_pending"] = [{"project": "b", "reset_at": "x", "countdown": "1h 0m"}]
    paused = next(line for line in plain(render.document(doc)).split("\n") if "resumes in" in line)
    assert paused.index("⏸") == 1 + len(long_display) + 2, paused


def test_the_last_word_on_a_local_page_is_that_nobody_looked():
    """render.py's `_signals_section` cites this. The unread-status line and every other warning print
    BEFORE the resolution line, so the page's last SIGNALS word stays "nobody looked".

    MUTATION: move the `_resolution_line` call above the warnings loop."""
    doc = _doc()
    doc["grid"].update(
        {
            "declared": 3,
            "unresolved": 3,
            "warnings": ['declared: 1 row(s) carry a word that is not a PR state ("review" x1) -- shown unresolved'],
        }
    )
    page = plain(render.document(doc))
    # SIGNALS is no longer the last section (WAITING ON YOU lands last), so the last word is read OFF
    # THE SIGNALS SECTION, which is what this test's docstring always claimed.
    signals = page.split("▸ SIGNALS", 1)[1].split("▸ WAITING ON YOU", 1)[0]
    lines = [line for line in signals.split("\n") if line.strip()]
    assert "declared refs unresolved — nobody looked" in lines[-1]
    assert any('"review" x1' in line for line in lines[:-1])


def test_signals_reports_the_ladders_gap_as_a_sentence_never_a_token():
    doc = _doc()
    doc["grid"].update({"declared": 11, "unresolved": 3})
    assert "3 of 11 declared refs unresolved — nobody looked" in render.document(doc)

    doc = _doc()
    doc["grid"].update({"declared": 7, "unresolved": 0})
    assert "7 of 7 declared refs resolved." in render.document(doc)

    # Nothing declared -> no line at all, rather than "0 of 0".
    assert "declared refs" not in render.document(_doc())


def test_signals_says_the_picture_blew_its_budget_rather_than_just_looking_wrong():
    """The width-check directive's own case. MUTATION: drop `_width_line` from `_signals_section`.

    The page then renders a picture that wraps in any pane narrower than it, with SIGNALS reporting
    "nothing to report." — the failure is visible and unexplained, which is the whole complaint the
    directive was filed on.

    WHAT THIS CASE DOES *NOT* COVER, corrected after a reviewer checked the claim it used to make.
    It said this also killed "delete the `block["picture_width"] = ...` stamp in `cli._grid`". It does
    not, and cannot: it sets the field by hand, so THIS WHOLE MODULE IS BLIND TO THE STAMP — measured
    by replacing that line in cli._grid with `pass` and re-running, which leaves test_render.py fully
    green and turns test_cli.py red. (No pass-count is written down here on purpose: this file gains
    cases every AC, and the last recorded number, 69, was already stale by four when a reviewer
    checked it. Re-run the mutation; do not trust a transcribed total.) That mutation is killed by
    `test_cli.py::test_json_publishes_the_measured_picture_width_on_the_grid_block`, which measures
    over a REGISTERED fixture repository rather than an empty registry, and by `cli_contract.bats`'s
    B15b ("grid.picture_width is the width of the widest picture row the same run rendered"). Neither
    existed when the claim was written, which is how a shipped feature came to be entirely unpinned
    behind three green tests.

    READ, NEVER REMEASURED, and that is why setting the field by hand is right HERE. The width
    arrives as a published integer on the grid block; a renderer that rasterized the picture itself
    would pass a test that built a wide manifest and still be free to disagree with `--json`. Pinning
    the STAMP is the other two cases' job, deliberately, because this one is about the SENTENCE.
    """
    doc = _doc()
    doc["grid"]["picture_width"] = 71
    out = plain(render.document(doc))
    assert "picture is 71 columns wide" in out
    assert f"{picture.PICTURE_BUDGET} is the budget" in out

    # ...and SILENT at and below the budget, so it can never become permanent page furniture. 0 is
    # the case that matters most: every fixture and both live manifests sit well under the budget.
    for width in (0, 1, picture.PICTURE_BUDGET):
        doc["grid"]["picture_width"] = width
        assert "columns wide" not in plain(render.document(doc))


def test_chains_names_the_sweep_window_bound_rather_than_claiming_it_is_the_sweep_time():
    """MUTATION: restore `freshness = f"swept {since}"` in `_grid_section`.

    `grid.since` is `grid.sweep_since(now, DEFAULT_SWEEP_WINDOW_DAYS)` -- the window's LOWER BOUND,
    `now - 90 days` -- and the note used to interpolate it after the bare word "swept". On a real
    render that printed a full ISO timestamp exactly ninety days old with the current wall clock
    attached, and a human read `swept 2026-05-30T14:24:17Z` as "this data is three months stale".
    Freshness is the entire premise of the front door and this is the one line that reports it.

    IT DERIVES THE MARK THE WAY PRODUCTION DOES INSTEAD OF PINNING A DATE, which is the whole reason
    the goldens missed this: `tests/fixtures/link/sweep-acme.json` pins a bare `"since": "2026-05-28"`
    with no relationship to any clock, and a bare date reads harmlessly under either wording. The
    mark here comes out of `sweep_since` itself, so it has the SHAPE and the OFFSET the bug is made
    of -- asserted below, so the case cannot go quiet if `sweep_since` stops being relative.
    """
    moment = 1787000000
    mark = link_grid.sweep_since(moment, link_grid.DEFAULT_SWEEP_WINDOW_DAYS)
    assert mark != link_grid.format_iso(moment), "the mark is a WINDOW BOUND, never the sweep instant"
    assert mark.endswith("Z") and "T" in mark, "and it is a full timestamp, which is what misreads"

    block = dict(_doc()["grid"])
    block.update({"swept": True, "since": mark})
    note = next(
        line
        for line in plain(render.document(_doc(grid=block))).split("\n")
        if line.startswith(f"{render.SECTION_MARK}STACKS")
    )

    assert f"swept back to {mark}" in note, note
    assert f"swept {mark}" not in note, f"the note reports a window bound as if it were a sweep time: {note}"

    # ...and an un-swept grid still says so, rather than naming a bound nobody swept against.
    block.update({"swept": False, "since": ""})
    unswept = next(
        line
        for line in plain(render.document(_doc(grid=block))).split("\n")
        if line.startswith(f"{render.SECTION_MARK}STACKS")
    )
    assert "not swept" in unswept and "back to" not in unswept


def _fork_block() -> dict:
    """The approved mock's fork, all the way through grid_manifest -- a real block, not a hand-built
    one, so STACKS is exercised against the shape production actually assembles.

    `_id` is stamped here because `manifest.shell._load_manifest` stamps it at LOAD time, not
    validation time, and these tests never load from disk. Without it the block's `id` is "" and the
    heading renders empty -- which is what the first run of these cases actually did.
    """
    manifest = fork_manifest()
    manifest["_id"] = "auth-hardening"
    return link_grid.grid_manifest(manifest, {}, {})


def test_chains_renders_a_manifest_heading_its_description_and_its_repositories():
    """MUTATION: drop the `desc` or `repos` line from `_manifest_lines`. Both are AC2 additions to
    the wire (grid.py's `desc`/`repos`) and neither has any other consumer, so nothing else notices
    if the renderer stops reading them."""
    doc = _doc()
    doc["grid"]["manifests"] = [_fork_block()]
    body_text = plain(_full(doc))

    assert "  auth-hardening" in body_text
    assert "  Rotate every service onto scoped keypair auth" in body_text
    assert "  repos: acme/infra · acme/platform · acme/warehouse" in body_text
    # ...the picture, ...
    assert "├────" in body_text
    # ...and one detail block per node, in node-id order, each id appearing exactly twice.
    ids = re.findall(r"\bn\d+\b", body_text)
    assert sorted(set(ids), key=lambda s: int(s[1:])) == [f"n{i}" for i in range(1, 8)]
    assert {ids.count(i) for i in set(ids)} == {2}


def test_a_manifest_with_no_description_or_repositories_renders_neither_line():
    """The blank-line failure the placeholder rule exists to prevent, one level down: an empty `desc`
    must vanish, not render as an indented empty dim line."""
    block = _fork_block()
    block["desc"] = ""
    block["repos"] = []
    doc = _doc()
    doc["grid"]["manifests"] = [block]
    body_text = plain(_full(doc))

    # Drop the header LINE (which carries the section note) before reading the body.
    body = body_text.split("▸ STACKS")[1].split("\n", 1)[1].split("▸ QUEUED")[0]
    assert "repos:" not in body
    # The heading is immediately followed by the glance strip -- no orphan blank between them.
    lines = [line for line in body.split("\n") if line.strip()]
    assert lines[0].strip() == "auth-hardening"
    assert lines[1].strip().startswith("glance:")


def test_signals_names_a_declared_cycle_rather_than_drawing_it():
    """MUTATION: delete `_cycle_lines`. `manifest_core._rank_nodes` breaks a cycle by admitting the
    smallest remaining ref rather than raising, so a cyclic manifest still ranks and still draws --
    minus the edges that do not descend. Without this sentence the picture reads as acyclic and the
    missing connector looks like a rendering bug."""
    cyclic = {
        "_id": "loop",
        "rows": [
            {"ref": "o/r#1", "order": "1", "after": ["o/r#2"]},
            {"ref": "o/r#2", "order": "2", "after": ["o/r#1"]},
        ],
    }
    block = link_grid.grid_manifest(cyclic, {}, {})
    assert render.picture.back_edges(block), "the fixture must actually be cyclic"

    doc = _doc()
    doc["grid"]["manifests"] = [block]
    assert "loop: 1 declared edge forms a cycle and is not drawn" in render.document(doc)

    # ...and the plural arm is a SEPARATE sentence, not a pluralized noun glued to a singular verb.
    # TWO DISJOINT 2-CYCLES, not one longer cycle: `_rank_nodes` breaks a cycle by admitting the
    # smallest remaining ref, so a 3-node loop still yields exactly ONE undrawable edge. Reaching two
    # takes two independent loops.
    bigger = link_grid.grid_manifest(
        {
            "_id": "twin-loops",
            "rows": [
                {"ref": "o/r#1", "order": "1", "after": ["o/r#2"]},
                {"ref": "o/r#2", "order": "2", "after": ["o/r#1"]},
                {"ref": "o/s#1", "order": "3", "after": ["o/s#2"]},
                {"ref": "o/s#2", "order": "4", "after": ["o/s#1"]},
            ],
        },
        {},
        {},
    )
    assert len(render.picture.back_edges(bigger)) == 2
    doc["grid"]["manifests"] = [bigger]
    out = render.document(doc)
    assert "declared edges form a cycle and are not drawn" in out
    assert "edge forms" not in out

    # An acyclic manifest says nothing at all.
    clean = _doc()
    clean["grid"]["manifests"] = [_fork_block()]
    assert "cycle" not in render.document(clean)


def test_the_archived_status_arm_renders_a_bare_reset():
    """`_status_color`'s `*)` arm reproduces borg.zsh:354's genuine double reset -- NC + text + NC.
    It is the only board row shape `--all` can produce and no golden covers it in isolation."""
    doc = _doc(
        total_projects=1,
        order=["gone"],
        projects={"gone": {"source": "cli", "status": "archived", "relative_activity": "5d ago", "summary": "s"}},
        show_all=True,
    )
    row = [line for line in render.document(doc).split("\n") if "gone" in line][0]
    assert row.startswith(f" gone{' ' * 16} [C]  \x1b[0marchived")


def test_a_summary_past_seventy_columns_wraps_and_reindents_inside_the_card():
    """The IN FOCUS card's `fold -s -w 70` + `sed '1!s/^/  /'` path. Pinned structurally rather than
    byte-exact for the reason the bats case records: three counting algorithms are in play and they
    diverge on non-ASCII."""
    long_summary = (
        "This summary is deliberately far longer than seventy columns so that the fold "
        "pipeline has to break it across at least three separate rendered lines."
    )
    doc = _repository_doc(focus=_focus(entry={"path": "null", "summary": long_summary}))
    body_text = plain(render.document(doc))
    block = body_text.split("  Summary\n")[1].split("\n\n")[0].split("\n")
    assert len(block) >= 2
    for continuation in block[1:]:
        assert continuation.startswith("  ") and not continuation.startswith("   ")


def test_two_pending_wakes_for_one_repository_render_the_first_not_the_last():
    """`_cortex_countdowns` is first-wins, matching borg.zsh:374's awk join: a state file appended to
    twice has an earlier wake, and the earlier one is the one that fires."""
    doc = _doc(
        total_projects=1,
        order=["a"],
        projects={"a": {"source": "cli", "status": "idle", "relative_activity": "1h ago", "summary": "s"}},
        cortex_pending=[
            {"project": "a", "countdown": "0h 5m"},
            {"project": "a", "countdown": "9h 9m"},
        ],
    )
    out = render.document(doc)
    assert "resumes in 0h 5m" in out
    assert "9h 9m" not in out


def test_signals_surfaces_every_grid_warning():
    doc = _doc()
    doc["grid"]["warnings"] = ["sweep: adapter 'github' could not reach its source -- offline"]
    out = render.document(doc)
    assert "— sweep: adapter 'github' could not reach its source -- offline" in out


def test_assimilated_omits_parens_when_ship_date_empty():
    """Regression for the zsh-port bug: a missing "Shipped:" line produced ship_date="", and the
    old f"({item['ship_date']})" rendered a bare, empty "()" after the title. A title that itself
    ends in a parenthetical (e.g. "(C6)") must survive untouched -- only the DATE's own parens are
    conditional, never a suffix stripped from the title."""
    out = render.document(
        _doc(
            assimilated=[
                {"project": "ingle", "title": "T-4 mutation gate", "ship_date": ""},
                {"project": "borg-collective", "title": "recon migration ledger (C6)", "ship_date": "2026-08-12"},
            ],
        )
    )
    assert "[ingle] T-4 mutation gate\x1b[0m\n" in out
    assert "()" not in out
    assert "[borg-collective] recon migration ledger (C6) (2026-08-12)" in out

    # ...and the bullet loop is the Queen's alone: a bare-date item with no `project` tag still prints cleanly.
    untagged = render.document(
        _doc(assimilated=[{"project": "", "slug": "s", "title": "Deep shipped (C6)", "ship_date": ""}])
    )
    assert "Deep shipped (C6)\x1b[0m\n" in untagged
    assert "()" not in untagged


def test_render_imports_no_impure_module():
    """The import-level half of render.py's purity contract, mirroring test_picture.py's P20.

    MUTATION: measure the width inside `_width_line` by calling `os.get_terminal_size()`, or read the
    picture back off disk. Either turns this red at the import, before any assertion about output.

    THE CLOCK TEST BELOW WAS THE ONLY GUARD THIS MODULE HAD, and a monkeypatch on `time`/`datetime`
    catches exactly one impurity. `render.py` was also absent from pyproject's clean-arch Domain map
    until the `--json`-side width check added it, and the linter RETURNS EARLY on a file it cannot
    classify — so for three ACs this module was asserted pure by its own docstring and by nothing
    executable. Both gates now exist and neither is redundant: W9004's allow-list already permits
    `pathlib`, `json` and `datetime`, so the linter would not catch `from pathlib import Path` and
    this walk would.
    """
    tree = ast.parse(Path(render.__file__).read_text(encoding="utf-8"))
    imported: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            imported.update(alias.name.split(".")[0] for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.module:
            imported.add(node.module.split(".")[0])
    assert not imported & {"os", "subprocess", "time", "datetime", "pathlib", "shutil", "socket"}

    called = {n.func.id for n in ast.walk(tree) if isinstance(n, ast.Call) and isinstance(n.func, ast.Name)}
    assert "open" not in called
    attributes = {n.attr for n in ast.walk(tree) if isinstance(n, ast.Attribute)}
    assert "isatty" not in attributes


def test_render_reads_no_clock(monkeypatch):
    # render.py's stated purity contract: every relative_activity/countdown/generated_at is already
    # baked into the document by ONE shell.now_epoch() call in cli._document. A second clock read
    # here would reintroduce the straddle the port removed.
    def _boom(*_args, **_kwargs):
        raise AssertionError("render.py must not read the clock")

    monkeypatch.setattr(time, "time", _boom)
    monkeypatch.setattr(datetime, "datetime", type("Boom", (), {"now": _boom}))

    doc = _repository_doc(
        total_projects=1,
        order=["p"],
        projects={"p": {"source": "cli", "status": "idle", "relative_activity": "2h ago", "summary": "s"}},
    )
    render.porcelain(doc)
    render.document(doc)


class TestFoldS:
    def test_no_break_needed(self):
        assert render._fold_s("short", width=70) == ["short"]  # pylint: disable=protected-access

    def test_breaks_after_last_space_at_or_before_width(self):
        text = "a" * 68 + " " + "b" * 10
        lines = render._fold_s(text, width=70)  # pylint: disable=protected-access
        assert lines[0] == "a" * 68 + " "
        assert lines[1] == "b" * 10
        assert not lines[1].startswith(" ")

    def test_hard_break_when_no_space_in_window(self):
        text = "a" * 140
        lines = render._fold_s(text, width=70)  # pylint: disable=protected-access
        assert lines[0] == "a" * 70
        assert lines[1] == "a" * 70

    def test_exactly_width_does_not_break(self):
        text = "a" * 70
        assert render._fold_s(text, width=70) == [text]  # pylint: disable=protected-access

    def test_width_plus_one_breaks(self):
        text = "a" * 71
        lines = render._fold_s(text, width=70)  # pylint: disable=protected-access
        assert lines[0] == "a" * 70
        assert lines[1] == "a"

    @pytest.mark.skipif(shutil.which("fold") is None, reason="no `fold` binary on this host")
    @pytest.mark.parametrize(
        "text,width",
        [
            ("short", 70),
            ("a" * 68 + " " + "b" * 10, 70),
            ("a" * 140, 70),
            ("a" * 70, 70),
            ("a" * 71, 70),
            ("aa bbb cc", 6),
            ("   abc def ghi", 5),
            ("abc def " * 5, 6),
            ("a b c d e f g h i j k l m n o p", 3),
            ("", 70),
            ("     ", 4),
            ("word " * 20, 20),
        ],
    )
    def test_matches_real_fold_s_binary(self, text, width):
        """Differential, not hardcoded: shells out to whatever `fold -s` this host actually has
        (BSD on macOS CI, GNU in a devcontainer) so the assertion is correct by construction on
        every platform instead of pinning one vendor's output. This is the test that would have
        caught the original `_fold_s` divergence -- see the PR body for the RED-before-fix run."""
        proc = subprocess.run(
            ["fold", "-s", "-w", str(width)],
            input=text,
            capture_output=True,
            text=True,
            check=True,
        )
        # `fold` never appends a newline that wasn't already on the (newline-free) input, so its
        # stdout is directly comparable to `"\n".join(lines)` with no trailing-newline massaging.
        got = render._fold_s(text, width=width)  # pylint: disable=protected-access
        assert "\n".join(got) == proc.stdout


# ── F1/F5: _summary_block, the COMPOSITION of _fold_s with the re-indent loop ─────────────────────
# TestFoldS above covers the folding primitive alone, including a differential against the real
# `fold -s` binary. What the renderer's `^  [^ ]` continuation contract actually rests on is the
# composition -- fold, then re-indent lines 2..n -- and until this class it was unverified.

_CONTINUATION_CONTRACT = re.compile(r"^  [^ ]")


class TestSummaryBlock:
    def test_summary_block_single_line_is_header_plus_one_indented_line(self):
        out = render._summary_block("a short summary")  # pylint: disable=protected-access
        assert out == f"  {picture.BOLD}Summary{picture.NC}\n  a short summary\n"

    def test_summary_block_reindents_lines_two_onward_only(self):
        # A two-word summary, each word long enough that the pair plus the two-space prefix
        # overruns the 70-column budget while either word alone fits: `fold -s -w 70` therefore
        # breaks at the single space, and the tail arrives from _fold_s with NO indent of its own.
        # (Shape, not arithmetic -- a character count in a comment rots the moment the fixture or
        # the width changes, and nothing fails when it does.)
        summary = "w" * 40 + " " + "x" * 40
        out = render._summary_block(summary)  # pylint: disable=protected-access
        lines = out.split("\n")[:-1]
        assert lines[0] == f"  {picture.BOLD}Summary{picture.NC}"
        # Line 1 carries the indent the FOLD INPUT already had -- it must not be indented twice.
        assert lines[1] == "  " + "w" * 40 + " "
        # Line 2 is the one the re-indent loop is responsible for.
        assert lines[2] == "  " + "x" * 40
        assert len(lines) == 3
        assert all(_CONTINUATION_CONTRACT.match(line) for line in lines)

    def test_summary_block_empty_string_pins_the_bare_indent_line(self):
        # The one line on the page that legitimately fails `^  [^ ]`: with nothing to fold, zsh's
        # `echo -e "  " | fold -s -w 70 | sed '1!s/^/  /'` emits the bare two-space line and so does
        # this. Pinned so a future "strip trailing whitespace" cleanup is a visible decision.
        out = render._summary_block("")  # pylint: disable=protected-access
        assert out == f"  {picture.BOLD}Summary{picture.NC}\n  \n"

    def test_summary_block_flattens_an_embedded_newline(self):
        # F1. summarize.summarize_llm returns `result.stdout.strip()[:500]`, and .strip() does not
        # touch INTERIOR newlines the way the heuristic path's `.replace("\n", " ")` does; nor does
        # lib/registry.zsh's control-char scrub, whose ranges exclude 0x0A. Un-normalized, the raw
        # \n emits a sub-line _fold_s never produced and the re-indent loop therefore never indents.
        out = render._summary_block(link_core.flatten_summary("first half\nsecond half"))  # pylint: disable=protected-access
        lines = out.split("\n")[:-1]
        assert all(_CONTINUATION_CONTRACT.match(line) for line in lines[1:]), lines
        assert lines[1] == "  first half second half"
        assert len(lines) == 2

    def test_summary_block_flattens_newlines_before_folding_not_after(self):
        # The flatten is one-for-one, so a newline occupies a space's worth of the 70-column budget
        # and the break lands exactly where an equivalent space would put it -- i.e. no golden moves.
        summary = "w" * 40 + "\n" + "x" * 40
        with_newline = render._summary_block(link_core.flatten_summary(summary))  # pylint: disable=protected-access
        with_space = render._summary_block(summary.replace("\n", " "))  # pylint: disable=protected-access
        assert with_newline == with_space


# ── F1, second renderer: _overview_summary_cut, the BOARD's newline defense ───────────────────────
# _summary_block above is the DEEP DIVE's renderer. The board has its own, and it is the more
# fragile of the two: _overview_row lays every column out with fixed `:<{_COL_*}` padding, so a
# newline reaching the cut does not merely break an indent contract, it splits one row into two and
# shears every column after it.


class TestOverviewSummaryCut:
    def test_cut_flattens_an_embedded_newline(self):
        # Same writer as F1's deep-dive case: summarize.summarize_llm's `result.stdout.strip()[:500]`
        # leaves interior newlines intact, and lib/registry.zsh's control-char scrub excludes 0x0A.
        out = render._overview_summary_cut(link_core.flatten_summary("first half\nsecond half"))  # pylint: disable=protected-access
        assert "\n" not in out
        assert out == "first half second half"

    def test_cut_boundary_and_ellipsis_measure_displayed_characters(self):
        # What the flatten-before-cut ordering is FOR. Both halves of the contract -- the 50-char
        # boundary and the strictly-greater-than-50 ellipsis -- have to be decided on the string the
        # reader sees, not on the raw one. Two summaries whose ONLY newline sits at the boundary:
        # one that fills the budget exactly (no ellipsis) and one that overruns it (ellipsis).
        # Not an ordering assertion -- with a one-for-one replacement the two orderings are the same
        # string. This pins the property the ordering exists to protect, which is the part a future
        # non-one-for-one replacement could break.
        exact = render._overview_summary_cut(link_core.flatten_summary("a" * 49 + "\n"))  # pylint: disable=protected-access
        assert exact == "a" * 49 + " "
        over = render._overview_summary_cut(link_core.flatten_summary("a" * 50 + "\n" + "b"))  # pylint: disable=protected-access
        assert over == "a" * 50 + "..."

    def test_cut_matches_the_equivalent_space_so_no_golden_moves(self):
        # The replacement is one-for-one, so both the 50-char cut and the strictly-greater-than-50
        # ellipsis test land identically to the same string written with a space. This is the claim
        # that no fixture golden moves.
        summary = "w" * 30 + "\n" + "x" * 30
        with_newline = render._overview_summary_cut(link_core.flatten_summary(summary))  # pylint: disable=protected-access
        with_space = render._overview_summary_cut(summary.replace("\n", " "))  # pylint: disable=protected-access
        assert with_newline == with_space

    def test_cut_keeps_the_row_on_one_line_end_to_end(self):
        # The defect stated at the altitude the reader sees it: one registry entry, one board row.
        row = render._overview_row(  # pylint: disable=protected-access
            "alpha",
            _as_document_carries(
                {"source": "cli", "status": "idle", "relative_activity": "1h", "summary": "top\nbottom"}
            ),
            {},
        )
        assert row.count("\n") == 1
        assert row.endswith("top bottom\n")


# ── the summary field's THIRD call site, and the character set all three share ────────────────────
# `_summary_block` is the fold's defense and `_overview_summary_cut` is the board's. `porcelain` is
# the third: it serializes `summary` into a TSV RECORD whose consumers parse it BY FIELD, so a
# control character does not shear a line a reader skims past, it changes how many records there are
# and which field is which.
#
# NOT `borg switch`. The commit that added these cases claimed this function feeds the fzf picker.
# It does not -- `cmd_switch` pipes `cmd_ls --porcelain` into fzf, and that is a separate zsh
# implementation in borg.zsh which never calls into Python. The picker's own defect is fixed there
# and pinned by cli_contract.bats's "the picker feed stays one 5-field record per repository through
# tab and newline" -- a title narrowed from "tab, newline and CR" because its counting oracle cannot
# kill a CR-only mutant. See `render.porcelain`'s docstring for the full retraction.
#
# The character set is read off `lib/registry.zsh`'s `_borg_registry_write` -- `tr -d
# '\000-\010\013\014\016-\037'` deletes 0x00-0x08, 0x0B, 0x0C and 0x0E-0x1F, so 0x09, 0x0A and 0x0D
# all reach storage. Parameterized rather than hand-listed per test, so widening the set is one edit.

_SURVIVING_WS = ["\t", "\n", "\r"]


def _as_document_carries(entry: dict) -> dict:
    """`entry` exactly as the ASSEMBLED DOCUMENT carries it.

    The renderers below used to be handed a raw registry dict and flatten it themselves. They no
    longer do: `core.assemble` flattens `summary` once, at the chokepoint, so a renderer receiving a
    raw control character is testing a state the document cannot produce. Routing every case through
    assembly is what makes these assertions about the real pipeline rather than about a defence each
    renderer had to be edited to grow.
    """
    doc = link_core.assemble(
        generated_at="2026-01-01T00:00:00Z",
        show_all=False,
        total_projects=1,
        capacity={},
        projects={"alpha": entry},
        order=["alpha"],
        directives=[],
        assimilated=[],
        cortex_pending=[],
        focus=None,
    )
    entry = doc["projects"]["alpha"]
    assert isinstance(entry, dict)
    return entry


@pytest.mark.parametrize("scrubbed", ["\x00", "\x08", "\x0b", "\x0c", "\x0e", "\x1f"])
def test_the_registry_scrub_set_is_enumerated_from_the_scrub_not_assumed(scrubbed):
    """A guard on the PREMISE, not on the renderer: every character the `tr -d` range deletes is one
    `core.flatten_summary` deliberately does NOT handle, because it cannot arrive. If someone narrows
    the scrub in lib/registry.zsh they must revisit this list; if someone widens `_FLATTEN_WS` past
    the survivors they will find this test explaining why the extra characters were out of scope."""
    assert link_core.flatten_summary(scrubbed) == scrubbed


@pytest.mark.parametrize("ch", _SURVIVING_WS)
def test_flatten_summary_maps_every_surviving_whitespace_control_to_one_space(ch):
    assert link_core.flatten_summary(f"a{ch}b") == "a b"  # pylint: disable=protected-access


@pytest.mark.parametrize("ch", _SURVIVING_WS)
def test_summary_block_flattens_every_surviving_control_not_just_newline(ch):
    # Consumer 1. A `\t` inside the fold input also breaks `^  [^ ]` reasoning -- `fold -s` counts a
    # tab as one column while a terminal expands it -- and a `\r` returns the cursor to column zero,
    # erasing the indent the re-indent loop just applied.
    out = render._summary_block(link_core.flatten_summary(f"first half{ch}second half"))  # pylint: disable=protected-access
    lines = out.split("\n")[:-1]
    assert len(lines) == 2, lines
    assert lines[1] == "  first half second half"
    # The block's own newlines are structure; a tab or a CR anywhere in it is leaked payload.
    assert "\t" not in out and "\r" not in out


@pytest.mark.parametrize("ch", _SURVIVING_WS)
def test_board_row_stays_one_line_for_every_surviving_control(ch):
    # Consumer 2, stated at the altitude the reader sees it: one registry entry, one board row.
    row = render._overview_row(  # pylint: disable=protected-access
        "alpha",
        _as_document_carries(
            {"source": "cli", "status": "idle", "relative_activity": "1h", "summary": f"top{ch}bottom"}
        ),
        {},
    )
    assert row.count("\n") == 1
    assert row.endswith("top bottom\n")


@pytest.mark.parametrize("ch", _SURVIVING_WS)
def test_porcelain_emits_exactly_one_record_per_repository_for_every_surviving_control(ch):
    """THE HONEST ASSERTION IS ON THE RECORD COUNT, and on the field count within the record.

    An assertion on the text alone ("the summary reads `top bottom`") passes on a build that emits
    TWO rows, because the first row still ends where the assertion stops looking. What a
    field-parsing consumer of `borg link --porcelain` depends on is one record per repository and five
    tab-separated fields per record -- an extra record is a repository that does not exist, and a
    shifted field means column 3 is no longer the status. Both are asserted here; neither is implied
    by the other.
    """
    doc = _doc(
        order=["alpha", "beta"],
        projects={
            "alpha": {"source": "cli", "status": "idle", "last_activity": "1h", "summary": f"top{ch}bottom"},
            "beta": {"source": "cli", "status": "idle", "last_activity": "2h", "summary": "plain"},
        },
    )
    out = render.porcelain(doc)
    records = out.splitlines()
    assert len(records) == 2, records
    assert [record.split("\t")[0] for record in records] == ["alpha", "beta"]
    assert all(len(record.split("\t")) == 5 for record in records), records
    assert records[0].split("\t")[4] == "top bottom"


def test_porcelain_flattens_before_the_80_char_cut():
    # Same ordering the other two consumers use. The replacement is one-for-one so the two orderings
    # agree today; what is pinned is that the 80-char budget measures the characters the field
    # actually carries, which is the half a future non-one-for-one replacement could break.
    summary = "w" * 40 + "\t" + "x" * 60
    doc = _doc(order=["a"], projects={"a": {"source": "cli", "status": "idle", "summary": summary}})
    field = render.porcelain(doc).split("\t")[4].rstrip("\n")
    assert field == ("w" * 40 + " " + "x" * 60)[:80]


def test_a_null_summary_renders_nothing_in_the_board_row_and_empty_in_porcelain():
    """Registry rows carry `"summary": null`. Through the real pipeline the board row must say
    nothing (no placeholder: status and time only) and porcelain must carry an empty field; None appears in neither."""
    entry = _as_document_carries(
        {"source": "cli", "status": "idle", "relative_activity": "1h", "last_activity": "1h", "summary": None}
    )
    row = render._overview_row("alpha", entry, {})  # pylint: disable=protected-access
    assert "(no summary)" not in row
    assert "None" not in row
    doc = _doc(order=["alpha"], projects={"alpha": entry})
    field = render.porcelain(doc).rstrip("\n").split("\t")[4]
    assert field == ""
    assert "None" not in render.porcelain(doc)


# ── AC4: NEXT, and the yours / mine / unsure routing ──────────────────────────────────────────────


def _ready_doc(refs, *, gates=(), nodes=None, state="known", declared=None) -> dict:
    """A document carrying one manifest whose READY set is `refs`."""
    node_map = dict(nodes or {})
    for ref in refs:
        node_map.setdefault(ref, {})
    built = {ref: {"ref": ref, "state": "open", "state_source": "swept", **extra} for ref, extra in node_map.items()}
    manifest = {
        "id": "m",
        "path": "",
        "desc": "",
        "repos": [],
        "levels": [],
        "nodes": built,
        "gates": list(gates),
        "ready": {"state": state, "refs": list(refs)},
    }
    block = dict(_doc()["grid"])
    block.update({"manifests": [manifest], "declared": declared if declared is not None else len(built)})
    return _doc(grid=block)


def _next_body(doc: dict) -> list[str]:
    """The plain-text `▸ NEXT` block, header included, up to the next section."""
    out, inside = [], False
    for line in plain(_full(doc)).split("\n"):
        if line.startswith(f"{render.SECTION_MARK}NEXT"):
            inside = True
        elif line.startswith(render.SECTION_MARK):
            inside = False
        if inside:
            out.append(line)
    return out


def test_a_decision_gate_routes_to_yours_and_a_verification_to_mine():
    """A4. MUTATION: swap the two entries in `_GATE_ROUTING`.

    These are `manifest_core.gates`' own words -- a `decision` blocks a PERSON, a `verification`
    blocks nobody in particular because anyone can run it -- and they are the only two kinds either
    LIVE manifest declares. They are no longer the only two the validator accepts; see
    `test_an_unrecognized_kind_reaches_unsure_through_the_real_loader`.
    """
    doc = _ready_doc(
        ["o/r#1", "o/r#2"],
        gates=[
            {
                "ref": "o/r#1",
                "kind": "decision",
                "blocked_by": "Dana signs off",
                "resolved_by": "",
                "blocked_by_ref": "",
            },
            {
                "ref": "o/r#2",
                "kind": "verification",
                "blocked_by": "the canary must pass",
                "resolved_by": "",
                "blocked_by_ref": "",
            },
        ],
    )
    body = "\n".join(_next_body(doc))
    yours, mine = body.index("yours"), body.index("mine")
    assert yours < body.index("o/r#1") < mine, "the decision sits under yours"
    assert mine < body.index("o/r#2"), "the verification sits under mine"
    assert "Dana signs off" in body, "the gate's own sentence is what says WHY it is yours"


def test_the_mine_heading_is_true_of_a_verification_gated_row_and_not_only_an_ungated_one():
    """MUTATION: restore `_GROUP_HEADINGS[_GROUP_MINE] = "nothing is blocking these"`.

    THE HEADING WAS WRITTEN FOR ONE OF THE GROUP'S TWO MEMBERS AND WAS FALSE ABOUT THE OTHER. AC4's
    D2 puts BOTH the ungated rows and the `verification`-gated ones in `mine`; "nothing is blocking
    these" is true of the first kind and a flat contradiction of the second, because `_next_row`
    prints that gate's own `blocked_by` on the same line. Reproduced live against
    `ingle-t1-cutover` before the fix:

        mine — nothing is blocking these
          ● stillpoint-labs/stillpoint#57  needs a live-prod confirmation run against all four ...

    The routing is NOT what changed and must not: a `verification` blocks nobody in particular
    because anyone can run it, which is the axis the table splits on.

    THE ASSERTION IS THE CONTRADICTION ITSELF, not the new wording. It pins that a blocker sentence
    and the word "blocking" cannot both be in the group's own heading-plus-rows, which stays true
    through any future rewording that is honest and goes red for any that is not.
    """
    doc = _ready_doc(
        ["o/r#2"],
        gates=[
            {
                "ref": "o/r#2",
                "kind": "verification",
                "blocked_by": "the canary must be green for 24h",
                "resolved_by": "anyone runs it",
                "blocked_by_ref": "",
            },
        ],
    )
    body = "\n".join(_next_body(doc))
    heading = next(line for line in body.split("\n") if line.strip().startswith("mine"))

    assert "the canary must be green for 24h" in body, "the row states its blocker"
    assert "blocking" not in heading, f"the heading denies the blocker printed under it: {heading!r}"
    assert "nothing is blocking" not in body

    # ...and the heading still has to say something, rather than being emptied to dodge the check.
    assert len(heading.split("—", 1)[1].strip()) > 10, heading


def test_an_ungated_ready_row_is_mine():
    """A5. MUTATION: make `_route("")` return `_GROUP_YOURS`.

    Nothing is blocking the row, so nothing needs a human first. Owner's decision, and the one that
    makes the section useful rather than a second inbox.
    """
    body = "\n".join(_next_body(_ready_doc(["o/r#9"])))
    assert "mine" in body and "yours" not in body
    assert "o/r#9" in body


def test_an_unrecognized_gate_kind_routes_to_unsure_and_names_the_kind():
    """A6. MUTATION: `_GATE_ROUTING.get(kind, _GROUP_MINE)` -- or `_GROUP_YOURS`; both are lies.

    THE UNIT HALF. This case hands `_next_tally` a gate dict directly, so it pins the routing and the
    heading without going near the loader. It used to be the ONLY half, because the validator closed
    `gate.kind` to `manifest_core.GATE_KINDS` and a manifest carrying `kind: "review"` was first
    dropped whole and later (PR #173) degraded down to nothing but that row. Both are fixed: an
    unrecognized kind is now a router concern. The end-to-end half is
    `test_an_unrecognized_kind_reaches_unsure_through_the_real_loader` below, over the same fixture
    row `link-grid-orchestrator.golden` pins.
    """
    doc = _ready_doc(
        ["o/r#3"],
        gates=[{"ref": "o/r#3", "kind": "review", "blocked_by": "", "resolved_by": "", "blocked_by_ref": ""}],
    )
    body = "\n".join(_next_body(doc))
    assert "unsure" in body
    assert '"review"' in body, "the reader is told WHICH kind failed to route"
    assert "yours" not in body and "mine" not in body


_LINK_FIXTURES = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "tests", "fixtures", "link")


def test_an_unrecognized_kind_reaches_unsure_through_the_real_loader(tmp_path):
    """A6 THROUGH THE FRONT DOOR. MUTATION: restore `if kind not in GATE_KINDS` in `_validate_gate`.

    THE CASE ABOVE HANDS `_next_tally` A GATE DICT; this one starts from the shipped fixture FILE and
    goes through `manifest_shell.discover` -- validate, `gates()`, `ready_refs`,
    `_route`. That distinction is the whole point: for two ACs `unsure` was reachable only by handing
    the router a string. First the validator closed `gate.kind` to `GATE_KINDS` and
    `shell._load_manifest` dropped the WHOLE FILE; then PR #173 made degradation row-level, which
    deleted only the offending row -- quieter, and strictly worse, because the page then rendered as
    though the row had never been declared.

    READS `tests/fixtures/link/` DIRECTLY rather than building a manifest inline, and that is
    deliberate: `link-grid-orchestrator.golden` pins this same row's rendered form, and the two
    oracles must be reading the same bytes. A test that built its own `kind: "review"` row would stay
    green if someone reverted the fixture, leaving the golden as the only guard on a row whose whole
    job is to be the guard.
    """
    # `discover` takes REPOSITORY roots and globs `<root>/.stacks/`, so the shipped fixture is
    # copied into that layout rather than read in place -- the bytes under test are still the
    # fixture's.
    programs = tmp_path / "warehouse" / ".stacks"
    programs.mkdir(parents=True)
    shutil.copy(os.path.join(_LINK_FIXTURES, "manifests", "warehouse-rollout.json"), str(programs))

    manifests, warnings = manifest_shell.discover([str(tmp_path / "warehouse")])
    assert warnings == [], "an unrecognized kind is not a defect, so nothing is degraded away"
    assert "acme/warehouse#78" in [row["ref"] for row in manifests[0]["rows"]], "the row SURVIVES loading"

    with open(os.path.join(_LINK_FIXTURES, "fetch-acme.json"), encoding="utf-8") as handle:
        recording = json.load(handle)
    fetched = {ref: {"state": node["state"].lower()} for ref, node in recording["nodes"].items()}

    block = link_grid.grid_manifest(manifests[0], {}, fetched)
    grid_block = dict(_doc()["grid"])
    grid_block.update({"manifests": [block], "declared": len(block["nodes"])})
    body = "\n".join(_next_body(_doc(grid=grid_block)))

    assert "unsure" in body, "the group built to say 'the router does not know' actually populates"
    assert '"review"' in body, "and the human is told WHICH kind failed to route"
    assert "acme/warehouse#78" in body


def test_the_unsure_group_is_absent_when_empty_but_the_section_is_not():
    """A7. MUTATION: render the `unsure` heading unconditionally.

    A GROUP may be absent; a SECTION may not. AC2's directive rejected reserving an always-empty
    section slot for yours-vs-mine as the "reads as broken" failure, and this is the line between the
    two ideas: NEXT always renders (with a placeholder when it has nothing), the groups inside it
    only render when populated. Neither live manifest declares an unrecognized kind.
    """
    body = "\n".join(_next_body(_ready_doc(["o/r#9"])))
    assert "unsure" not in body
    assert f"{render.SECTION_MARK}NEXT" in body


def test_nothing_ready_and_nobody_looking_are_different_sentences():
    """A2/A3 at the RENDER level. MUTATION: drop the `unlooked` arm and print one placeholder.

    The `--local` case is the one that matters: SIGNALS prints `N of N declared refs unresolved —
    nobody looked` two lines below, so a NEXT that says "nothing is ready" makes the page contradict
    itself inside one screen.
    """
    empty = "\n".join(_next_body(_ready_doc([], declared=3)))
    # A declared-only node, as `ready_refs` sees it under `--local`. The fixture used to carry NO nodes, which no
    # real unresolved manifest does: a manifest with no refs is `_is_unlooked` False by design.
    declared_only = {"o/r#1": {"state_source": "declared"}}
    unlooked = "\n".join(_next_body(_ready_doc([], nodes=declared_only, state="unlooked", declared=3)))
    assert "nothing is ready" in empty
    assert "0 ready of 3" in empty
    assert "nobody looked" in unlooked
    assert "nothing is ready" not in unlooked
    assert empty != unlooked


def _swept_board_doc(*, extra: dict | None = None) -> dict:
    """A fully swept board built the way production builds it: every manifest goes through `grid_manifest`, so
    the `ready` block on each one is DERIVED, not typed. Handing a test `state: "unlooked"` would be supplying
    the very value production must compute, and the live defect lives in what production computes for a
    manifest that declares no refs.

    One manifest has already merged everything (resolved, nothing ready), one declares no refs at all. The
    optional `extra` is a third, declared-only manifest that was never swept.
    """
    done = link_grid.grid_manifest(
        {
            "program": "done",
            "rows": [{"ref": f"o/r#{n}", "order": str(n), "lane": "L", "status": "merged"} for n in (1, 2, 3)],
        },
        {f"o/r#{n}": {"state": "merged"} for n in (1, 2, 3)},
        {},
    )
    empty = link_grid.grid_manifest({"program": "empty", "rows": []}, {}, {})
    manifests = [done, empty] + ([link_grid.grid_manifest(extra, {}, {})] if extra else [])
    declared = sum(len(manifest["nodes"]) for manifest in manifests)
    unresolved = sum(
        1
        for manifest in manifests
        for node in manifest["nodes"].values()
        if node["state_source"] not in link_grid.RESOLVED_STATE_SOURCES
    )
    block = dict(_doc()["grid"])
    block.update({"manifests": manifests, "declared": declared, "unresolved": unresolved, "swept": True})
    return _doc(grid=block)


def test_the_derived_fixture_really_produces_the_state_the_defect_needs():
    """Guards the guard: if `grid_manifest` ever stopped calling an empty manifest `unlooked`, the two cases below
    would pass for the wrong reason. The premise is asserted, not assumed."""
    manifests = _swept_board_doc()["grid"]["manifests"]
    assert [manifest["ready"]["state"] for manifest in manifests] == ["known", "unlooked"]
    assert manifests[1]["nodes"] == {}


def test_a_fully_swept_board_with_nothing_ready_never_says_nobody_looked():
    """AC1 of the doorways directive. MUTATION: drop the `bool(nodes)` guard from `_is_unlooked`.

    Live cause: three manifests that declare no refs have nothing to resolve, so `ready_refs` calls their READY set
    `unlooked`. `_waiting` already ignored them, `_next_tally` did not, so NEXT said `nobody looked` above a
    WAITING ON YOU that had looked just fine, while STACKS said `0 unresolved`.
    """
    doc = _swept_board_doc()
    assert doc["grid"]["unresolved"] == 0 and doc["grid"]["declared"] == 3
    next_block = "\n".join(_next_body(doc))
    assert "nobody looked" not in next_block
    assert "0 ready of 3" in next_block and "nothing is ready" in next_block
    page = plain(render.document(doc))
    assert "nobody looked" not in page
    assert _page_tail(doc)[-1] == "  next  nothing is ready  borg next"


def test_an_unswept_manifest_still_makes_next_say_nobody_looked_beside_an_empty_one():
    """The three-state rule survives the fix: a manifest that DECLARES refs and resolved none is still unlooked,
    and an empty manifest next to it does not hide that. MUTATION: make `_is_unlooked` return False always."""
    doc = _swept_board_doc(extra={"program": "declared", "rows": [{"ref": "o/r#9", "order": "1", "lane": "L"}]})
    assert doc["grid"]["unresolved"] == 1
    assert "nobody looked" in "\n".join(_next_body(doc))


def test_a_ready_row_carries_its_provenance_mark():
    """A10. MUTATION: build the glyph locally instead of calling picture.

    The `●` this section prints is the one AC4's precondition was filed to protect: off an
    unresolved state it reads "start this now" from a hand-typed field. `ready_refs` makes that
    unreachable by construction, and this is the belt to that braces -- if a declared node ever does
    reach the list, it renders `●?` rather than a confident `●`.
    """
    declared = _ready_doc(["o/r#1"], nodes={"o/r#1": {"state_source": "declared"}})
    swept = _ready_doc(["o/r#1"], nodes={"o/r#1": {"state_source": "swept"}})
    assert picture.PROVENANCE_MARK in "\n".join(_next_body(declared))
    assert picture.PROVENANCE_MARK not in "\n".join(_next_body(swept))


def test_next_true_orders_within_a_group_and_never_grants_membership():
    """`rows[].next` is EMPHASIS, not an override. MUTATION: let `next` add a row to READY.

    AC4 names `rows[].next` as an input without saying what it does, and the two readings are not
    close. As an override, a hand-typed flag would put a row into NEXT whose parent has not merged --
    a hand-typed field beating a resolved one, which is the precondition's failure arriving through a
    different door. As emphasis it costs nothing when stale.
    """
    doc = _ready_doc(["o/r#1", "o/r#2"], nodes={"o/r#2": {"next": True}})
    rows = [line for line in _next_body(doc) if "o/r#" in line]
    assert rows[0].strip().endswith("o/r#2"), "the flagged row leads its group despite sorting second"

    # ...and a flagged row that is NOT ready stays out entirely.
    absent = _ready_doc(["o/r#1"], nodes={"o/r#2": {"next": True}})
    assert "o/r#2" not in "\n".join(_next_body(absent))


def test_a_partly_unlooked_board_reports_both_halves():
    """Orchestrator scope with one manifest resolved and one not. MUTATION: drop the `unlooked` note.

    Reporting a bare `1 ready of 2` there understates the answer as confidently as reporting zero:
    the reader is told what IS ready without being told that part of the board was never checked. The
    `unlooked` sentence only WINS outright when nothing at all resolved -- with a real answer present,
    it qualifies rather than replaces.
    """
    resolved = _ready_doc(["o/r#1"], declared=2)["grid"]["manifests"][0]
    blind = dict(resolved)
    blind["ready"] = {"state": "unlooked", "refs": []}
    block = dict(_doc()["grid"])
    block.update({"manifests": [resolved, blind], "declared": 2})

    body = "\n".join(_next_body(_doc(grid=block)))
    assert "1 ready of 2" in body
    assert "nobody looked up" in body, "the un-checked half is named"
    assert "o/r#1" in body, "and the real answer still renders"


def test_the_router_covers_every_declared_gate_kind():
    """`unsure` is a DIVERGENCE GUARD, and this is the case that gives it a job.

    MUTATION: add a third member to `manifest_core.GATE_KINDS` without adding it to `_GATE_ROUTING`.

    `GATE_KINDS` no longer gates validation — any non-empty kind loads now — so it is purely the
    DECLARED vocabulary, the set of kinds this repository says it understands. The invariant is that the
    router is never BEHIND that declaration: a kind added to the declared set and forgotten in
    `_GATE_ROUTING` would fall to `unsure` and be reported as unroutable when it is in fact a kind we
    claim to know, which is a quieter wrong answer than the one `unsure` exists to prevent.

    Asserted as a subset rather than equality: the router is allowed to know about a kind the
    declaration has not caught up to, which is the safe direction. This is also the ONLY live tie
    between `GATE_KINDS` and any production code — see the constant's own comment.
    """
    routed = set(render._GATE_ROUTING)  # pylint: disable=protected-access
    assert set(manifest_core.GATE_KINDS) <= routed, (
        "a gate kind the validator admits but the router does not route would fall to a default side"
    )
    assert render._route("review") == render._GROUP_UNSURE  # pylint: disable=protected-access


# ── the board: WAITING ON YOU and the per-repository routing counts ─────────────────────────────────


def _gate(ref: str, kind: str, text: str) -> dict:
    return {"ref": ref, "kind": kind, "blocked_by": text, "resolved_by": "", "blocked_by_ref": ""}


def _waiting_body(doc: dict) -> list[str]:
    """The lines between the WAITING ON YOU header and the next section header (or the end)."""
    out, inside = [], False
    for line in plain(render.document(doc)).split("\n"):
        if line.startswith(f"{render.SECTION_MARK}WAITING ON YOU"):
            inside = True
            continue
        if line.startswith(render.SECTION_MARK):
            inside = False
        if inside and line.strip() and not line.startswith("  next  "):
            out.append(line)
    return out


def _page_tail(doc: dict, n: int = 5) -> list[str]:
    """The last `n` non-blank lines of the page, plain -- what `borg link | tail -5` shows."""
    return [line for line in plain(render.document(doc)).split("\n") if line.strip()][-n:]


def test_waiting_on_you_is_always_present_and_says_so_when_empty():
    """Board AC4. MUTATION: drop the entry from SECTIONS, or return [] from `_waiting_section`."""
    page = plain(render.document(_doc()))
    assert f"{render.SECTION_MARK}WAITING ON YOU" in page
    assert _waiting_body(_doc()) == ["  — nothing waits on you"]


def test_waiting_on_you_is_the_last_section():
    """link-unification L3 wins over the mock's position: the answer lands at the bottom."""
    assert render.SECTIONS[-1][0] == "WAITING ON YOU"


def test_waiting_on_you_prints_one_line_per_yours_row_and_no_mine_rows():
    """Board AC4 (populated). Only `yours` rows wait on the reader; `mine` and ungated rows never do."""
    doc = _ready_doc(
        ["o/r#1", "o/r#2", "o/r#3"],
        gates=[_gate("o/r#1", "decision", "Dana signs off"), _gate("o/r#2", "verification", "canary must pass")],
        nodes={"o/r#1": {"children": ["o/r#9", "o/r#8"]}},
    )
    body = _waiting_body(doc)
    assert len(body) == 1
    assert "o/r#1" in body[0] and "Dana signs off" in body[0] and "unblocks 2" in body[0]
    assert "o/r#2" not in "\n".join(body) and "o/r#3" not in "\n".join(body)


def test_waiting_on_you_does_not_claim_nothing_waits_when_nobody_looked():
    """A `--local` page cannot know. MUTATION: delete the `unlooked` arm in `_waiting_section`."""
    doc = _ready_doc([], nodes={"o/r#1": {"state_source": "declared"}}, state="unlooked")
    page = plain(render.document(doc))
    assert "WAITING ON YOU  nobody looked" in page and "nothing waits on you" not in page


def test_waiting_item_text_is_truncated_to_one_line():
    doc = _ready_doc(["o/r#1"], gates=[_gate("o/r#1", "decision", "x" * 200)])
    body = _waiting_body(doc)
    assert len(body) == 1 and "…" in body[0]


def test_the_board_counts_a_repositories_routed_next_rows_and_dashes_the_rest():
    """The counts are `▸ NEXT`'s rows per owner, attributed by the manifest's path. MUTATION: count
    `yours` rows into the `mine` bucket, or attribute by basename instead of path prefix."""
    doc = _ready_doc(
        ["o/r#1", "o/r#2", "o/r#3"],
        gates=[_gate("o/r#1", "decision", "a"), _gate("o/r#2", "decision", "b"), _gate("o/r#3", "weird", "c")],
    )
    doc["grid"]["manifests"][0]["path"] = "/work/alpha/.borg/chains/m.json"
    entry = {"path": "/work/alpha", "source": "cli", "status": "idle", "relative_activity": "now"}
    doc.update(
        total_projects=2,
        order=["alpha", "beta"],
        projects={"alpha": entry, "beta": {**entry, "path": "/work/beta"}},
    )
    assert render._routing_counts(doc) == {"alpha": {"yours": 2, "mine": 0, "unsure": 1}}  # pylint: disable=protected-access
    rows = {
        line.split()[0]: line for line in plain(render.document(doc)).split("\n") if line[1:6] in ("alpha", "beta ")
    }
    assert "YOURS" in plain(render.document(doc))
    assert " 2    –      1" in rows["alpha"]
    assert " –    –      –" in rows["beta"]


def test_an_unlooked_manifest_with_no_refs_does_not_cloud_waiting_on_you():
    """MUTATION: set `unlooked = True` unconditionally in `_waiting`. Three empty manifests did this live."""
    doc = _ready_doc([], state="unlooked", declared=0)
    doc["grid"]["manifests"][0]["nodes"] = {}
    assert _waiting_body(doc) == ["  — nothing waits on you"]


def test_the_page_ends_on_one_next_action_with_a_runnable_command_for_a_yours_row():
    """link-unification L3: `borg link | tail -5` holds the recommended action and its command.

    MUTATION: drop `action` from the lines `_waiting_section` returns and this goes red. The first `yours`
    row wins over a `mine` row that sorts before it.
    """
    doc = _ready_doc(["a/b#1", "o/r#2"], gates=[_gate("o/r#2", "decision", "Dana signs off")])
    tail = _page_tail(doc)
    assert tail[-1].startswith("  next  #2")
    assert tail[-1].endswith("gh pr view 2 -R o/r")
    assert sum(1 for line in tail if line.startswith("  next  ")) == 1


def test_the_next_action_falls_back_to_the_first_mine_row_then_to_a_nothing_ready_sentence():
    """The documented order: yours, else mine, else a sentence. MUTATION: make `_first_mine` return None."""
    assert _page_tail(_ready_doc(["a/b#1"]))[-1].endswith("gh pr view 1 -R a/b")
    assert _page_tail(_ready_doc([]))[-1] == "  next  nothing is ready  borg next"
    unlooked_tail = _page_tail(_ready_doc(["a/b#1"], state="unlooked"))[-1]
    assert "nobody looked" in unlooked_tail
    assert unlooked_tail.endswith("borg next")


def test_the_next_action_never_puts_a_malformed_ref_on_a_command_line():
    """A ref that is not `owner/repo#N` gets `borg next`, never an interpolated shell fragment."""
    assert render._next_action_command("x; rm -rf /#1") == "borg next"  # pylint: disable=protected-access
    assert render._next_action_command("o/r#7") == "gh pr view 7 -R o/r"  # pylint: disable=protected-access


def test_the_next_action_line_ends_both_pages_but_a_directory_sees_only_its_own_items():
    """The final line is a `next` line with a runnable command on BOTH pages (L3). What differs is its input:
    the Queen's sees the manifest decision, a directory's does not, because a manifest row is a fact about the
    repository and not about this checkout. MUTATION: restore the manifest read in `_waiting` for repository
    scope and the directory's page recommends a pull request that is not its own."""
    doc = _ready_doc(["o/r#2"], gates=[_gate("o/r#2", "decision", "Dana signs off")])
    repo = {**doc, "scope": {"kind": "repository"}}
    assert _page_tail(doc)[-1].startswith("  next  #2") and _page_tail(doc)[-1].endswith("gh pr view 2 -R o/r")
    last = _page_tail(repo)[-1]
    assert last.startswith("  next  ") and last.endswith("borg next")
    assert "o/r#2" not in last


# ── the page of repository scope: strictly one directory (2026-10-13) ───────────────────────────────


def _worktree_focus(**overrides) -> dict:
    return _focus(
        name="door",
        entry={
            "path": "/dev/borg-door",
            "source": "cli",
            "status": "active",
            "last_activity": "2026-10-13T09:00:00Z",
            "tmux_window": "door",
            "claude_session_id": "sess-door-1",
            "summary": "Own summary.",
        },
        identity={"kind": "worktree", "branch": "feat-x", "worktree_of": "borg"},
        checkpoints=["2026-10-13-0900.md"],
        checkpoint_head="# Own checkpoint",
        **overrides,
    )


def _door_doc(**overrides) -> dict:
    """A directory's document that ALSO carries every repository-level thing the Queen's page would print.

    The registry-wide keys are populated on purpose: the page must be strictly the directory by CHOICE, not
    because the document happened to be thin.
    """
    others = {
        "door": {"source": "cli", "status": "active", "relative_activity": "1h ago", "summary": "Own summary."},
        "sibling": {"source": "cli", "status": "waiting", "relative_activity": "2h ago", "summary": "Sibling work."},
        "other-repo": {"source": "cli", "status": "idle", "relative_activity": "3d ago", "summary": "Elsewhere."},
    }
    base = {
        "focus": _worktree_focus(plan={"objective": "A plan.", "met": 1, "total": 2}),
        "total_projects": 3,
        "order": ["door", "sibling", "other-repo"],
        "projects": others,
        "directives": [{"project": "other-repo", "title": "Queued elsewhere"}],
        "assimilated": [{"project": "other-repo", "title": "Shipped elsewhere", "ship_date": "2026-01-01"}],
    }
    base.update(overrides)
    doc = _repository_doc(**base)
    doc["scope"]["repository"] = "door"
    doc["grid"]["warnings"] = ["sweep: a repository-level warning"]
    doc["grid"]["manifests"] = [_fork_block()]
    return doc


def test_a_worktree_page_is_strictly_that_directory():
    """The decision in one case. MUTATION: make `_sections_for` return SECTIONS for repository scope, or add any
    repository-level builder to REPOSITORY_SECTIONS -- every absence below goes red."""
    out = plain(render.document(_door_doc()))
    assert out.startswith("▸ IN FOCUS  door — worktree of borg\n")
    for kept in (
        "Path:         /dev/borg-door",
        "Branch:       feat-x",
        "Worktree of:  borg",
        "Status:       active",
        "sess-door-1",
        "Own summary.",
        "2026-10-13-0900.md",
        "# Own checkpoint",
    ):
        assert kept in out, kept
    for absent in (
        "THE BORG COLLECTIVE",
        "Tip:",
        "REPOSITORIES",
        "STACKS",
        "QUEUED",
        "SHIPPED",
        "NEXT",
        "SIGNALS",
        "Active Plan",
        "sibling",
        "other-repo",
        "Sibling work.",
        "Elsewhere.",
        "Queued elsewhere",
        "Shipped elsewhere",
        "auth-hardening",
        "a repository-level warning",
    ):
        assert absent not in out, absent


def test_a_main_checkout_page_is_labelled_a_main_checkout_and_has_no_worktree_of_line():
    focus = _worktree_focus()
    focus["identity"] = {"kind": "checkout", "branch": "main", "worktree_of": ""}
    out = plain(render.document(_door_doc(focus=focus)))
    assert out.startswith("▸ IN FOCUS  door — main checkout\n")
    assert "Branch:       main" in out
    assert "Worktree of:" not in out


def test_the_identity_lines_are_omitted_when_git_did_not_state_them():
    """A non-git directory has no branch and no relationship; a blank `Branch:` would state a falsehood."""
    focus = _worktree_focus()
    focus["identity"] = {"kind": "directory", "branch": "", "worktree_of": ""}
    out = plain(render.document(_door_doc(focus=focus)))
    assert out.startswith("▸ IN FOCUS  door\n")
    assert "Branch:" not in out and "Worktree of:" not in out
    del focus["identity"]
    assert plain(render.document(_door_doc(focus=focus))).startswith("▸ IN FOCUS  door\n")


def test_a_detached_head_worktree_states_where_it_is_detached():
    """A detached HEAD has no branch NAME but is not unstated: the row says `detached at <short sha>`.

    MUTATION: drop the `elif` in `_focus_section` and the row vanishes, which is the defect decision (7) closes.
    A real branch still wins over a stray `detached` key, and `Worktree of:` is unaffected.
    """
    focus = _worktree_focus()
    focus["identity"] = {"kind": "worktree", "branch": "", "worktree_of": "borg", "detached": "8afb0b4"}
    out = plain(render.document(_door_doc(focus=focus)))
    assert "Branch:       detached at 8afb0b4" in out
    assert "Worktree of:  borg" in out
    focus["identity"] = {"kind": "worktree", "branch": "feat-x", "worktree_of": "borg", "detached": "8afb0b4"}
    assert "detached at" not in plain(render.document(_door_doc(focus=focus)))


def _unregistered_doc() -> dict:
    """The document of a cwd that is neither the Queen root nor inside a registered path: the FULL registry-wide
    document is on the wire (`--json` is scope-independent), and only `scope.unregistered` says not to show it."""
    doc = _doc(
        total_projects=2,
        order=["alpha-secret", "beta-secret"],
        projects={
            "alpha-secret": {"source": "cli", "status": "idle", "path": "/dev/alpha-secret", "summary": "Alpha."},
            "beta-secret": {"source": "cli", "status": "waiting", "path": "/dev/beta-secret", "summary": "Beta."},
        },
        directives=[{"project": "alpha-secret", "title": "Queued elsewhere", "slug": "q"}],
    )
    doc["scope"] = {"kind": "orchestrator", "repository": None, "local": False, "unregistered": True}
    return doc


def test_an_unregistered_directory_prints_the_hint_page_and_never_the_overview():
    """Decision (3): a stranger directory is told what it is not and given two commands. MUTATION: drop the
    `_is_unregistered` arm in `_sections_for` and the whole overview (every registry name) renders again."""
    out = plain(render.document(_unregistered_doc()))
    assert "This directory is not a registered repository." in out
    assert "borg add" in out
    assert "borg link --overview" in out
    for absent in ("alpha-secret", "beta-secret", "THE BORG COLLECTIVE", "REPOSITORIES", "QUEUED", "WAITING ON YOU"):
        assert absent not in out, absent
    assert _headers(render.document(_unregistered_doc())) == []


def test_the_queen_root_with_no_unregistered_key_still_renders_the_overview():
    """The hint is keyed on the additive key alone: the same document without it is the Queen's page."""
    doc = _unregistered_doc()
    del doc["scope"]["unregistered"]
    out = plain(render.document(doc))
    assert "alpha-secret" in out and "REPOSITORIES" in out
    assert "not a registered repository" not in out


def test_a_directory_page_points_at_the_queen_view_and_still_ends_on_the_next_action():
    """L3: the answer is the last line. The pointer is ABOVE it. MUTATION: move the pointer entry after
    WAITING ON YOU in REPOSITORY_SECTIONS and the last-line assertion goes red."""
    lines = plain(render.document(_door_doc())).split("\n")
    pointer = next(i for i, line in enumerate(lines) if "borg link --overview" in line)
    waiting = next(i for i, line in enumerate(lines) if line.startswith("▸ WAITING ON YOU"))
    assert "Queen view" in lines[pointer]
    assert pointer < waiting
    body = [line for line in lines if line.strip()]
    assert body[-1].startswith("  next  ") and body[-1].endswith("borg next")


def test_a_directorys_waiting_section_holds_its_own_session_row_only():
    """MUTATION: drop the repository-scope filter in `render._waiting` and the PR row, the manifest decision and
    the `+N` hidden counts -- all repository-level -- come back onto a page about one checkout."""
    session = {"project": "door", "item": "session", "next_step": "reply to session", "owner": "YOU", "ref": None}
    pull_request = {"project": "door", "item": "Fix the thing", "next_step": "merge", "owner": "YOU", "ref": "o/r#9"}
    doc = _door_doc(
        waiting={
            "rows": [session, pull_request],
            "hidden": {"agent": 2, "stale": 0, "overflow": 0},
            "hidden_lines": ["+2 agent tasks"],
            "degraded": None,
        }
    )
    out = plain(render.document(doc))
    assert "▶ session" in out and "reply to session" in out
    assert "o/r#9" not in out and "Fix the thing" not in out
    assert "agent tasks" not in out

    queen = plain(render.document({**doc, "focus": None, "scope": {"kind": "orchestrator"}}))
    assert "Fix the thing" in queen and "+2 agent tasks" in queen


def test_a_directory_with_nothing_waiting_says_so_and_still_gives_a_runnable_next_action():
    out = plain(render.document(_door_doc()))
    assert "— nothing waits on you" in out
    assert [line for line in out.split("\n") if line.strip()][-1] == "  next  nothing is ready  borg next"
    assert "nothing here waits on you" not in out, "no repository rows, so the plain sentence stands"


def _you_row(project: str, number: int) -> dict:
    return {
        "project": project,
        "item": f"Synthetic PR {number}",
        "next_step": "merge",
        "owner": "YOU",
        "ref": f"example/{project}#{number}",
    }


def test_a_directory_never_says_nothing_waits_while_its_repository_has_you_rows():
    """AC1 of the doorways directive. MUTATION: drop `_repository_you_count` from `_waiting_section` and the page
    prints `nothing waits on you` above two rows that `borg next --rows` holds for this very repository.

    The page stays strictly about its own directory: the rows are COUNTED and `borg next` is named, never listed.
    A row for another repository does not count, and the directory's own session row is not a repository row.
    """
    rows = [_you_row("borg", 436), _you_row("borg", 437), _you_row("elsewhere", 85)]
    waiting = {"rows": rows, "hidden": {}, "hidden_lines": [], "degraded": None}
    out = plain(render.document(_door_doc(waiting=waiting)))
    assert "nothing waits on you" not in out
    assert "— nothing here waits on you · 2 for borg: borg next" in out
    assert "#436" not in out and "#437" not in out and "#85" not in out, "counted, not listed"
    assert [line for line in out.split("\n") if line.strip()][-1] == "  next  nothing is ready  borg next"


def test_the_count_line_is_singular_for_one_row_and_absent_for_none():
    one = {"rows": [_you_row("borg", 436)], "hidden": {}, "hidden_lines": [], "degraded": None}
    assert "nothing here waits on you · 1 for borg: borg next" in plain(render.document(_door_doc(waiting=one)))
    none = {"rows": [_you_row("elsewhere", 85)], "hidden": {}, "hidden_lines": [], "degraded": None}
    assert "— nothing waits on you" in plain(render.document(_door_doc(waiting=none)))


def test_the_count_line_names_the_repository_of_a_main_checkout_too():
    """A main checkout has no `worktree_of`; its own registry name is the repository."""
    doc = _door_doc(waiting={"rows": [_you_row("door", 7)], "hidden": {}, "hidden_lines": [], "degraded": None})
    doc["focus"]["identity"] = {"kind": "main", "branch": "main"}
    assert "nothing here waits on you · 1 for door: borg next" in plain(render.document(doc))


def test_a_directory_with_its_own_item_still_prints_the_item_and_no_nothing_sentence():
    session = {"project": "door", "item": "session", "next_step": "reply to session", "owner": "YOU", "ref": None}
    waiting = {"rows": [session, _you_row("borg", 436)], "hidden": {}, "hidden_lines": [], "degraded": None}
    out = plain(render.document(_door_doc(waiting=waiting)))
    assert "▶ session" in out and "nothing waits on you" not in out and "nothing here waits" not in out


def test_a_degraded_waiting_block_is_still_reported_on_a_directory_page():
    out = plain(render.document(_door_doc(waiting={"rows": [], "hidden_lines": [], "degraded": "boom"})))
    assert "rows degraded: boom" in out


# ── the Queen's board collapses worktrees under their repository (2026-10-13) ───────────────────────


_COMMON = "/dev/borg/.git"


def _grouped_board_doc() -> dict:
    repositories = {
        "door": {
            "source": "cli",
            "status": "waiting",
            "relative_activity": "1h ago",
            "summary": "Door.",
            "path": "/dev/borg-door",
            "repo": _COMMON,
        },
        "borg": {
            "source": "cli",
            "status": "idle",
            "relative_activity": "2h ago",
            "summary": "Borg.",
            "path": "/dev/borg",
            "repo": _COMMON,
        },
        "solo": {
            "source": "cli",
            "status": "idle",
            "relative_activity": "3d ago",
            "summary": "Solo.",
            "path": "/dev/solo",
        },
    }
    return _doc(total_projects=3, order=["door", "borg", "solo"], projects=repositories)


def test_the_board_collapses_worktrees_under_their_repository():
    """MUTATION: iterate `order` directly in `_board_section` (the old loop) and `door` prints as its own
    repository, the note counts three, and the worktree is not indented under `borg`."""
    out = plain(render.document(_grouped_board_doc()))
    assert "▸ REPOSITORIES  the collective · 2 repositories · 1 worktree · 1 need attention" in out
    rows = [line for line in out.split("\n") if line.lstrip(" *").startswith(("borg", "└ door", "solo"))]
    assert [line.lstrip(" *").split()[0] for line in rows] == ["borg", "└", "solo"]
    assert rows[1].lstrip(" *").startswith("└ door")
    # ...and the worktree's own status is still visible: a waiting session matters to the Queen.
    assert "waiting <<<" in rows[1]


def test_the_board_header_still_describes_its_rows_with_a_worktree_prefix():
    """The prefix is part of the displayed name, so it is measured: a name at the column floor plus `└ ` must
    widen the header, not push the SRC column out from under it."""
    doc = _grouped_board_doc()
    doc["projects"]["door"]["display_name"] = "d" * 20
    lines = plain(_full(doc)).split("\n")
    header = next(line for line in lines if " SRC " in line and "STATUS" in line)
    row = next(line for line in lines if "└ " in line and "[C]" in line)
    assert header.index("SRC") == row.index("[C]")


def test_a_board_with_no_shared_repo_is_unchanged_by_grouping():
    doc = _doc(
        total_projects=2,
        order=["a", "b"],
        projects={
            "a": {"source": "cli", "status": "idle", "relative_activity": "1h ago", "summary": "A."},
            "b": {"source": "cli", "status": "idle", "relative_activity": "2h ago", "summary": "B."},
        },
    )
    out = plain(_full(doc))
    assert "▸ REPOSITORIES  the collective · 2 repositories · 0 need attention" in out
    # The legend names `└ worktree` on every Queen page, so the check reads the board alone.
    board = out.split("▸ REPOSITORIES")[1].split("▸ STACKS")[0]
    assert "worktree" not in board.split("\n", 1)[1] and "└" not in board
