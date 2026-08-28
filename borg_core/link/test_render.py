"""Unit tests for borg_core.link.render -- the one human document and the untouched porcelain TSV.

These pin the sub-behaviours a byte-exact golden diff cannot localize: which branch fired, which
default applied, where a fold broke, which of three diagnoses a placeholder chose. The goldens under
tests/fixtures/link/ remain the primary oracle (exercised end to end via tests/cli_contract.bats);
these are the microscope.
"""

import datetime
import inspect
import re
import shutil
import subprocess
import time

import pytest

from borg_core.link import cli, picture, render
from borg_core.link import grid as link_grid
from borg_core.manifest import core as manifest_core
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


def test_signals_reports_the_ladders_gap_as_a_sentence_never_a_token():
    doc = _doc()
    doc["grid"].update({"declared": 11, "unresolved": 3})
    assert "3 of 11 declared refs unresolved — nobody looked" in render.document(doc)

    doc = _doc()
    doc["grid"].update({"declared": 7, "unresolved": 0})
    assert "7 of 7 declared refs resolved." in render.document(doc)

    # Nothing declared -> no line at all, rather than "0 of 0".
    assert "declared refs" not in render.document(_doc())


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
        out = render._summary_block("first half\nsecond half")  # pylint: disable=protected-access
        lines = out.split("\n")[:-1]
        assert all(_CONTINUATION_CONTRACT.match(line) for line in lines[1:]), lines
        assert lines[1] == "  first half second half"
        assert len(lines) == 2

    def test_summary_block_flattens_newlines_before_folding_not_after(self):
        # The flatten is one-for-one, so a newline occupies a space's worth of the 70-column budget
        # and the break lands exactly where an equivalent space would put it -- i.e. no golden moves.
        summary = "w" * 40 + "\n" + "x" * 40
        with_newline = render._summary_block(summary)  # pylint: disable=protected-access
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
        out = render._overview_summary_cut("first half\nsecond half")  # pylint: disable=protected-access
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
        exact = render._overview_summary_cut("a" * 49 + "\n")  # pylint: disable=protected-access
        assert exact == "a" * 49 + " "
        over = render._overview_summary_cut("a" * 50 + "\n" + "b")  # pylint: disable=protected-access
        assert over == "a" * 50 + "..."

    def test_cut_matches_the_equivalent_space_so_no_golden_moves(self):
        # The replacement is one-for-one, so both the 50-char cut and the strictly-greater-than-50
        # ellipsis test land identically to the same string written with a space. This is the claim
        # that no fixture golden moves.
        summary = "w" * 30 + "\n" + "x" * 30
        with_newline = render._overview_summary_cut(summary)  # pylint: disable=protected-access
        with_space = render._overview_summary_cut(summary.replace("\n", " "))  # pylint: disable=protected-access
        assert with_newline == with_space

    def test_cut_keeps_the_row_on_one_line_end_to_end(self):
        # The defect stated at the altitude the reader sees it: one registry entry, one board row.
        row = render._overview_row(  # pylint: disable=protected-access
            "alpha",
            {"source": "cli", "status": "idle", "relative_activity": "1h", "summary": "top\nbottom"},
            {},
        )
        assert row.count("\n") == 1
        assert row.endswith("top bottom\n")


# ── the summary field's THIRD consumer, and the character set all three share ─────────────────────
# `_summary_block` is the fold's defense and `_overview_summary_cut` is the board's. `porcelain` is
# the third and is the one with the worst failure -- it serializes `summary` into a TSV RECORD that
# `borg switch` parses by field, so a control character does not shear a line the user reads past, it
# invents a row the user can SELECT.
#
# The character set is read off `lib/registry.zsh`'s `_borg_registry_write` -- `tr -d
# '\000-\010\013\014\016-\037'` deletes 0x00-0x08, 0x0B, 0x0C and 0x0E-0x1F, so 0x09, 0x0A and 0x0D
# all reach storage. Parameterized rather than hand-listed per test, so widening the set is one edit.

_SURVIVING_WS = ["\t", "\n", "\r"]


@pytest.mark.parametrize("scrubbed", ["\x00", "\x08", "\x0b", "\x0c", "\x0e", "\x1f"])
def test_the_registry_scrub_set_is_enumerated_from_the_scrub_not_assumed(scrubbed):
    """A guard on the PREMISE, not on the renderer: every character the `tr -d` range deletes is one
    `_flatten_summary` deliberately does NOT handle, because it cannot arrive. If someone narrows the
    scrub in lib/registry.zsh they must revisit this list; if someone widens `_FLATTEN_WS` past the
    survivors they will find this test explaining why the extra characters were out of scope."""
    assert render._flatten_summary(scrubbed) == scrubbed  # pylint: disable=protected-access


