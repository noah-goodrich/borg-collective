"""The one human renderer for `borg link`, plus the machine TSV `--porcelain` still serializes.

TWO PUBLIC CALLABLES, AND THAT IS THE WHOLE OF AC2's "one front door". `document(doc)` is the single
human entry point: a fixed SEVEN-SECTION SPINE whose `▸` headers are byte-identical in every context,
where `scope` narrows the ROW SET of the four scope-dependent sections and never the board, never the
section list and never the order. `porcelain(doc)` is deliberately outside "everywhere" and its
LAYOUT is unchanged (one control-character flatten aside, see its docstring) -- it is not a renderer,
it is `borg link --porcelain`'s machine TSV, read BY FIELD, and box drawing in that stream would
break any consumer that splits it. IT DOES NOT FEED `borg switch`: this paragraph used to say it was
"the TSV feeding fzf's input list" and that is RETRACTED -- `porcelain`'s own docstring is the
canonical statement of the retraction and names who actually feeds the picker. Read it first.

`overview()` AND `deep()` ARE GONE. Their bodies survive, transcribed statement by statement, as
`_board_section` and `_focus_section`; `_summary_block`, `_fold_s`, `_label`, `_overview_row` and
every `_COL_*` width are the untouched parity surface underneath them. What used to be two modes of
one command answering the same question with different data is now two ROW SETS of one document.

IN FOCUS IS SECTION 2, ABOVE THE BOARD, AND THE ORDER IS LOAD-BEARING RATHER THAN AESTHETIC.
drone.zsh:964 extracts a session's status with `borg link --local "$w" | grep -m1 'Status:'`. Post-AC2
this page carries two classes of text the renderer does not control -- board summaries written by
checkpoint debriefs, and pull request titles arriving off the wire -- and a PR literally titled
`chore(auth): Status: normalise the rollout report` (which the golden fixture deliberately contains)
would poison `grep -m1` and render a stranger's PR title as a session status. Putting IN FOCUS first
makes the extraction correct BY CONSTRUCTION against all wire-sourced text, with no scrubbing rule a
future field can escape. Two supporting invariants hold it up: the grid's vocabulary says `state:`
and never `Status:`, and the board's column header stays `STATUS` (uppercase, colonless).

EVERY SECTION ALWAYS RENDERS ITS HEADER. A section with no rows renders that header plus EXACTLY ONE
dim placeholder line naming what would fill it and the one command that would -- which is the same
rule that makes "the two contexts differ in breadth only" mechanically assertable, because the header
list can then be compared against `SECTIONS` itself rather than against the other context's golden
(a header diff between two goldens goes green if both drift together).

UNCONDITIONALLY PURE, matching core.py's and picture.py's contract: no clock, no os.environ, no
subprocess, no filesystem, no isatty. Every function here takes the already-assembled `--json`
document (cli.py._document()) and returns ONE complete string, trailing newlines included.
`generated_at`, every `relative_activity` and every cortex `countdown` already come from ONE
shell.now_epoch() call threaded through cli._document; a second clock read here would reintroduce the
straddle the port removed. ANSI is emitted UNCONDITIONALLY -- there is no isatty check anywhere in the
link path (borg.zsh never added one) and adding one would fail every golden. Do not "fix" this.

Every default goes through core.jq_default -- a bare `or` is a review-blocking defect (see
jq_default's docstring for why: jq's `//` does not treat "" or 0 as absent).

NON-REPRODUCED DEVIATION, no test impact (record in the PR body): zsh's `echo` builtin expands
backslash escapes by default (`echo -e` is even more explicit about it), so every deep-dive line and
every Directives/Assimilated/cube line USED to interpolate data THROUGH escape expansion -- a
directive title or summary containing a literal `\\n` or `\\t` was EXPANDED. The overview table rows
went through `printf %s` and were NOT. Python's `print()` expands neither. No golden covers this; it
is not reproduced here.

LOCALE COLLATION NOTE, matching core.sort_assimilated's docstring: any per-project or aggregate
directive listing here inherits shell._markdown_files' codepoint-order glob, not zsh's/coreutils'
locale-collated order. Measured zero-impact across every real filename this repo has seen; recorded
so it does not surprise anyone later.
"""

# Measured, not asserted: 54% of this file is docstrings (34.5k of 64.4k bytes), so its ~500 lines of
# actual code sit well inside what C0302 targets. Splitting the module is filed; see the note below.
# JUSTIFICATION: this module is prose-dominated -- C0302 is measuring its design record, not its code.
# pylint: disable=too-many-lines
#
# THE CEILING IS TRIPPED BY THE DESIGN RECORD, NOT BY COMPLEXITY, AND THAT IS MEASURED RATHER THAN
# asserted: 54% of this file's bytes are docstrings (34.5k of 64.4k), across 39 functions holding 380
# statements. C0302 exists as a proxy for module complexity; the ~500 lines of actual code here are
# well inside what it targets, and every paragraph above the disable was written to stop a specific
# wrong answer being re-derived -- the porcelain/picker retraction, the enumerated scrub set, the
# per-call-site honesty about `_flatten_summary`. Cutting prose to satisfy a line count would trade
# the reasoning for the metric, which is the failure this repo files under "a check pointed at the
# wrong thing does not fail, it reads as a pass".
#
# THIS IS A DEFERRAL, NOT A VERDICT. The real fix is splitting the module along the seam that already
# exists -- the SECTIONS spine and its section builders on one side, the shared text primitives
# (`_fold_s`, `_flatten_summary`, `_label`, `_summary_block`) on the other. That is an architecture
# change and was deliberately not made inside a merge fix; it is filed as its own directive. The
# duplication this merge DID create (two branches each writing the same argument) was collapsed
# first, AST-verified as behavior-identical, which took the file from 1133 to 1108.

from __future__ import annotations

from typing import Callable

from borg_core.link import core, grid, picture
from borg_core.link.picture import BOLD, CYAN, DIM, GREEN, NC, YELLOW

# Overview column widths, hoisted so the header line and every row format string share ONE source
# of truth and cannot drift apart (borg.zsh:329, :371-372).
#
# `_COL_PROJECT` IS A FLOOR, NOT A WIDTH, AND SAYING SO IS THE FIX. It was used as a minimum via
# `{display:<{_COL_PROJECT}}` with no truncation anywhere, so a name longer than 20 pushed SRC,
# STATUS, LAST ACTIVE and SUMMARY right by the overflow while the header line -- padded from the same
# constant -- did NOT move, and stopped describing its own rows on EVERY render in both scopes. Two
# registered projects trigger it today (`pytest-coverage-impact` 22, `reveal-data-consistency` 23).
#
# WIDENED RATHER THAN TRUNCATED, ON THE READER'S TERMS AND NOT A CONSUMER'S: truncation destroys the
# one field on the row that is also an ARGUMENT (`pytest-coverage-impa…` is not typeable into `borg
# link <name>`), while widening costs only geometry that varies with the row set, which every golden
# absorbs by byte-comparing ONE invocation against its own file. NOTHING PARSES THIS BOARD -- checked, not asserted:
# every hit `grep -rn 'borg link' drone.zsh borg.zsh lib/ hooks/ skills/` returns is prose, a `--json` read, `drone
# link`'s `exec`, or skills/borg-switch's `borg link --local --all` -- THIS board's one automated reader, and it
# wants a list of names, not a column. (A draft cited `drone status`'s `grep -m1 'Status:'` -- retired 2026-08-27.)
_COL_PROJECT = 20
_COL_SRC = 4
_COL_STATUS = 12
_COL_LAST_ACTIVE = 12

# The deep dive's label column (borg.zsh:440-445): a 2-space indent PLUS a 14-wide label field, so
# every value starts at column 16 measured from the start of the line. col=14 is the padding target
# for the label text itself; the leading "  " is applied separately by _label below.
_DEEP_LABEL_COL = 14

