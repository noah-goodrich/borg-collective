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

from borg_core.link import cli, picture, render
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
    return base


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
    assert public == {"document", "porcelain"}


def test_the_human_arm_names_render_document_exactly_once():
    """Source-text, not behavioural, and deliberately so: a second `render.document(doc)` call in
    `_run` would render identically and cost twice, and no output assertion can see it."""
    source = inspect.getsource(cli._run)  # pylint: disable=protected-access
    assert source.count("render.document(") == 1
    assert "render.overview" not in source
    assert "render.deep" not in source


# ── R3/R4: the spine, and the empty-section rule that makes it assertable ──────────────────────────


def test_every_section_renders_its_header_in_both_contexts():
    """The invariant compares each context against the SECTIONS CONSTANT, never against the other
    context: a header diff between two renderings goes green if both drift together."""
    expected = [title for title, _ in render.SECTIONS if title]
    # A9. EIGHT SECTIONS SINCE AC4. This list going red is the reviewable event AC2's directive chose
    # over reserving an always-empty slot for yours-vs-mine ahead of time -- "a section that renders
    # only a placeholder in every context for a whole release is the exact 'reads as broken' failure
    # Q10 exists to prevent". NEXT sits below SHIPPED so the page reads history-then-future, and
    # above SIGNALS so the honest "nobody looked" line is the last word on a `--local` render.
    assert expected == ["IN FOCUS", "REPOSITORIES", "CHAINS", "QUEUED", "SHIPPED", "NEXT", "SIGNALS"]
    assert _headers(render.document(_doc())) == expected
    assert _headers(render.document(_repository_doc())) == expected


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
    for title in ("IN FOCUS", "CHAINS", "QUEUED", "SHIPPED", "SIGNALS"):
        assert len(body[title]) == 1, f"{title} rendered {body[title]}"
        assert body[title][0].startswith("  — "), body[title][0]
    # REPOSITORIES on an empty registry is the same rule with the zsh original's own sentence.
    assert body["REPOSITORIES"] == ["  — No projects registered. Run: borg scan"]


# ── R5: three diagnoses, not one sentence ─────────────────────────────────────────────────────────


# EVERY CASE HERE CARRIES A `scope_kind`, and the orchestrator one carries the EMPTY slug that
# `grid.repository_dir` actually produces there rather than a plausible-looking one. Varying `slug`
# alone -- which is how the spec states this ladder -- passes against a hand-built block while the
# third arm is unreachable in production, because orchestrator scope has no slug by contract.
_CHAINS_CASES = [
    ({"scope_kind": "orchestrator", "slug": ""}, "no project manifests in the registry yet"),
    ({"scope_kind": "repository", "slug": ""}, "no GitHub origin"),
    ({"scope_kind": "repository", "slug": "acme/ledger"}, "no project manifest declares work in acme/ledger"),
]


@pytest.mark.parametrize("grid_overrides,expected", _CHAINS_CASES)
def test_the_three_chains_placeholders_are_three_different_diagnoses(grid_overrides, expected):
    """An empty CHAINS section is the MODAL case -- 13 of ~14 registered repositories have no
    manifest -- so which of the three it is has to be readable off the page, not inferred."""
    doc = _doc()
    doc["grid"].update(grid_overrides)
    assert expected in render.document(doc)


def test_the_three_chains_placeholders_are_actually_distinct():
    sentences = set()
    for overrides, _ in _CHAINS_CASES:
        doc = _doc()
        doc["grid"].update(overrides)
        sentences.add(render._grid_placeholder(doc["grid"]))  # pylint: disable=protected-access
    assert len(sentences) == 3


def test_orchestrator_scope_never_reaches_the_no_origin_diagnosis():
    """The regression guard for the ladder's ORDER. `grid.repository_dir` returns "" for orchestrator
    scope by contract, so a slug-first ladder answers "this directory has no GitHub origin" for
    `borg link` run from the workspace root -- a diagnosis about a directory, on the one invocation
    that is not about a directory."""
    doc = _doc()
    doc["grid"].update({"scope_kind": "orchestrator", "slug": ""})
    out = render.document(doc)
    assert "no GitHub origin" not in out
    assert "no project manifests in the registry yet" in out


# ── R6: the two sentences the empty-registry early returns used to print ───────────────────────────


def test_empty_registry_and_all_archived_print_their_two_sentences():
    """Adapted from the three assertions that used to sit on `render.overview`. The sentences are
    verbatim; only the leading `▸` is gone, so `▸ ` stays an unambiguous section marker."""
    empty = render.document(_doc(total_projects=0))
    assert "No projects registered. Run: borg scan" in empty

    all_archived = render.document(_doc(total_projects=2, order=[], projects={}))
    assert "No projects to show. Run: borg link --all" in all_archived
    assert "No projects registered" not in all_archived


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
    assert "No projects to show. Run: borg link --all" in out


# ── R7/R8: what scope narrows, and what it must not ───────────────────────────────────────────────