@pytest.mark.parametrize("ch", _SURVIVING_WS)
def test_flatten_summary_maps_every_surviving_whitespace_control_to_one_space(ch):
    assert render._flatten_summary(f"a{ch}b") == "a b"  # pylint: disable=protected-access


@pytest.mark.parametrize("ch", _SURVIVING_WS)
def test_summary_block_flattens_every_surviving_control_not_just_newline(ch):
    # Consumer 1. A `\t` inside the fold input also breaks `^  [^ ]` reasoning -- `fold -s` counts a
    # tab as one column while a terminal expands it -- and a `\r` returns the cursor to column zero,
    # erasing the indent the re-indent loop just applied.
    out = render._summary_block(f"first half{ch}second half")  # pylint: disable=protected-access
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
        {"source": "cli", "status": "idle", "relative_activity": "1h", "summary": f"top{ch}bottom"},
        {},
    )
    assert row.count("\n") == 1
    assert row.endswith("top bottom\n")


@pytest.mark.parametrize("ch", _SURVIVING_WS)
def test_porcelain_emits_exactly_one_record_per_project_for_every_surviving_control(ch):
    """THE HONEST ASSERTION IS ON THE RECORD COUNT, and on the field count within the record.

    An assertion on the text alone ("the summary reads `top bottom`") passes on a build that emits
    TWO rows, because the first row still ends where the assertion stops looking. What `borg switch`
    actually consumes is a record per project and five tab-separated fields per record: an extra
    record is a phantom project in the picker, and a shifted field is `cut -f1` returning prose
    instead of a project name. Both are asserted here; neither is implied by the other.
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
    blocks nobody in particular because anyone can run it -- and they are the only two kinds any
    manifest has ever declared or that the validator will accept.
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

    UNREACHABLE THROUGH THE FRONT DOOR AND TESTED ANYWAY. `manifest_core.GATE_KINDS` is
    `{"decision", "verification"}` and validation drops the WHOLE manifest on anything else, so no
    valid file produces this row -- measured, by putting `kind: "review"` in auth-hardening.json and
    watching the orchestrator grid fall from 12 declared refs to 5. Same terms `GLYPH_DRAFT` was kept
    on through two ACs: the branch is one line and the day `GATE_KINDS` widens, a default would send
    a kind nobody understands to one of the two real sides with nothing mis-set.
    """
    doc = _ready_doc(
        ["o/r#3"],
        gates=[{"ref": "o/r#3", "kind": "review", "blocked_by": "", "resolved_by": "", "blocked_by_ref": ""}],
    )
    body = "\n".join(_next_body(doc))
    assert "unsure" in body
    assert '"review"' in body, "the reader is told WHICH kind failed to route"
    assert "yours" not in body and "mine" not in body


def test_the_unsure_group_is_absent_when_empty_but_the_section_is_not():
    """A7. MUTATION: render the `unsure` heading unconditionally.

    A GROUP may be absent; a SECTION may not. AC2's directive rejected reserving an always-empty
    section slot for yours-vs-mine as the "reads as broken" failure, and this is the line between the
    two ideas: NEXT always renders (with a placeholder when it has nothing), the groups inside it
    only render when populated. Zero manifests in existence declare an unrecognized kind.
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


def test_the_router_covers_every_gate_kind_the_validator_admits():
    """`unsure` is a DIVERGENCE GUARD, and this is the case that gives it a job.

    MUTATION: add a third member to `manifest_core.GATE_KINDS` without adding it to `_GATE_ROUTING`.

    The group cannot be reached through the front door today and that is not an oversight: the
    validator admits exactly `{decision, verification}` and the router routes exactly those two, so
    the sets coincide. What `unsure` protects against is the window where they STOP coinciding — a
    kind added to the validator and forgotten in the router would otherwise fall to whichever side a
    `.get(kind, default)` named, silently, with nothing mis-set.

    So the real invariant is not "unsure renders" (it should not, yet) but "the router is never
    behind the validator". Asserted as a subset rather than equality: the router is allowed to know
    about a kind the validator has not admitted yet, which is the safe direction.
    """
    routed = set(render._GATE_ROUTING)  # pylint: disable=protected-access
    assert set(manifest_core.GATE_KINDS) <= routed, (
        "a gate kind the validator admits but the router does not route would fall to a default side"
    )
    assert render._route("review") == render._GROUP_UNSURE  # pylint: disable=protected-access