# THE REGISTRY-STATUS jq FALLBACK, TRANSCRIBED FROM borg.zsh, AND EXPLICITLY NOT THE GRID'S STATE
# TOKEN. `borg link`'s zsh original wrote a jq `.status //` fallback of this word in the porcelain
# serializer and in both human renderers, for a REGISTRY status -- a different field, different question
# from `grid.nodes[].state`. Naming it is what lets AC2's rule about the grid's unresolved token be
# stated as a grep: this literal appears in this file exactly ONCE (here) and ZERO times in
# picture.py, which imports `grid.STATE_SOURCE_UNKNOWN` wherever the grid's token must be compared so
# the two modules cannot drift. Deleting these call sites is NOT a cleanup -- it changes the bytes
# link-overview.golden, link-deep.golden and drone.zsh:964's Status column read.
_JQ_ABSENT_STATUS = "unknown"

# The one unambiguous section marker on the page. Nothing else in this file may emit `▸ ` at the
# start of a line -- which is why the empty-registry and all-archived sentences below lost the
# leading `{GREEN}▸{NC}` they carried in the zsh original, and why SIGNALS' capacity warning lost
# its `{YELLOW}▸{NC}`. Both sentences are otherwise verbatim; every assertion on them anywhere in
# this tree is a substring test, which is why that change is free.
SECTION_MARK = "▸ "

# 0x09 TAB, 0x0A LF, 0x0D CR -- `_flatten_summary` enumerates why exactly these three, off the scrub.
_FLATTEN_WS = str.maketrans({"\t": " ", "\n": " ", "\r": " "})


def _flatten_summary(text: str) -> str:
    """Replace every registry-surviving whitespace control character in a registry `summary` with a
    single space. THE CANONICAL STATEMENT of the character set, the altitude and the call sites; the
    three call sites below carry pointers here rather than repeating any of it.

    THE SET IS ENUMERATED FROM `lib/registry.zsh`'s SCRUB, NOT ASSUMED. `_borg_registry_write` pipes
    through `tr -d '\\000-\\010\\013\\014\\016-\\037'`, which deletes 0x00-0x08, 0x0B (vertical tab),
    0x0C (form feed) and 0x0E-0x1F. Everything else reaches storage intact -- and of what remains,
    exactly three are whitespace that a renderer must not emit raw: 0x09 TAB, 0x0A LF, 0x0D CR. So the
    writer-side argument F1 made about newlines is true of all three, and the earlier defense was one
    character short at each end of it.

    THE DEFENSE IS PER-CALL-SITE. NOTHING INHERITS IT. An earlier revision of this docstring said
    "ONE HELPER, THREE CONSUMERS, so a fourth inherits the defense instead of repeating the bug."
    That is false and it is the kind of false that stops a follow-up from being written: calling this
    helper is OPT-IN at every site, so a fourth consumer that reads `entry["summary"]` directly
    reintroduces the bug with every test in this tree green. No chokepoint routes the field through
    here, and no test asserts that one does. THE UNBUILT ALTERNATIVE, named so it can be filed rather
    than rediscovered: flatten ONCE at document assembly (`cli._document`), so `summary` is already
    clean by the time any renderer sees it and this helper becomes unreachable. That is a design
    change and is deliberately NOT made here. Until it is, the honest statement is the one above --
    three call sites, each defended because it was edited to be.

    THE THREE CALL SITES, and how each breaks on the same byte. `_summary_block` -- IN FOCUS's fold; a
    raw control character emits a sub-line `_fold_s` never produced, which the re-indent loop
    therefore never indents, breaking its `^  [^ ]` continuation contract. `_overview_summary_cut` --
    the board's fixed-width table; `_overview_row` lays every column out with `:<{_COL_*}` padding, so
    a `\\n` or a `\\r` splits one row into two and shears every column after it. `porcelain` -- `borg
    link --porcelain`'s TSV, parsed BY FIELD, so a `\\n` ends a record early and a `\\t` shifts every
    field after it; NOT `borg switch`'s picker, see `porcelain` for that retraction.

    THE RENDERER OWNS THIS, NOT THE WRITER. Same altitude rule the `borg recon` retirement gate
    settled (CLAUDE.md; docs/plans/assimilated/2026-08-26-recon-retirement-gate-altitude.md): the
    artifact that implements the contract owns its invariant. Normalizing in `summarize.summarize_llm`
    -- whose `result.stdout.strip()[:500]` leaves interior control characters intact, unlike the
    heuristic path's `step[:200].replace("\\n", " ")` -- would fix today's one known writer and leave
    all three contracts undefended against the next. And the LLM is not the only possible source: the
    scrub above lets all three characters through, so a hand-edited registry produces one with no LLM
    involved at all.

    Replacement is ONE CHARACTER FOR ONE, so every width budget downstream (the 70-column fold, the
    50-char board cut and its `> 50` ellipsis, porcelain's 80-char cut) is unchanged for input that
    was already clean, and no golden moves. PRIVATE ON PURPOSE:
    `test_render_exposes_exactly_one_human_entry_point` asserts this module's public surface is
    exactly `{document, porcelain}` -- AC2's "one front door" -- so a shared helper here has to carry
    the underscore or it reads as a third entry point callers may route through.
    """
    return text.translate(_FLATTEN_WS)


def _label(text: str, value: str, col: int = _DEEP_LABEL_COL) -> str:
    """One `  {DIM}<label>{NC}<pad>value` IN FOCUS header line, padding computed as col - len(text)
    rather than six separately hand-counted space literals (borg.zsh:440-445)."""
    pad = " " * max(col - len(text), 1)
    return f"  {DIM}{text}{NC}{pad}{value}\n"


def _fold_s(text: str, width: int = 70) -> list[str]:
    """Reproduce `fold -s -w <width>`'s break points: break AFTER the last space at or before
    `width` (the space stays on the emitted line); hard-break at exactly `width` when the window
    contains no space at all.

    Pinned by cli_contract.bats's "link <project> deep dive wraps and indents a summary longer than
    70 columns": every continuation line must match `^  [^ ]` -- a continuation must never begin
    with a space. (Anchored by TEST NAME, not by line number. A 90-line insertion at the top of
    cli_contract.bats silently invalidated every `cli_contract.bats:<N>` pointer in this tree once
    already; names survive insertions.)

    GNU-vs-BSD, measured not assumed: a 1000-case randomized differential (varied word lengths,
    runs of spaces, leading/trailing spaces, words longer than the width, empty strings, widths
    1-70) run against BSD `fold` (macOS host) and GNU coreutils 9.4 `fold` (ubuntu:24.04 via
    Docker) produced ZERO disagreements between the two vendors, and this implementation matched
    both exactly. There is no known real divergence for this module's inputs; the differential
    test at test_render.py::TestFoldS::test_matches_real_fold_s_binary shells out to whichever
    `fold` is on PATH rather than hardcoding either vendor's output, so a future real divergence
    would surface as a platform-specific test failure instead of silently shipping wrong bytes.
    """
    lines: list[str] = []
    remaining = text
    while len(remaining) > width:
        window = remaining[:width]
        break_at = window.rfind(" ")
        if break_at == -1:
            lines.append(remaining[:width])
            remaining = remaining[width:]
        else:
            lines.append(remaining[: break_at + 1])
            remaining = remaining[break_at + 1 :]
    lines.append(remaining)
    return lines


def _summary_block(summary: str) -> str:
    """IN FOCUS's unconditional Summary block (borg.zsh:447-448):
    `echo -e "  ${BOLD}Summary${NC}"` then `echo -e "  $summary" | fold -s -w 70 | sed '1!s/^/  /'`.

    The two leading spaces on the first line COUNT against the 70-column fold budget; lines 2..n are
    re-indented to two spaces (NOT folded with the indent already applied).

    EMBEDDED WHITESPACE CONTROL CHARACTERS ARE FLATTENED TO SPACES HERE (F1), because the `^  [^ ]`
    continuation contract is this function's OWN invariant. See `_flatten_summary` for the character
    set, the altitude argument, and why the one-for-one replacement moves no golden.
    """
    out = [f"  {BOLD}Summary{NC}\n"]
    folded = _fold_s("  " + _flatten_summary(summary), width=70)
    for i, line in enumerate(folded):
        if i == 0:
            out.append(f"{line}\n")
        else:
            out.append(f"  {line}\n")
    return "".join(out)