def test_the_board_is_registry_wide_in_repository_scope():
    """REPOSITORIES is the one section breadth does NOT touch. skills/borg-switch runs
    `borg link --local --all` from a project session's cwd and reads the whole table out of it;
    borg.zsh's 5s watch redraw does the same. Narrowing it makes both a one-row list."""
    projects = {
        "p": {"source": "cli", "status": "active", "relative_activity": "2h ago", "summary": "Mine."},
        "other": {"source": "cli", "status": "idle", "relative_activity": "1d ago", "summary": "Theirs."},
    }
    doc = _repository_doc(total_projects=2, order=["p", "other"], projects=projects)
    out = render.document(doc)
    assert "other" in out
    assert "Theirs." in out
    # ...and the scoped row is MARKED rather than made the only row.
    marked = [line for line in out.split("\n") if "◀" in line]
    assert len(marked) == 1
    assert marked[0].lstrip().startswith("p ")


def test_queued_reads_focus_directives_in_repository_scope_and_the_aggregate_otherwise():
    """The `[project]` tag follows the breadth: information in the orchestrator context, noise in
    the repository's own."""
    aggregate = [{"project": "other", "title": "Someone else's directive"}]
    scoped = [{"title": "My directive"}]

    repository = render.document(_repository_doc(directives=aggregate, focus=_focus(directives=scoped)))
    assert "My directive" in repository
    assert "Someone else's directive" not in repository
    assert "[other]" not in repository

    orchestrator = render.document(_doc(directives=aggregate))
    assert "[other] Someone else's directive" in orchestrator


def test_shipped_follows_the_same_breadth_rule_as_queued():
    aggregate = [{"project": "other", "title": "Their ship", "ship_date": "2026-01-01"}]
    scoped = [{"title": "My ship", "ship_date": "2026-02-02"}]

    repository = render.document(_repository_doc(assimilated=aggregate, focus=_focus(assimilated=scoped)))
    assert "My ship (2026-02-02)" in repository
    assert "Their ship" not in repository

    orchestrator = render.document(_doc(assimilated=aggregate))
    assert "[other] Their ship (2026-01-01)" in orchestrator


# ── the transcribed IN FOCUS card (was `deep`) ────────────────────────────────────────────────────


def test_focus_path_line_omitted_entirely_when_path_is_the_string_null():
    out = render.document(_repository_doc())
    assert "Path:" not in out


def test_status_line_appears_exactly_once_on_the_whole_page_and_ends_in_the_status_word():
    """drone.zsh:964's `grep -m1 'Status:'` reads this line. The fixture below puts the literal
    `Status:` inside a PR title in CHAINS as well, which is the poisoning shape a real sweep
    produces -- IN FOCUS being section 2 is what keeps `-m1` landing on the right one."""
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
    out = render.document(doc)
    body_text = plain(out)
    status_lines = [line for line in body_text.split("\n") if "Status:" in line]
    assert len(status_lines) == 2  # the card's own line, plus the poisoned PR title below it
    assert status_lines[0].startswith("  Status:")
    assert status_lines[0].endswith("active")


def test_objective_omitted_with_no_placeholder_when_empty():
    doc = _repository_doc(focus=_focus(plan={"objective": "", "met": 0, "total": 2}))
    out = render.document(doc)
    assert "Objective:" not in out
    assert "0/2 criteria met" in out


def test_the_objective_folds_like_a_summary_instead_of_running_off_the_page():
    """MUTATION: restore `out.append(f"  {CYAN}Objective:{NC} {objective}\\n")` in `_focus_section`.

    IN FOCUS printed the objective RAW while `_summary_block`, three lines above it in the same
    section, folded at 70. Measured against this repo's own PROJECT_PLAN.md the emitted line was 129
    VISIBLE COLUMNS -- the widest row the document produces, and wider than the picture's own
    68-column budget. Nothing caught it because every fixture objective is one short line.

    ASSERTED AS A WIDTH BOUND, not as a set of expected break points: any honest fold satisfies it
    and the raw print cannot. The whole objective must still be PRESENT, so folding may not become
    truncating by another name.
    """
    objective = (
        "Land the derived-fact surface behind one front door, so that every consumer reads the same "
        "document, and no renderer re-derives a number the wire already published."
    )
    doc = _repository_doc(focus=_focus(plan={"objective": objective, "met": 1, "total": 2}))
    body = plain(render.document(doc)).split("\n")

    # The Active Plan block is `Objective:` then `Progress:`, so the objective owns every line
    # between them -- one, before this fix; as many as the fold needs, after it.
    start = next(i for i, line in enumerate(body) if line.startswith("  Objective:"))
    end = next(i for i, line in enumerate(body) if line.startswith("  Progress:"))
    block = body[start:end]

    assert len(block) > 1, "an objective well past 70 columns must wrap at all"
    for line in block:
        assert len(line) <= 72, f"{len(line)} columns: {line}"
        assert not line[2:3].isspace(), f"a continuation must never begin with a space: {line!r}"
    # Reassembling the block must give the objective back -- folding, never truncating.
    assert " ".join(part.strip() for part in block) == f"Objective: {objective}"


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
    out = render.document(doc)
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