# Named so `_objective_lines` slices the folded first line at exactly the prefix it built.
_OBJECTIVE_LABEL = "Objective:"


def _objective_lines(objective: str) -> list[str]:
    """The Active Plan objective, FOLDED the way `_summary_block` folds a summary.

    IT USED TO PRINT RAW, which was half of a two-part defect: `core.plan_objective` read one
    physical line of a wrapped paragraph, and this printed whatever it got with no fold at all,
    unlike every other prose field on the page. Measured on this repo's own PROJECT_PLAN.md the
    emitted line was 129 VISIBLE COLUMNS -- the widest row the document produces, wider than the
    picture's own 68-column budget, in the section a reader looks at first.

    THE PREFIXED STRING IS WHAT GETS FOLDED, at 70, through `_fold_s` -- byte for byte the
    arrangement `_summary_block` uses, so the section's two prose blocks cannot wrap differently.
    Continuations re-indent to two spaces, keeping the deep dive's `^  [^ ]` rule intact. The slice
    is safe by construction: `_fold_s` breaks after the last space at or before 70, `"  Objective: "`
    puts one at index 12, 12 < 70 -- so `rfind` never returns below 12 and the slice cannot bite into
    the label. THAT ARGUMENT WAS ONLY HALF OF ONE: a first token of 57+ chars pushes the next space
    past 70, leaving 12 the sole candidate, so the label line degenerates to `"  Objective: "` with
    the objective on the continuation (measured: shares the line at 56, not at 57). Left as is --
    not corruption, exactly what `fold -s -w 70` does with those bytes, and a 57-char unbroken token
    is a URL, whose fix belongs in `core.plan_objective` rather than a carve-out in a folder pinned
    to `fold`'s behaviour. Only the LABEL is coloured, so ANSI bytes never enter the width arithmetic.
    """
    prefix = f"  {_OBJECTIVE_LABEL} "
    folded = _fold_s(prefix + objective, width=70)
    out = [f"  {CYAN}{_OBJECTIVE_LABEL}{NC}{folded[0][len(prefix) - 1 :]}\n"]
    out.extend(f"  {line}\n" for line in folded[1:])
    return out


def _checkpoint_head_block(head: str) -> str:
    """Indent every line of a checkpoint head to two spaces, INCLUDING blank ones (borg.zsh:476's
    `head -20 "$f" | sed 's/^/  /'`, whose `^` anchor matches an empty line too).

    Drops a spurious trailing empty element: shell.read_latest_checkpoint_head encodes the file's
    trailing newline as an empty FINAL element after split("\\n"); a naive per-element loop would
    therefore emit one extra "  " line that `head -20` piped through `sed` never produces.
    """
    lines = head.split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    return "".join(f"  {line}\n" for line in lines)


def porcelain(doc: dict) -> str:
    """`--porcelain`: one TSV row per visible project, no color, no padding, no header.

    Empty or fully-filtered -> "" -- absolutely nothing, not even a trailing newline (pinned by
    cli_contract.bats's "link --porcelain prints nothing at all on an empty registry").

    UNCHANGED BY AC2, DELIBERATELY, and `tests/fixtures/link/link-porcelain.golden` must not move.
    It is a machine surface, not a page.

    THIS FUNCTION DOES NOT FEED `borg switch`. THE CANONICAL RETRACTION, and every other mention in
    this file now points here: the commit that added the flatten below asserted the opposite in its
    message and in two docstrings, and it is wrong. Traced through the call path rather than inferred:
    `cmd_switch` in `borg.zsh` builds the picker's stdin from `cmd_ls --porcelain`, whose porcelain
    branch is a SEPARATE ZSH IMPLEMENTATION -- it reads the registry with its own `jq` calls, cuts
    with `${summary:0:80}`, and emits the record with `printf '%s\\t%s\\t%s\\t%s\\t%s\\n'`. It never
    enters Python at all. So every consequence that earlier text attributed to this function -- the
    phantom fzf row, `cut -f1` handing prose to `_borg_do_switch` -- belongs to `cmd_ls --porcelain`,
    where it was live and where it is now fixed (the flatten and the `printf '%s' | jq` correction in
    `cmd_ls`, pinned by cli_contract.bats's "the picker feed stays one 5-field record per project
    through tab and newline" -- a title narrowed from "tab, newline and CR" because its counting
    oracle cannot kill a CR-only mutant). THE TWO IMPLEMENTATIONS ALREADY DIVERGE, which is why the
    mix-up was not harmless: on an empty registry this one prints nothing while `cmd_ls --porcelain`
    prints a human "No projects registered" sentence, and both behaviours are pinned. The enumeration
    that found the stale claims, and the one to re-run before calling this file clean, is a grep of
    this module for `picker` and `switch`.

    STILL FLATTENED HERE, ON ITS OWN GROUNDS. `borg link --porcelain` is a TSV read BY FIELD: a
    `\\n` in the last field ends the record early and a `\\t` shifts every field after it, and both
    characters reach storage through `lib/registry.zsh`'s scrub. That argument stands without any
    claim about fzf. Stated at its real strength, though: grepped across borg.zsh, drone.zsh,
    hooks/, skills/ and bin/, this surface has NO runtime consumer in the repo today -- what pins its
    five-field shape is cli_contract.bats, and the one proposed consumer (reading a `drone status`
    column by position) lives in a SEVERED directive whose command was deleted. So the flatten here
    protects a documented contract and its tests, not a user-visible break; the user-visible break
    was in `cmd_ls --porcelain`. Flattened BEFORE the 80-char cut, the same ordering the other two
    call sites use and for the same reason: the budget must measure the characters the field carries.
    """
    order = doc.get("order") or []
    projects = doc.get("projects") or {}
    rows = []
    for name in order:
        entry = projects[name]
        source = core.jq_default(entry.get("source"), "cli")
        status = core.jq_default(entry.get("status"), _JQ_ABSENT_STATUS)
        last_activity = core.jq_default(entry.get("last_activity"), "")
        summary = core.jq_default(entry.get("summary"), "")
        summary = _flatten_summary(str(summary))[:80]
        rows.append(f"{name}\t{source}\t{status}\t{last_activity}\t{summary}\n")
    return "".join(rows)


def _status_color(status: str) -> str:
    if status == "active":
        return GREEN
    if status == "waiting":
        return YELLOW
    if status == "idle":
        return DIM
    # The archived arm (and any other status) reproduces NC + text + NC -- a genuine double reset,
    # not a copy-paste accident (borg.zsh:354's `*) status_color="$NC" ;;`).
    return NC


def _src_badge(source: str) -> str:
    if source == "desktop":
        return "[D]"
    if source == "coco":
        return "[X]"
    return "[C]"


def _overview_summary_cut(summary: str) -> str:
    """The board's 50-char cut WITH a literal `...` appended only when the ORIGINAL length is
    STRICTLY greater than 50 (an exactly-50-char summary gets none).

    EMBEDDED WHITESPACE CONTROL CHARACTERS ARE FLATTENED TO SPACES HERE, BEFORE THE CUT (F1, second
    renderer): a fixed-width table cannot survive one, exactly the way it cannot survive an over-long
    project name. `_flatten_summary` is the canonical statement of the character set, of all three
    call sites and how each breaks, and of the retraction that none of this is about the picker.

    FLATTEN BEFORE CUTTING, NOT AFTER -- the same ordering `_summary_block` uses, pinned there by
    test_render.py::TestSummaryBlock::test_summary_block_flattens_newlines_before_folding_not_after.
    Stated honestly: TODAY the two orderings are behaviourally identical, because the replacement is
    one character for one character, so `flat[:50]` and `summary[:50].replace(...)` are the same
    string and `len()` is the same number either way. Before-cut is nonetheless the correct
    placement, because it is the one that stays correct if the replacement ever stops being
    one-for-one (a future `"\\n" -> " | "`, say): the 50-char budget and the `> 50` ellipsis test
    must measure DISPLAYED characters, and only the before-cut ordering guarantees that without a
    second edit here. What IS pinned by test is the displayed-character property itself --
    TestOverviewSummaryCut::test_cut_boundary_and_ellipsis_measure_displayed_characters.

    Because the replacement is one-for-one, both the cut and the ellipsis test are unchanged for
    already-clean input and no golden moves.
    """
    flat = _flatten_summary(summary)
    cut = flat[:50]
    return f"{cut}..." if len(flat) > 50 else cut


def _board_display(name: str, entry: dict) -> str:
    """The name a board row PRINTS: the registry's `display_name`, else the key. ONE definition,
    because `_board_width` must measure exactly the string `_overview_row` pads -- measuring the key
    while padding the display name reintroduces the header/row mismatch through a rename."""
    return str(entry.get("display_name") or name)


def _board_width(order: list[str], projects: dict) -> int:
    """The PROJECT column's width for one render: `_COL_PROJECT`, or the longest name if longer.

    THE FLOOR KEEPS THE COMMON CASE BYTE-STABLE -- every fixture name and the real registry's modal
    case is under 20, so this returns 20 and no golden moves. See `_COL_PROJECT` for why widening
    beats truncating.
    """
    return max([_COL_PROJECT, *(len(_board_display(name, projects.get(name) or {})) for name in order)])


def _overview_row(
    name: str, entry: dict, cortex_by_project: dict[str, str], mark: str = "", width: int = _COL_PROJECT
) -> str:
    """One board row, plus its cortex pause continuation when the project has a pending wake.

    `mark` IS APPENDED INSIDE THE ROW'S OWN f-STRING and defaults to "", which keeps every byte of
    this function identical for a caller that does not pass one. It exists so the scoped `◀` lands on
    the ROW and never on the countdown continuation, without the caller having to split the returned
    string back apart to find the boundary.

    `width` DEFAULTS TO THE FLOOR so a caller rendering one row alone still gets the ordinary shape;
    `_board_section`, the only caller that can SEE every row, passes the measured one and pads the
    header from that same number. Computed once, in one place, handed to both.
    """
    source = str(core.jq_default(entry.get("source"), "cli"))
    # UNREACHABLE in practice: core.with_state already defaults a missing status to "idle"
    # (DEFAULT_STATUS, mirroring lib/registry.zsh:203) -- which is why the porcelain golden's
    # `golf` row renders "idle" rather than the absent-status fallback. Reproduced anyway for
    # parity with the jq.
    status = str(core.jq_default(entry.get("status"), _JQ_ABSENT_STATUS))
    last_activity = str(core.jq_default(entry.get("relative_activity"), ""))
    summary_short = _overview_summary_cut(str(core.jq_default(entry.get("summary"), "(no summary)")))
    display = _board_display(name, entry)
    pin_mark = "*" if entry.get("pinned") is True else " "
    status_display = "waiting <<<" if status == "waiting" else status

    line = (
        f"{pin_mark}{display:<{width}} {_src_badge(source):<{_COL_SRC}} "
        f"{_status_color(status)}{status_display:<{_COL_STATUS}}{NC} "
        f"{last_activity:<{_COL_LAST_ACTIVE}} {summary_short}{mark}\n"
    )
    countdown = cortex_by_project.get(name)
    if countdown:
        # DERIVED FROM `width`, NOT THE 23 SPACES THIS USED TO HARDCODE -- a literal correct for
        # exactly one column width and silently wrong for every other, which is the two-sources-of-
        # truth failure the `_COL_*` constants were hoisted to prevent. `1 + width + 2` reproduces 23
        # byte for byte at the floor (pin-mark column, name field, the zsh original's hand-counted
        # two-space lead-in), which is why no golden moves.
        line += f"{' ' * (1 + width + 2)}{CYAN}⏸ resumes in {countdown}{NC}\n"
    return line


def _cube_lines() -> list[str]:
    """The cube art, verbatim (borg.zsh:319-328). Ends with a bare newline, which is the blank line
    separating the header section from `▸ IN FOCUS` -- see `_section`, which supplies that separator
    for every OTHER section and therefore must not supply a second one here."""
    return [
        "\n",
        f"  {DIM}_______________{NC}\n",
        f"  {DIM}/|             /|{NC}      {BOLD}THE BORG COLLECTIVE{NC}\n",
        f"  {DIM}/ |            / |{NC}      {DIM}resistance is futile{NC}\n",
        f"  {DIM}  |___________|  |{NC}\n",
        f"  {DIM}  |  |        |  |{NC}\n",
        f"  {DIM}  |  |________|__|{NC}\n",
        f"  {DIM}  | /         | /{NC}\n",
        f"  {DIM}  |/          |/{NC}\n",
        "\n",
    ]


def _ship_date_suffix(item: dict) -> str:
    """ " (date)" when a ship date is present, else "" -- omit the parens entirely rather than
    render an empty "()". A missing/empty ship date is TSV_EMPTY_SENTINEL-shaped upstream (see
    core.ship_date's docstring: no matching "Shipped:" line -> ""); this is the render-side half
    of that contract, not a second sentinel.
    """
    ship_date = item.get("ship_date") or ""
    return f" ({ship_date})" if ship_date else ""


def _bullet_lines(items: list[dict], show_project: bool) -> list[str]:
    """The bullet loop for QUEUED **and** SHIPPED. One function, because they are one line.

    THEY WERE TWO UNTIL AC2 TOOK THE LAST DIFFERENCE OUT. The zsh original printed a distinct header
    above each block (`Directives: N pending` / `Recently assimilated:`), which is what made two
    functions defensible; the `▸ QUEUED` and `▸ SHIPPED` section headers and their notes replace
    both, and what remained was two identical loops differing by one interpolation that is EMPTY on
    a directive anyway -- `_ship_date_suffix` reads an absent key as "". Keeping them apart would
    mean two places to change the bullet shape and one of them getting missed.

    `show_project` follows the document's BREADTH, not the section: `[platform] Scope keypair
    rotation` is information in the orchestrator context and noise in platform's own.
    """
    out = []
    for item in items:
        prefix = f"[{item['project']}] " if show_project else ""
        out.append(f"    {DIM}- {prefix}{item['title']}{_ship_date_suffix(item)}{NC}\n")
    return out


# ── the spine ─────────────────────────────────────────────────────────────────────────────────────


def _placeholder(sentence: str) -> str:
    """The ONE line an empty section renders under its header: what would fill it, and how.

    Exactly one, never zero and never two. Zero is the "reads as broken" failure the plan's own risk
    section names -- a front door that prints a header and nothing under it looks like a bug rather
    than an empty set. Two is a section quietly growing a second vocabulary for emptiness.
    """
    return f"  {DIM}— {sentence}{NC}\n"


def _plural(count: int, singular: str, plural: str) -> str:
    return f"{count} {singular if count == 1 else plural}"


def _section(title: str, note: str, lines: list[str]) -> list[str]:
    """One section: its `▸` header (plus an optional dim note), its body, and ONE trailing blank.

    The empty-titled first entry is the page header -- the cube, which gets no `▸` line and supplies
    its own trailing blank through `_cube_lines`. That is the only special case, and it is keyed on
    the SECTIONS constant rather than on anything in the document, so `document()` below stays free
    of any branch on scope, mode or emptiness.
    """
    if not title:
        return lines
    head = f"{BOLD}{SECTION_MARK}{title}{NC}"
    if note:
        head += f"  {DIM}{note}{NC}"
    return [head + "\n", *lines, "\n"]


def _header_section(doc: dict) -> tuple[str, list[str]]:
    """The cube, and the discovery tip above it when the registry holds at most one project.

    The tip is gated on the UNFILTERED `total_projects`, NOT on `len(order)` -- one visible project
    plus one archived one is two, and must not print it (borg.zsh:286-290). It is also NOT mutually
    exclusive with the board's all-archived placeholder: a lone archived project prints both.
    """
    lines: list[str] = []
    if doc.get("total_projects", 0) <= 1:
        lines.append(f"  {DIM}Tip: run 'borg scan' to discover projects from session history{NC}\n")
    lines.extend(_cube_lines())
    return "", lines