def test_queued_and_shipped_share_one_bullet_loop_differing_only_by_the_project_tag():
    """QUEUED and SHIPPED were two byte-identical-except-for-the-tag loops until AC2 took the last
    difference out: the zsh original's per-block header lines are gone, and `_ship_date_suffix` reads
    an ABSENT key as "" -- so a directive and a shipped plan render through the same call."""
    directives = [{"project": "a", "title": "One"}]
    assimilated = [{"project": "a", "title": "Shipped", "ship_date": "2026-01-01"}]

    tagged = render._bullet_lines(directives, show_project=True)  # pylint: disable=protected-access
    untagged = render._bullet_lines(directives, show_project=False)  # pylint: disable=protected-access
    assert len(tagged) == len(untagged) == 1
    assert "[a]" in tagged[0]
    assert "[a]" not in untagged[0]
    assert tagged[0].replace("[a] ", "") == untagged[0]

    # A directive carries no ship date, and its bullet must not grow an empty "()" for the lack.
    assert "(" not in plain(untagged[0])
    shipped = render._bullet_lines(assimilated, show_project=False)  # pylint: disable=protected-access
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
    out = render.document(doc)
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
    """MUTATION: pad the header and the rows from `_COL_PROJECT` again instead of `_board_width`.

    `_COL_PROJECT` was used as a MINIMUM (`{display:<{_COL_PROJECT}}`) with no truncation anywhere,
    so a name longer than 20 pushed SRC / STATUS / LAST ACTIVE / SUMMARY right by the overflow while
    the header line, padded from the same constant, did not move. Every column label then sat over
    the wrong column, on EVERY render in both scopes. Two registered projects trigger it today
    (`pytest-coverage-impact` 22, `reveal-data-consistency` 23), which is why no fixture ever saw it:
    every fixture name is short.

    THE ASSERTION IS AN OFFSET, NOT A STRING. It finds where `SRC` starts on the header and where
    each row's `[C]` badge starts, and requires them equal. That is the property "the header
    describes its rows" stated in the only terms that can actually go red, and it holds for any
    width rule that is internally consistent -- including a future truncating one.

    THE DISPLAY NAME IS WHAT COUNTS, not the registry key: `_board_width` measures the same string
    `_overview_row` pads, or a renamed project reintroduces the bug through the other door.
    """
    long_display = "reveal-data-consistency"  # 23 -- the longest name in the real registry today
    assert len(long_display) > render._COL_PROJECT  # pylint: disable=protected-access
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
        if line.startswith(f"{render.SECTION_MARK}CHAINS")
    )

    assert f"swept back to {mark}" in note, note
    assert f"swept {mark}" not in note, f"the note reports a window bound as if it were a sweep time: {note}"

    # ...and an un-swept grid still says so, rather than naming a bound nobody swept against.
    block.update({"swept": False, "since": ""})
    unswept = next(
        line
        for line in plain(render.document(_doc(grid=block))).split("\n")
        if line.startswith(f"{render.SECTION_MARK}CHAINS")
    )
    assert "not swept" in unswept and "back to" not in unswept


def _fork_block() -> dict:
    """The approved mock's fork, all the way through grid_manifest -- a real block, not a hand-built
    one, so CHAINS is exercised against the shape production actually assembles.

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
    doc = _repository_doc()
    doc["grid"]["manifests"] = [_fork_block()]
    body_text = plain(render.document(doc))

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
    doc = _repository_doc()
    doc["grid"]["manifests"] = [block]
    body_text = plain(render.document(doc))

    # Drop the header LINE (which carries the section note) before reading the body.
    body = body_text.split("▸ CHAINS")[1].split("\n", 1)[1].split("▸ QUEUED")[0]
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

    doc = _repository_doc()
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
    clean = _repository_doc()
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


def test_two_pending_wakes_for_one_project_render_the_first_not_the_last():
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

    scoped = render.document(
        _repository_doc(focus=_focus(assimilated=[{"slug": "s", "title": "Deep shipped (C6)", "ship_date": ""}]))
    )
    assert "Deep shipped (C6)\x1b[0m\n" in scoped
    assert "()" not in scoped


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
    for line in plain(render.document(doc)).split("\n"):
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
                "blocked_by": "Kelly signs off",
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
    assert "Kelly signs off" in body, "the gate's own sentence is what says WHY it is yours"


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
    goes through `manifest_shell.discover` -- validate, `_drop_invalid_rows`, `gates()`, `ready_refs`,
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
    # `discover` takes REPOSITORY roots and globs `<root>/.borg/programs/`, so the shipped fixture is
    # copied into that layout rather than read in place -- the bytes under test are still the
    # fixture's.
    programs = tmp_path / "warehouse" / ".borg" / "programs"
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
    unlooked = "\n".join(_next_body(_ready_doc([], state="unlooked", declared=3)))
    assert "nothing is ready" in empty
    assert "0 ready of 3" in empty
    assert "nobody looked" in unlooked
    assert "nothing is ready" not in unlooked
    assert empty != unlooked


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
    DECLARED vocabulary, the set of kinds this project says it understands. The invariant is that the
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