# JUSTIFICATION: transcribes borg.zsh:415-508 statement by statement for one golden-diffable section.
def _focus_section(doc: dict) -> tuple[str, list[str]]:  # pylint: disable=too-many-locals
    """IN FOCUS: the scoped repository's own card, transcribed from the retired `deep()`.

    Its Directives and Recently-assimilated blocks are NOT here any more -- they are the QUEUED and
    SHIPPED sections, which render the same rows under a header shared with the orchestrator context.
    That is what "the two contexts differ in breadth only" means in practice: one row set moved out
    from under a per-mode heading and into a section that exists in both.
    """
    focus = doc.get("focus") or {}
    if not focus:
        return "", [_placeholder("no repository in focus. cd into one, or run borg link <name>.")]

    name = focus.get("name", "")
    entry = focus.get("entry") or {}
    source = core.jq_default(entry.get("source"), "cli")
    path = core.jq_default(entry.get("path"), "null")
    status = core.jq_default(entry.get("status"), _JQ_ABSENT_STATUS)
    last_activity = core.jq_default(entry.get("last_activity"), "(never)")
    summary = str(core.jq_default(entry.get("summary"), "(no summary)"))
    session_id = core.jq_default(entry.get("claude_session_id"), "(unknown)")
    tmux_window = core.jq_default(entry.get("tmux_window"), "(none)")

    out = [_label("Source:", str(source))]
    # `Path:` is the ONLY conditional header line -- omitted entirely, not blanked, when path is
    # the sentinel string "null".
    if path != "null":
        out.append(_label("Path:", str(path)))
    # Exactly ONE line on the whole page contains "Status:", and this section is above every other
    # source of text, so drone.zsh:964-965's `grep -m1` finds it before any PR title. See the module
    # docstring for why that ordering is the invariant rather than a scrubbing rule.
    out.append(_label("Status:", str(status)))
    out.append(_label("Last active:", str(last_activity)))
    out.append(_label("tmux window:", str(tmux_window)))
    out.append(_label("Session ID:", str(session_id)))
    out.append("\n")
    out.append(_summary_block(summary))

    plan = focus.get("plan")
    if plan is not None:
        out.append("\n")
        out.append(f"  {BOLD}Active Plan{NC}\n")
        objective = plan.get("objective") or ""
        if objective:
            out.extend(_objective_lines(objective))
        out.append(f"  {CYAN}Progress:{NC} {plan.get('met', 0)}/{plan.get('total', 0)} criteria met\n")

    checkpoints = focus.get("checkpoints") or []
    if checkpoints:
        out.append("\n")
        out.append(f"  {BOLD}Recent Checkpoints{NC}\n")
        for filename in checkpoints:
            out.append(f"    {CYAN}{filename}{NC}\n")
        out.append("\n")
        out.append(f"  {BOLD}Latest Checkpoint{NC}\n")
        out.append(_checkpoint_head_block(focus.get("checkpoint_head") or ""))

    return name, out


def _scoped_name(doc: dict) -> str:
    """The repository this invocation is scoped to, or "" in orchestrator scope."""
    return str((doc.get("scope") or {}).get("repository") or "")


def _board_section(doc: dict) -> tuple[str, list[str]]:
    """REPOSITORIES: every registered repository, in BOTH contexts. Transcribed from `overview()`.

    DELIBERATELY SCOPE-INVARIANT, and this is the one section AC2's "breadth" rule does not touch.

    TWO OF THE THREE CONSUMERS THIS USED TO CITE NO LONGER EXIST, and the justification is restated
    rather than re-invented around whatever is left. It named `borg.zsh:2225`'s 5s `borg watch`
    redraw and "the fzf preview's own orientation": `watch` is not in the case dispatch and exits 1
    with "unknown command", and `cmd_switch`'s fzf call has no `--preview` at all (B15 pins
    `grep -c -- '--preview-window' borg.zsh` at 0) -- both retired 2026-08-27. ONE named consumer
    survives, skills/borg-switch/SKILL.md's `borg link --local --all`, run from a project session's
    cwd precisely to get a cross-project list; narrowing this section to the scoped repository would
    hand it a one-row table.

    The remaining reason is the one that was always underneath the consumer list: the page has
    exactly one place that answers "what else is going on", and a reader who ran `borg link` inside
    a repository has not asked to stop being able to see that. `--all` remains the only control over
    which rows appear; the scoped row is MARKED with a trailing `◀` rather than made the only row.
    """
    total_projects = doc.get("total_projects", 0)
    order = doc.get("order") or []
    projects = doc.get("projects") or {}

    # Gated on the UNFILTERED count, NOT len(order). See core.assemble's docstring: an empty registry
    # and an all-archived one both emit order=[]/projects={}, but must print two different sentences.
    # Both sentences are the zsh original's verbatim, minus the leading `▸` -- every assertion on
    # them in this tree is a substring test, which is what makes dropping the marker free.
    if total_projects == 0:
        return "", [_placeholder("No projects registered. Run: borg scan")]
    if not order:
        return "", [_placeholder("No projects to show. Run: borg link --all")]

    # "Need attention" is the WAITING count, which is not `capacity.active`: capacity counts every
    # session holding a slot (active AND waiting) against BORG_MAX_ACTIVE and belongs in SIGNALS,
    # while this note answers "how many of these rows are blocked on me". The two are different
    # numbers on the same registry and the goldens carry both.
    waiting = sum(1 for name in order if str(core.jq_default(projects[name].get("status"), "")) == "waiting")
    note = f"the collective · {_plural(len(order), 'repository', 'repositories')} · {waiting} need attention"

    # MEASURED ONCE AND HANDED TO BOTH the header and every row, which is the only arrangement in
    # which the header cannot stop describing its rows.
    width = _board_width(order, projects)
    lines = [
        f"{BOLD} {'PROJECT':<{width}} {'SRC':<{_COL_SRC}} {'STATUS':<{_COL_STATUS}} "
        f"{'LAST ACTIVE':<{_COL_LAST_ACTIVE}} SUMMARY{NC}\n",
        ("─" * 90) + "\n",
    ]
    countdowns = _cortex_countdowns(doc)
    scoped = _scoped_name(doc)
    for name in order:
        mark = f" {CYAN}◀{NC}" if name == scoped else ""
        lines.append(_overview_row(name, projects[name], countdowns, mark, width))
    return note, lines


def _cortex_countdowns(doc: dict) -> dict[str, str]:
    """`{project: countdown}`, FIRST WAKE WINS, matching borg.zsh:374's awk join.

    First-wins rather than last: two pending wakes for one project is a state file that was appended
    to twice, and the earlier one is the one that fires.
    """
    countdowns: dict[str, str] = {}
    for pending in doc.get("cortex_pending") or []:
        project = pending.get("project")
        if project not in countdowns:
            countdowns[project] = pending.get("countdown", "")
    return countdowns


def _grid_placeholder(grid_block: dict) -> str:
    """THREE DIFFERENT DIAGNOSES for an empty CHAINS section, read off the grid block's own
    self-describing fields (`slug`, `scope_kind`, `manifests`) rather than guessed.

    build_grid carries those fields precisely so "a consumer reading only this block can tell an
    empty grid apart from an un-swept one apart from a wrong-repository one". Collapsing the three
    into one sentence throws that away on the section where the modal repository -- 13 of ~14 of
    them -- spends its entire life.

    SCOPE IS TESTED BEFORE THE SLUG, AND THE OTHER ORDER MAKES THE THIRD ARM DEAD CODE. The AC2 spec
    states this ladder slug-first; executed against the real document that is wrong, because
    `grid.repository_dir` returns "" for orchestrator scope BY CONTRACT ("there is no single
    repository to resolve a slug for") and so `slug` is unconditionally empty there. Slug-first
    therefore answers "this directory has no GitHub origin" for `borg link` run from the workspace
    root -- a diagnosis about a directory, on the one invocation that is not about a directory --
    and the registry-wide sentence can never render. Found by reading the generated golden rather
    than by a test, which is why `test_the_three_chains_placeholders_are_three_different_diagnoses`
    now parameterizes `scope_kind` alongside `slug` instead of varying `slug` alone.
    """
    if grid_block.get("scope_kind") != "repository":
        return "no project manifests in the registry yet. Run /borg-plan in any repository."
    if not grid_block.get("slug"):
        return "this directory has no GitHub origin — nothing to scope a chain to."
    return f"no project manifest declares work in {grid_block['slug']}. Run /borg-plan to scaffold one."


def _manifest_lines(manifest_grid: dict, ids: dict[str, str], columns: dict[str, int]) -> list[str]:
    """One project's CHAINS block: its heading, the picture, then one detail block per node.

    THE DETAIL BLOCKS ARE IN NODE-ID ORDER, which is picture reading order (manifest, level, column)
    and NOT the wire's `(seq, ref)`. A reader moving between the picture and the details must never
    re-sort in their head; `picture.reading_order` is the one definition of that order and both the
    glance strip and this loop go through it.
    """
    nodes = manifest_grid.get("nodes") or {}
    out = ["\n", f"  {BOLD}{manifest_grid.get('id', '')}{NC}\n"]
    desc = manifest_grid.get("desc") or ""
    if desc:
        out.append(f"  {DIM}{desc}{NC}\n")
    repos = manifest_grid.get("repos") or []
    if repos:
        out.append(f"  {DIM}repos: {' · '.join(repos)}{NC}\n")
    out.append(f"  {DIM}glance:{NC} {picture.glance_row(manifest_grid, ids)}\n")

    out.append("\n")
    out.extend(f"{row}\n" for row in picture.picture(manifest_grid, ids, columns))

    for ref in picture.reading_order(manifest_grid, ids):
        out.append("\n")
        out.extend(f"{line}\n" for line in picture.detail_block(nodes[ref], ids.get(ref, ""), nodes, ids))
    return out


def _grid_section(doc: dict) -> tuple[str, list[str]]:
    """CHAINS: the declared cross-repository topology, one picture and one detail block set per
    project, with GLOBAL node ids so `*` in vim toggles between a cell and its detail exactly once.

    The note is UNCONDITIONAL, even when no manifest was selected: `0 projects · 0 refs · 0
    unresolved · swept back to <mark>` is the honest reading of a repository with nothing declared,
    and it is what separates that from a repository nobody swept.

    "swept back to <mark>", NOT "swept <mark>", AND THE THREE MISSING WORDS WERE A WRONG ANSWER.
    `grid.since` is the sweep's WINDOW LOWER BOUND -- `grid.sweep_since(now, 90)` -- never the
    instant anything was swept, so this line used to render a full ISO timestamp exactly ninety days
    old with the current wall clock attached and a reader parsed it as "this data is three months
    stale". Reproduced: at `NOW=2026-08-28T14:24:17Z` the page said `swept 2026-05-30T14:24:17Z`,
    and three minutes later `swept 2026-05-30T14:21:00Z` -- the mark tracks `now`, exactly backwards
    from what the sentence claimed. No golden could see it: `sweep-acme.json` pins a bare
    `"since": "2026-05-28"` with no relationship to any clock, which reads harmlessly either way.

    A WINDOW BOUND AND A SWEEP TIME ARE TWO DIFFERENT SENTENCES -- this project's recurring trap --
    so the fix is to say which one this is, not to swap in the other. The sweep TIME is not reported
    here and need not be: the sweep runs inside the same `cli._document` pass that stamps
    `generated_at`, so "when was this swept" is already the page's own freshness, while "how far back
    did it look" is a fact only this line carries.
    """
    grid_block = doc.get("grid") or {}
    manifests = grid_block.get("manifests") or []
    since = str(grid_block.get("since") or "")
    freshness = f"swept back to {since}" if grid_block.get("swept") and since else "not swept"
    note = (
        f"{_plural(len(manifests), 'project', 'projects')}"
        f" · {grid_block.get('declared', 0)} refs"
        f" · {grid_block.get('unresolved', 0)} unresolved"
        f" · {freshness}"
    )
    if not manifests:
        return note, [_placeholder(_grid_placeholder(grid_block))]

    columns_by_manifest = [picture.assign_columns(manifest) for manifest in manifests]
    ids = picture.node_ids(manifests, columns_by_manifest)
    lines: list[str] = []
    for manifest, columns in zip(manifests, columns_by_manifest):
        lines.extend(_manifest_lines(manifest, ids, columns))
    return note, lines


# AC4's routing, and it reads `gate.kind` off the wire rather than re-deriving anything.
# `manifest_core.gates` is the total source: `unmapped_gates` deliberately EXCLUDES gates carrying a
# `blocked_by_ref`, so reaching for it here would silently drop exactly the decisions that were
# careful enough to name their blocker -- which is the plan's own named risk, arrived at with nothing
# mis-set.
_GROUP_YOURS = "yours"
_GROUP_MINE = "mine"
_GROUP_UNSURE = "unsure"
# `decision` blocks a PERSON; `verification` blocks nobody in particular because anyone can run it.
# Those are manifest_core.gates' words and the only two kinds any manifest has ever declared.
_GATE_ROUTING = {"decision": _GROUP_YOURS, "verification": _GROUP_MINE}
# `mine` HAS TWO KINDS OF MEMBER AND THE HEADING MUST BE TRUE OF BOTH. It used to read "nothing is
# blocking these", written for the UNGATED member and a FALSE STATEMENT about the other one: a
# `verification` gate IS a blocker and `_next_row` prints its `blocked_by` on the very same line.
# Reproduced live on the front door's single most decision-relevant line --
# `mine — nothing is blocking these` directly above `stillpoint#57  needs a live-prod confirmation
# run against all four contracts`.
#
# THE ROUTING IS NOT THE BUG AND DOES NOT MOVE. AC4's D2 is explicit that a `verification` goes to
# `mine` -- "a `decision` blocks a PERSON, a `verification` blocks nobody in particular because anyone
# can run it" -- so the axis this table splits on is WHOSE HANDS the row needs, never whether it is
# blocked. The heading now says that axis out loud and is true of both members, and it is the exact
# complement of `yours`, which is what makes the pair read as one question with two answers.
#
# NO EM DASH INSIDE A HEADING: `_next_section` renders `{group} — {heading}`, so a second one on the
# line reads as the start of the row list.
_GROUP_HEADINGS = {
    _GROUP_YOURS: "a decision only you can make",
    _GROUP_MINE: "no decision needed first, so anyone can pick these up",
}


def _route(kind: str) -> str:
    """Which group one ready row belongs to, from its gate's `kind`. Ungated callers pass "".

    AN UNRECOGNIZED KIND GETS ITS OWN GROUP RATHER THAN A DEFAULT SIDE, and that is the owner's call
    recorded in the AC4 spec. BOTH defaults are lies: routing it to `mine` risks an agent acting on a
    decision (the plan's named risk), and routing it to `yours` silently asserts the author meant a
    decision when the router has no idea. A third group says the true thing. Third time this project
    has landed on the same rule -- an unknown is a state, not a default; cf. `?` for unverified
    provenance and `unlooked` for an unresolvable READY set.

    AN UNGATED ROW IS `mine`. Nothing is blocking it, so nothing needs a human first.

    `unsure` IS REACHABLE THROUGH THE FRONT DOOR, and getting it there took two changes on this
    docstring's own prediction. It used to say the group was unreachable because
    `manifest_core.GATE_KINDS` closed `gate.kind` to `{"decision", "verification"}` and
    `shell._load_manifest` dropped the WHOLE FILE on anything else. PR #173 replaced that with
    row-level degradation, which left the group unreachable for a WORSE reason -- the one row carrying
    the unrecognized kind was deleted and the rest of the file rendered as though it had never been
    declared. So the validator was demoted: it now requires only that a gate NAME some kind, and an
    unrecognized one arrives here and routes. `tests/fixtures/link/manifests/warehouse-rollout.json`
    carries `acme/warehouse#78` (`kind: "review"`) so `link-grid-orchestrator.golden` pins the whole
    path end to end, not just this function's unit test.

    AN ABSENT OR BLANK KIND IS STILL A VALIDATION ERROR AND STILL COSTS ITS ROW, and that asymmetry is
    what keeps this function honest: `_next_tally` passes `""` for an UNGATED row and the first branch
    below reads it as `mine` on the strength of being UNGATED. A gate declaring a blank kind would
    take that same branch, so a row that HAS a gate would be routed by the rule for rows that do not
    -- and if that gate was a decision, `mine` is the plan's own named risk arriving with nothing
    mis-set. `manifest_core._validate_gate` holds that line; do not demote it here.

    THE ROUTING TABLE IS ALLOWED TO BE NARROWER THAN `GATE_KINDS`, and the subset test is what keeps
    that from being an accident rather than a decision. NOTHING HERE DEFAULTS TO A REAL SIDE any more
    -- the `.get` below falls to `_GROUP_UNSURE`, which `_next_section` NAMES on the page -- so
    widening `GATE_KINDS` without adding a `_GATE_ROUTING` entry is no longer the loud failure this
    paragraph used to describe. It is the quiet one: a kind this project DECLARES it understands would
    be reported to the reader as unroutable. `test_the_router_covers_every_declared_gate_kind` asserts
    the subset for exactly that reason, and states it the same way.
    """
    if not kind:
        return _GROUP_MINE
    return _GATE_ROUTING.get(kind, _GROUP_UNSURE)


def _next_row(node: dict, gate: dict) -> str:
    """One ready row: state glyph, provenance mark, the linked FULL ref, and the gate's sentence.

    NO NODE ID, AND THAT IS LOAD-BEARING. Ids appear EXACTLY TWICE on a page by design -- once in a
    picture cell, once as a detail heading -- so `*` in vim toggles between them with no plugin, and
    `contract: every node id appears exactly twice in each grid golden` enforces it. Printing `n12`
    here would make it three and turn that case red for a real reason. The ref IS the vocabulary
    (grid_manifest's docstring: "ids are navigation handles, not vocabulary"), so this prints the
    full ref and a reader jumps by ref.

    The glyph is `picture`'s, not a local copy, so a ready row here and the same node in the picture
    cannot disagree -- including its provenance mark, which is why AC4's precondition shipped first.
    """
    ref = node.get("ref", "")
    glyph = f"{picture.glyph_color(node)}{picture.state_glyph(node)}{NC}{picture.cell_mark(node, drift=False)}"
    line = f"    {glyph}{picture.link_ref(ref, ref)}"
    blocked_by = (gate or {}).get("blocked_by") or ""
    if blocked_by:
        line += f"  {DIM}{blocked_by}{NC}"
    return line + "\n"


def _next_tally(manifests: list[dict]) -> tuple[dict[str, list[str]], list[str], int, bool]:
    """One walk over every manifest: `(grouped rows, unrecognized kinds, ready count, unlooked)`.

    IT DOES NOT COUNT THE DENOMINATOR. `grid.declared` is already on the wire and `_grid_section`'s
    note already prints it, so recomputing `len(nodes)` here would be a second derivation of a
    published number -- the shape `level` was hoisted onto the node to avoid, and the shape that lets
    CHAINS and NEXT disagree about how many refs a page has.

    SPLIT OUT OF `_next_section` BECAUSE RUFF MEASURED IT, not for taste -- the combined function
    came in at complexity 11 against a ceiling of 10. The seam is the honest one anyway: this is the
    DERIVATION (walk, route, count) and `_next_section` is the PRESENTATION (which sentence, which
    headings), and the three non-populated outcomes are decisions about presentation.

    A manifest whose READY set is `unlooked` contributes its node count and nothing else. It is
    skipped rather than treated as empty, so one unresolved manifest in orchestrator scope cannot
    silently subtract from a sibling's real answer.
    """
    grouped: dict[str, list[str]] = {_GROUP_YOURS: [], _GROUP_MINE: [], _GROUP_UNSURE: []}
    unsure_kinds: list[str] = []
    ready_total = 0
    unlooked = False

    for manifest in manifests:
        nodes = manifest.get("nodes") or {}
        ready = manifest.get("ready") or {}
        if ready.get("state") == grid.STATE_READY_UNLOOKED:
            unlooked = True
            continue
        gates = {gate["ref"]: gate for gate in manifest.get("gates") or []}
        # `rows[].next` ORDERS WITHIN A GROUP; IT DOES NOT GRANT MEMBERSHIP. AC4 names it as an input
        # alongside `gate.kind` without saying what it does, and the two readings are not close: as
        # an override it would put a row the author flagged into NEXT even when a parent has not
        # merged, which is a hand-typed field beating a resolved one -- the exact inversion AC4's
        # precondition exists to prevent, arriving through a different door. As emphasis it lets the
        # author say "start with this one" among rows that are ALREADY ready, which costs nothing if
        # the flag is stale. Sorted stably, so rows with no flag keep declaration order.
        # KEY BUILT EAGERLY, NOT AS A CLOSURE. `key=lambda ref: ... nodes.get(ref) ...` captures a
        # loop variable (pylint W0640) -- harmless here because the sort is consumed inside the same
        # iteration, but the local pylint rated it 10.00/10 while CI's flagged it, so the version that
        # is right is the one that fails the build. The tuple sorts False before True, and
        # `ready_set` already returned its refs sorted, so alphabetical order survives inside each
        # half.
        refs = [
            ref for _, ref in sorted((not (nodes.get(ref) or {}).get("next"), ref) for ref in ready.get("refs") or [])
        ]
        for ref in refs:
            gate = gates.get(ref) or {}
            kind = gate.get("kind") or ""
            group = _route(kind)
            if group == _GROUP_UNSURE:
                unsure_kinds.append(kind)
            grouped[group].append(_next_row(nodes.get(ref) or {}, gate))
            ready_total += 1
    return grouped, unsure_kinds, ready_total, unlooked


def _next_section(doc: dict) -> tuple[str, list[str]]:
    """NEXT: what can actually be picked up right now, split into yours / mine / unsure.

    THREE-STATE, NOT LIST-OR-EMPTY. `grid.ready_refs` returns `unlooked` when nothing on the page was
    resolved, and this renders that as its own sentence rather than as "nothing is ready". A
    `--local` reader whose board is entirely declared would otherwise be told they are clear, one
    section above SIGNALS saying `N of N declared refs unresolved — nobody looked`. The document must
    not contradict itself between two adjacent sections.

    `unsure` RENDERS ONLY WHEN NON-EMPTY, unlike the section itself. AC2's directive rejected giving
    yours-vs-mine an always-empty SECTION slot as the "reads as broken" failure; a GROUP is the
    version of that idea which is allowed, precisely because it can be absent without leaving a
    header over nothing. Neither live manifest declares an unrecognized kind; the fixture
    `warehouse-rollout.json` does, which is how the populated form stays pinned.
    """
    grid_block = doc.get("grid") or {}
    grouped, unsure_kinds, ready_total, unlooked = _next_tally(grid_block.get("manifests") or [])
    declared_total = grid_block.get("declared", 0)

    # UNLOOKED WINS OVER A POPULATED SET when both are present, which happens only in orchestrator
    # scope with one manifest resolved and another not. Reporting `2 ready` there would understate
    # the answer as confidently as reporting zero: the honest note names both halves.
    # "nobody looked" AND NEVER THE WORD `unknown`, which is the grid's internal bottom-of-the-ladder
    # TOKEN. `contract: link --local renders every node without naming the unresolved token` asserts
    # it appears zero times on a human page, and it is right to: a reader seeing `unknown` cannot tell
    # whether it is a fact about the pull request or a fact about the sweep. `picture._STATE_SENTENCE`
    # makes the same choice one section up.
    if unlooked and not ready_total:
        return "nobody looked", [_placeholder("no state on this page was resolved; run without --local.")]
    note = f"{ready_total} ready of {declared_total}"
    if unlooked:
        note += " — and some refs nobody looked up"
    if not ready_total:
        return note, [_placeholder("nothing is ready right now.")]

    lines: list[str] = []
    for group in (_GROUP_YOURS, _GROUP_MINE, _GROUP_UNSURE):
        rows = grouped[group]
        if not rows:
            continue
        if group == _GROUP_UNSURE:
            kinds = ", ".join(f'"{kind}"' for kind in sorted(set(unsure_kinds)) if kind) or "nothing"
            heading = f"the gate says {kinds}, which does not route"
        else:
            heading = _GROUP_HEADINGS[group]
        lines.append(f"  {BOLD}{group}{NC} {DIM}— {heading}{NC}\n")
        lines.extend(rows)
    return note, lines


def _scoped_rows(doc: dict, key: str) -> tuple[list[dict], bool]:
    """`(rows, show_project)` for one scope-dependent list: the focused repository's in repository
    scope, the registry-wide aggregate otherwise.

    ONE FUNCTION KEYED ON THE FIELD NAME, because QUEUED and SHIPPED narrow by the identical rule and
    two copies of it is two places for the breadth rule to drift.
    """
    if (doc.get("scope") or {}).get("kind") == "repository":
        return (doc.get("focus") or {}).get(key) or [], False
    return doc.get(key) or [], True


def _queued_section(doc: dict) -> tuple[str, list[str]]:
    """QUEUED: filed-but-not-started directives, at the document's breadth."""
    directives, show_project = _scoped_rows(doc, "directives")
    if not directives:
        return "", [_placeholder("nothing queued. Run /borg-plan to file one.")]
    return _plural(len(directives), "directive", "directives"), _bullet_lines(directives, show_project)


def _shipped_section(doc: dict) -> tuple[str, list[str]]:
    """SHIPPED: the most recently assimilated plans, at the document's breadth.

    NO NOTE, unlike QUEUED's count: `shell.collect_all_assimilated` caps at three, so a count here
    would read as a total and be one.
    """
    assimilated, show_project = _scoped_rows(doc, "assimilated")
    if not assimilated:
        return "", [_placeholder("nothing shipped yet.")]
    return "", _bullet_lines(assimilated, show_project)


def _resolution_line(grid_block: dict) -> list[str]:
    """The ladder's gap as a SENTENCE, never as a token, and only when there is something declared.

    `unresolved` counts declared refs whose state came from neither the sweep nor a targeted fetch.
    Printing the count is what separates a grid nobody looked at from one that resolved completely --
    the two are otherwise identical on the page, same `swept: true`, same mark.
    """
    declared = grid_block.get("declared", 0)
    if not declared:
        return []
    unresolved = grid_block.get("unresolved", 0)
    if unresolved:
        return [_placeholder(f"{unresolved} of {declared} declared refs unresolved — nobody looked")]
    return [_placeholder(f"{declared} of {declared} declared refs resolved.")]


def _cycle_lines(grid_block: dict) -> list[str]:
    """One sentence per project whose declared edges contain a cycle.

    `manifest_core._rank_nodes` breaks a cycle by admitting the smallest remaining ref rather than
    raising, so a cyclic manifest still ranks and still draws -- minus the edges that do not descend,
    which `picture.back_edges` reports and nothing else would. Without this line the picture would
    read as acyclic and the missing connector would look like a rendering bug.
    """
    lines = []
    for manifest in grid_block.get("manifests") or []:
        dropped = len(picture.back_edges(manifest))
        if not dropped:
            continue
        # The WHOLE clause is pluralized, not just its noun: the singular needs "forms"/"is" and the
        # plural "form"/"are", so a `_plural`-style helper on the noun alone produces "1 declared
        # edge form a cycle and are not drawn".
        clause = (
            "1 declared edge forms a cycle and is not drawn"
            if dropped == 1
            else f"{dropped} declared edges form a cycle and are not drawn"
        )
        lines.append(_placeholder(f"{manifest.get('id', '')}: {clause}"))
    return lines


def _width_line(grid_block: dict) -> list[str]:
    """The picture is wider than the budget, said once, from the number `cli._grid` measured.

    READ OFF THE DOCUMENT, NEVER REMEASURED HERE. This module is unconditionally pure and
    `picture.max_row_width` is pure too, so calling it would not break that -- it would be worse than
    breaking it quietly. `grid.picture_width` is already published, and a second derivation of one
    number is exactly how the printed sentence and `--json` come apart: the human would be told 71
    while a consumer read 68, with nothing mis-set and no test able to see it. The document field is
    the one truth and the renderer reads it.

    SILENT AT AND BELOW THE BUDGET, so it can never become page furniture. Every manifest that exists
    today measures well inside it (61 against 68 on both goldens), which is also why adding this line
    moves no golden.

    WHY IT IS A SIGNAL AND NOT A CRASH: a too-wide picture is not wrong, it is unreadable in a narrow
    pane, and deciding what to elide is a design question the width-check directive names as a
    non-goal. The reader gets told WHY the page looks wrong instead of just seeing it wrong.
    """
    width = grid_block.get("picture_width", 0)
    if not width or width <= picture.PICTURE_BUDGET:
        return []
    return [
        _placeholder(
            f"picture is {width} columns wide — {picture.PICTURE_BUDGET} is the budget; "
            "shorten a ref or split the manifest"
        )
    ]


def _signals_section(doc: dict) -> tuple[str, list[str]]:
    """SIGNALS: capacity, then every warning the document carried, then the ladder's own gap.

    WARNINGS ARE NEVER SWALLOWED. build_grid's docstring makes the argument for carrying them; this
    is where they surface. A document with a discovery, selection, sweep or fetch warning that
    printed nothing would be the exact silent-blindness shape CLAUDE.md's "Learned" catalogues.
    """
    grid_block = doc.get("grid") or {}
    capacity = doc.get("capacity") or {}
    lines: list[str] = []
    if capacity.get("over_limit"):
        lines.append(f"  {BOLD}{capacity['active']} sessions need attention{NC} (limit: {capacity['limit']})\n")
    lines.extend(_placeholder(warning) for warning in grid_block.get("warnings") or [])
    lines.extend(_cycle_lines(grid_block))
    # BEFORE the resolution line, deliberately: `_resolution_line` is the section's last word on a
    # `--local` render and `test_the_last_word_on_a_local_page_is_that_nobody_looked` pins that.
    lines.extend(_width_line(grid_block))
    lines.extend(_resolution_line(grid_block))
    if not lines:
        return "", [_placeholder("nothing to report.")]
    return "", lines


SECTIONS: tuple[tuple[str, Callable[[dict], tuple[str, list[str]]]], ...] = (
    ("", _header_section),  # the cube; no ▸ line
    ("IN FOCUS", _focus_section),  # ABOVE the board -- the `Status:` invariant
    ("REPOSITORIES", _board_section),  # registry-wide in BOTH contexts
    ("CHAINS", _grid_section),
    ("QUEUED", _queued_section),
    ("SHIPPED", _shipped_section),
    # AC4. EIGHT SECTIONS NOW, and the insertion point is deliberate: NEXT reads the same grid CHAINS
    # draws, and sits below SHIPPED so the page reads history-then-future. Placing it here rather
    # than reserving an always-empty slot in AC2 is what that directive chose, so that the spine test
    # going red is a reviewable event rather than a diff nobody sees.
    ("NEXT", _next_section),
    ("SIGNALS", _signals_section),
)


def document(doc: dict) -> str:
    """THE ONE HUMAN ENTRY POINT. Iterates SECTIONS and joins; no branch on scope, mode or emptiness.

    Every branch that used to pick a renderer now lives inside one section builder, which is what
    makes the header list assertable against `SECTIONS` itself: extract the `▸ `-prefixed titles from
    any rendering, in any context, and they equal `tuple(t for t, _ in SECTIONS if t)`. A builder that
    returns nothing still renders its header plus one placeholder, so an empty section cannot silently
    disappear and take the invariant with it.
    """
    return "".join(line for title, build in SECTIONS for line in _section(title, *build(doc)))
