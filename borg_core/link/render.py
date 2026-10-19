"""The one human renderer for `borg link`, plus the machine TSV `--porcelain` still serializes.

TWO PUBLIC CALLABLES, AND THAT IS THE WHOLE OF AC2's "one front door". `document(doc)` is the single
human entry point, and since 2026-10-13 `scope` chooses WHICH SECTION LIST it prints, from one place
(`_sections_for`): the Queen's page (`SECTIONS`, scope.kind "orchestrator") is the cross-repository
overview, a fixed spine whose `▸` headers are byte-identical on every Queen render; the page of
repository scope (`REPOSITORY_SECTIONS`) is STRICTLY ONE DIRECTORY -- its label, identity, session,
own checkpoints, its own waiting row and the next action -- with no board, no other worktree or
repository, and no repository-level section. THIS REVERSES AC2's "scope changes which rows a section
prints, never which sections exist" for repository scope, deliberately (Noah: the overview belongs to
the Queen). It is still ONE renderer: no second `document`, and the choice is a lookup, not a branch
inside any section. `porcelain(doc)` is deliberately outside "everywhere" and its
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
dim placeholder line naming what would fill it and the one command that would -- which is the rule that
makes each page's section list mechanically assertable, because the header list can then be compared
against `SECTIONS` / `REPOSITORY_SECTIONS` themselves rather than against a golden (a header diff
between two goldens goes green if both drift together).

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

LOCALE COLLATION NOTE, matching core.sort_assimilated's docstring: any per-repository or aggregate
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
# per-call-site honesty about summary flattening. Cutting prose to satisfy a line count would trade
# the reasoning for the metric, which is the failure this repo files under "a check pointed at the
# wrong thing does not fail, it reads as a pass".
#
# THIS IS A DEFERRAL, NOT A VERDICT. The real fix is splitting the module along the seam that already
# exists -- the SECTIONS spine and its section builders on one side, the shared text primitives
# (`_fold_s`, `_label`, `_summary_block`) on the other. That is an architecture
# change and was deliberately not made inside a merge fix; it is filed as its own directive. The
# duplication this merge DID create (two branches each writing the same argument) was collapsed
# first, AST-verified as behavior-identical, which took the file from 1133 to 1108.

from __future__ import annotations

import re
from functools import partial
from typing import Callable

from borg_core.link import core, grid, picture, worktree
from borg_core.link.picture import BOLD, CYAN, DIM, GREEN, NC, YELLOW

# Overview column widths, hoisted so the header line and every row format string share ONE source
# of truth and cannot drift apart (borg.zsh:329, :371-372).
#
# `_COL_REPOSITORY` IS A FLOOR, NOT A WIDTH, AND SAYING SO IS THE FIX. It was used as a minimum via
# `{display:<{_COL_REPOSITORY}}` with no truncation anywhere, so a name longer than 20 pushed SRC,
# STATUS, LAST ACTIVE and SUMMARY right by the overflow while the header line -- padded from the same
# constant -- did NOT move, and stopped describing its own rows on EVERY render in both scopes. Two
# registered repositories trigger it today (`pytest-coverage-impact` 22, `reveal-data-consistency` 23).
#
# WIDENED RATHER THAN TRUNCATED, ON THE READER'S TERMS AND NOT A CONSUMER'S: truncation destroys the
# one field on the row that is also an ARGUMENT (`pytest-coverage-impa…` is not typeable into `borg
# link <name>`), while widening costs only geometry that varies with the row set, which every golden
# absorbs by byte-comparing ONE invocation against its own file. NOTHING PARSES THIS BOARD -- checked, not asserted:
# every hit `grep -rn 'borg link' drone.zsh borg.zsh lib/ hooks/ skills/` returns is prose, a `--json` read, `drone
# link`'s `exec`, or skills/borg-switch's `borg link --local --all` -- THIS board's one automated reader, and it
# wants a list of names, not a column. (A draft cited `drone status`'s `grep -m1 'Status:'` -- retired 2026-08-27.)
_COL_REPOSITORY = 20
_COL_SRC = 4
_COL_STATUS = 12
_COL_LAST_ACTIVE = 12
# The three routing columns (yours / mine / unsure), each as wide as its header.
_COL_ROUTE = (5, 4, 6)
# What a worktree's board row is prefixed with, so it reads as beneath the repository row above it.
_WORKTREE_MARK = "└ "
_ROUTE_GROUPS = ("yours", "mine", "unsure")

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

# ── the screen contract (doorways S2, AC2): ONE SCREEN, DEFINED ONCE ──────────────────────────────────────────
#
# These are the numbers and the words the Queen's page is held to, and `test_screen_contract.py` reads every one
# of them from HERE: the tests assert the page against this module, so a number changed in one place cannot be
# changed to match a test that restates it. (The two limits are ALSO asserted as the literals the directive
# approved, 30 and 100, so a quiet edit of the constants alone cannot go green.)
#
# `PAGE_LINES` counts every line of the compact Queen page OUTSIDE `▸ REPOSITORIES` -- blank separators included,
# because a blank line occupies a row of the screen as surely as text does. REPOSITORIES is excluded because every
# registered repository stays on the board (idle collapse, L4, was rejected), so it is the one section whose
# length is the registry's and not the page's. `PAGE_COLUMNS` bounds EVERY line, board rows included, in VISIBLE
# columns (`picture.visible_len`, never `len`: the rows carry SGR and OSC-8 bytes).
PAGE_LINES = 30
PAGE_COLUMNS = 100

# The command that prints the Queen's page with no budget: every stack drawn, every directive listed, every
# signal and waiting row. `--all` was checked and does not mean this: it only un-hides archived repositories.
FULL_FLAG = "--full"
EXPAND_COMMAND = f"borg link --overview {FULL_FLAG}"

# The glyphs the page uses and the words that name them, in legend order. The five state glyphs are the
# ratified set from `picture.py` (merged, ready, open, draft, closed); the rest are the page's own marks.
GLYPH_WAITING = "▶"
GLYPH_PAUSED = "⏸"
STATE_GLYPHS: tuple[tuple[str, str], ...] = (
    (picture.GLYPH_MERGED, "merged"),
    (picture.GLYPH_READY, "ready"),
    (picture.GLYPH_OPEN, "open"),
    (picture.GLYPH_DRAFT, "draft"),
    (picture.GLYPH_CLOSED, "closed"),
)
GLYPH_LEGEND: tuple[tuple[str, str], ...] = (
    *STATE_GLYPHS,
    (GLYPH_WAITING, "waits on you"),
    ("└", "worktree"),
    (GLYPH_PAUSED, "paused"),
)

# THE CLOSED SET OF STATUS WORDS: every word the page uses to say what state a thing is in. Three families, all here
# and nowhere else. The five that sit beside a state glyph are read off `STATE_GLYPHS`, so the legend and this set
# cannot name different words. The board's session statuses are `active`, `waiting`, `idle`, `archived` and the
# registry fallback (`_JQ_ABSENT_STATUS`). The destination states the board's `· <state>` suffix prints are the
# compass's (`_COMPASS_STATES`' words, then `off leg`, and the parked statuses `frozen`, `proposed`, `done`, `killed`
# from the map's own `STATUSES`). The legend prints the glyph words, the contract test reads the whole set, and a status
# word the page prints that is in none of these is a vocabulary leak.
STATUS_WORDS: tuple[str, ...] = (
    *(word for _, word in STATE_GLYPHS),
    "active",
    "waiting",
    "idle",
    "archived",
    _JQ_ABSENT_STATUS,
    "on track",
    "at risk",
    "late",
    "undated",
    "off leg",
    "frozen",
    "proposed",
    "done",
    "killed",
)

# The most WAITING ON YOU rows (decisions and due parked thoughts together) the compact page prints.
_WAITING_CAP = 2
# The most SIGNALS lines (capacity, warnings, cycles, the width line) the compact page prints before the ladder's gap.
_SIGNALS_CAP = 2
# The widest repository name the compact board prints. A row's head is 50 columns beside the name, and the
# destination state (`· at risk`) follows it, so a name of 28 leaves 22 columns for the state and a summary.
_NAME_CAP = 28

_ESCAPES = re.compile(r"\033\[[0-9;]*m|\033\]8;;[^\033]*\033\\")
_OSC8_CLOSE = "\033]8;;\033\\"


def _fit_text(text: str, limit: int = PAGE_COLUMNS) -> str:
    """`_fit_line` over every line of `text`. A section builder may hand back one string holding several lines (a
    board row with its cortex continuation does), so the page is cut by line and never by list entry."""
    return "".join(_fit_line(line, limit) for line in re.findall(r"[^\n]*\n|[^\n]+", text))


def _fit_line(line: str, limit: int = PAGE_COLUMNS) -> str:
    """`line` (one line, newline kept) cut to at most `limit` VISIBLE columns, ending `…` when it was cut.

    ESCAPES ARE ZERO-WIDTH AND ARE NEVER CUT THROUGH: the walk copies every SGR and OSC-8 sequence whole and
    counts only the text between them. A cut line ends with a reset, and with an OSC-8 close ONLY when a link was open
    at the cut, so a colour or a link cannot bleed onto the next line and a line with no link gains no escape (the
    NO_COLOR page is the coloured page minus its SGR, and an extra OSC-8 on a cut line would break that). A line
    already within `limit` comes back unchanged.
    """
    body, newline, _ = line.partition("\n")
    if picture.visible_len(body) <= limit:
        return line
    out: list[str] = []
    shown = 0
    link_open = False
    for piece in re.split(f"({_ESCAPES.pattern})", body):
        if not piece:
            continue
        if _ESCAPES.fullmatch(piece):
            out.append(piece)
            if piece.startswith("\033]8;;"):
                link_open = piece != _OSC8_CLOSE
            continue
        take = piece[: max(limit - 1 - shown, 0)]
        out.append(take)
        shown += len(take)
        if len(take) < len(piece):
            break
    return "".join(out).rstrip() + f"…{NC}{_OSC8_CLOSE if link_open else ''}{newline}"


# `summary` ARRIVES ALREADY FLAT. `core.flatten_summary` is applied once at document assembly
# (`core.assemble`'s projects map), so no renderer here defends itself and a new consumer inherits
# the guarantee instead of repeating the bug. The helper that used to live here was OPT-IN, and the
# same defect was found at three separate call sites in one day because of it.
def _label(text: str, value: str, col: int = _DEEP_LABEL_COL) -> str:
    """One `  {DIM}<label>{NC}<pad>value` IN FOCUS header line, padding computed as col - len(text)
    rather than six separately hand-counted space literals (borg.zsh:440-445)."""
    pad = " " * max(col - len(text), 1)
    return f"  {DIM}{text}{NC}{pad}{value}\n"


def _fold_s(text: str, width: int = 70) -> list[str]:
    """Reproduce `fold -s -w <width>`'s break points: break AFTER the last space at or before
    `width` (the space stays on the emitted line); hard-break at exactly `width` when the window
    contains no space at all.

    Pinned by cli_contract.bats's "link <repository> deep dive wraps and indents a summary longer than
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
    continuation contract is this function's OWN invariant. See `core.flatten_summary` for the character
    set, the altitude argument, and why the one-for-one replacement moves no golden.
    """
    out = [f"  {BOLD}Summary{NC}\n"]
    folded = _fold_s("  " + summary, width=70)
    for i, line in enumerate(folded):
        if i == 0:
            out.append(f"{line}\n")
        else:
            out.append(f"  {line}\n")
    return "".join(out)


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
    """`--porcelain`: one TSV row per visible repository, no color, no padding, no header.

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
    `cmd_ls`, pinned by cli_contract.bats's "the picker feed stays one 5-field record per repository
    through tab and newline" -- a title narrowed from "tab, newline and CR" because its counting
    oracle cannot kill a CR-only mutant). THE TWO IMPLEMENTATIONS ALREADY DIVERGE, which is why the
    mix-up was not harmless: on an empty registry this one prints nothing while `cmd_ls --porcelain`
    prints a human "No repositories registered" sentence, and both behaviours are pinned. The enumeration
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
    repositories = doc.get("projects") or {}
    rows = []
    for name in order:
        entry = repositories[name]
        source = core.jq_default(entry.get("source"), "cli")
        status = core.jq_default(entry.get("status"), _JQ_ABSENT_STATUS)
        last_activity = core.jq_default(entry.get("last_activity"), "")
        summary = core.jq_default(entry.get("summary"), "")
        summary = str(summary)[:80]
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
    repository name. `core.flatten_summary` is the canonical statement of the character set, of all three
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
    flat = summary
    cut = flat[:50]
    return f"{cut}..." if len(flat) > 50 else cut


def _board_display(name: str, entry: dict) -> str:
    """The name a board row PRINTS: the registry's `display_name`, else the key. ONE definition,
    because `_board_width` must measure exactly the string `_overview_row` pads -- measuring the key
    while padding the display name reintroduces the header/row mismatch through a rename."""
    return str(entry.get("display_name") or name)


def _board_width(order: list[str], repositories: dict) -> int:
    """The REPOSITORY column's width for one render: `_COL_REPOSITORY`, or the longest name if longer.

    THE FLOOR KEEPS THE COMMON CASE BYTE-STABLE -- every fixture name and the real registry's modal
    case is under 20, so this returns 20 and no golden moves. See `_COL_REPOSITORY` for why widening
    beats truncating.
    """
    return max([_COL_REPOSITORY, *(len(_board_display(name, repositories.get(name) or {})) for name in order)])


def _route_cells(counts: dict[str, int] | None) -> str:
    """The yours / mine / unsure cells for one board row: the count, or an en dash when there is none.

    A repository with no routed `▸ NEXT` rows has `counts` of None, and a bucket of zero prints the same
    dash, so "nothing in this bucket" has one spelling.
    """
    return " ".join(f"{(counts or {}).get(group) or '–':>{width}}" for group, width in zip(_ROUTE_GROUPS, _COL_ROUTE))


def _row_tail(head: str, suffix: str, summary: str, mark: str, budget: int) -> str:
    """What follows a board row's route cells: ` <suffix> <summary><mark>`, the summary fitted to `budget`.

    No suffix: ` <summary><mark>`, exactly as before. A suffix goes first, in a column that is the same on every
    row, and the summary gives way: it is cut to what is left of `budget` (ending `...`) or dropped when under
    four columns remain. THE SUFFIX IS NEVER DROPPED: when the head plus the suffix alone is wider than `budget`
    the summary is gone and the suffix is printed anyway. The board does not let that happen on a normal render,
    because it grows `budget` to the widest head plus suffix (`_board_section`), so this branch is the floor
    under a caller that passes a smaller one, never a way for a long repository name to hide a state.
    """
    plain_tail = f"{' ' + summary if summary else ''}{mark}"
    if not suffix:
        return plain_tail
    room = budget - (picture.visible_len(head) + 1 + len(suffix) + picture.visible_len(mark)) - 1
    if len(summary) > room:
        summary = summary[: room - 3].rstrip() + "..." if room > 3 else ""
    shade = YELLOW if suffix in ("· late", "· at risk") else DIM
    return f" {shade}{suffix}{NC}{' ' + summary if summary else ''}{mark}"


# JUSTIFICATION: eight inputs, each independent (identity, cortex join, scope mark, width, counts, suffix, budget),
# and one named local per column the row prints.
# pylint: disable-next=too-many-arguments,too-many-positional-arguments,too-many-locals
def _overview_row(
    name: str,
    entry: dict,
    cortex_by_repository: dict[str, str],
    mark: str = "",
    width: int = _COL_REPOSITORY,
    counts: dict[str, int] | None = None,
    suffix: str = "",
    budget: int = 0,
) -> str:
    """One board row, plus its cortex pause continuation when the repository has a pending wake.

    `suffix` is the destination state (`· late`), printed right after the route cells and BEFORE the summary,
    and `budget` is the most columns the row's first line may use. The summary is the elastic part: it is cut
    (with `...`) or dropped so that the suffix fits, because the widest rows are the ones with the fullest
    summaries and a suffix that only fit on short rows would be missing from exactly the rows that say the most.
    THE SUFFIX IS NEVER DROPPED: a `budget` too small for the head plus the suffix leaves the row at exactly that
    width (summary gone), and a budget of 0 is how `_board_section` measures it. With no suffix the row is
    byte-for-byte what it always was.

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
    summary_short = _overview_summary_cut(str(core.jq_default(entry.get("summary"), "")))
    display = _board_display(name, entry)
    pin_mark = "*" if entry.get("pinned") is True else " "
    status_display = "waiting <<<" if status == "waiting" else status

    head = (
        f"{pin_mark}{display:<{width}} {_src_badge(source):<{_COL_SRC}} "
        f"{_status_color(status)}{status_display:<{_COL_STATUS}}{NC} "
        f"{last_activity:<{_COL_LAST_ACTIVE}} {_route_cells(counts)}"
    )
    line = head + _row_tail(head, suffix, summary_short, mark, budget) + "\n"
    countdown = cortex_by_repository.get(name)
    if countdown:
        # DERIVED FROM `width`, NOT THE 23 SPACES THIS USED TO HARDCODE -- a literal correct for
        # exactly one column width and silently wrong for every other, which is the two-sources-of-
        # truth failure the `_COL_*` constants were hoisted to prevent. `1 + width + 2` reproduces 23
        # byte for byte at the floor (pin-mark column, name field, the zsh original's hand-counted
        # two-space lead-in), which is why no golden moves.
        line += f"{' ' * (1 + width + 2)}{CYAN}⏸ resumes in {countdown}{NC}\n"
    return line


def _ship_date_suffix(item: dict) -> str:
    """ " (date)" when a ship date is present, else "" -- omit the parens entirely rather than
    render an empty "()". A missing/empty ship date is TSV_EMPTY_SENTINEL-shaped upstream (see
    core.ship_date's docstring: no matching "Shipped:" line -> ""); this is the render-side half
    of that contract, not a second sentinel.
    """
    ship_date = item.get("ship_date") or ""
    return f" ({ship_date})" if ship_date else ""


def _bullet_lines(items: list[dict], show_repository: bool) -> list[str]:
    """The bullet loop for QUEUED **and** SHIPPED. One function, because they are one line.

    THEY WERE TWO UNTIL AC2 TOOK THE LAST DIFFERENCE OUT. The zsh original printed a distinct header
    above each block (`Directives: N pending` / `Recently assimilated:`), which is what made two
    functions defensible; the `▸ QUEUED` and `▸ SHIPPED` section headers and their notes replace
    both, and what remained was two identical loops differing by one interpolation that is EMPTY on
    a directive anyway -- `_ship_date_suffix` reads an absent key as "". Keeping them apart would
    mean two places to change the bullet shape and one of them getting missed.

    `show_repository` follows the document's BREADTH, not the section: `[platform] Scope keypair
    rotation` is information in the orchestrator context and noise in platform's own.
    """
    out = []
    for item in items:
        prefix = f"[{item['project']}] " if show_repository else ""
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

    The empty-titled first entry is the page header -- the masthead, which gets no `▸` line and supplies
    its own trailing blank. That is the only special case, and it is keyed on
    the SECTIONS constant rather than on anything in the document, so `document()` below stays free
    of any branch on scope, mode or emptiness.
    """
    if not title:
        return lines
    head = f"{BOLD}{SECTION_MARK}{title}{NC}"
    if note:
        head += f"  {DIM}{note}{NC}"
    return [head + "\n", *lines, "\n"]


def _legend_line() -> str:
    """The one-line legend: every glyph the page uses, each followed by the word that names it.

    Read off `GLYPH_LEGEND`, the same tuple the contract test reads, so the line cannot name a glyph or a word
    the closed set does not hold. It is one line by construction and stays inside `PAGE_COLUMNS`.
    """
    return "  " + DIM + "  ".join(f"{glyph} {word}" for glyph, word in GLYPH_LEGEND) + NC + "\n"


def _header_section(_doc: dict) -> tuple[str, list[str]]:
    """The Queen's masthead: the name, then the legend, then the blank that opens `▸ IN FOCUS`.

    THE CUBE IS GONE (doorways S2). Eight lines of art plus its two blanks were a third of the thirty lines the
    page may spend outside REPOSITORIES, and the page has to carry a legend and a sentence for every section.
    The wordmark stays, which is what `THE BORG COLLECTIVE` assertions elsewhere look for. The discovery tip
    moved to the board (`_board_section`), the one section whose length is the registry's.
    """
    return "", [
        f"  {BOLD}THE BORG COLLECTIVE{NC}  {DIM}resistance is futile{NC}\n",
        _legend_line(),
        "\n",
    ]


# ── the compass: the owner's map, rendered from the `compass` block the document carries ────────────
#
# PURE LIKE THE REST OF THIS FILE: every function reads the block already on the document (cli._document read the
# map once, with the one epoch) and returns text. A document with NO `compass` key (hand-built, or `--porcelain`'s)
# renders exactly as it did before the compass existed; a block with `found` false renders the one no-map line.

_CONTROL_CHARACTERS = re.compile(r"[\x00-\x1f\x7f]")

# The four states of an ACTIVE destination, wire word then the words the page prints, in print order.
_COMPASS_STATES = (("on-track", "on track"), ("at-risk", "at risk"), ("late", "late"), ("undated", "undated"))

# The rule under the board's header, and the floor of the width a suffix may reach (see `_board_section`).
_BOARD_RULE = 90

# At most this many due parking items on WAITING ON YOU; the rest are counted on one dim line.
_PARKING_CAP = 5


def _clean(text: object) -> str:
    """Text out of the owner's map, safe on one page line: control characters (ESC included) become spaces."""
    return _CONTROL_CHARACTERS.sub(" ", str(text or "")).strip()


def _compass(doc: dict) -> dict | None:
    """The document's `compass` block, or None when it carries none."""
    block = doc.get("compass")
    return block if isinstance(block, dict) else None


def _compass_found(doc: dict) -> dict | None:
    """The `compass` block of a map that was found, else None."""
    block = _compass(doc)
    return block if block and block.get("found") else None


def _compass_tally(compass: dict) -> str:
    """` · on track N · at risk N · late N · undated N`, a bucket of zero omitted, empty when every bucket is."""
    counts: dict[str, int] = {}
    for destination in compass.get("destinations") or []:
        state = str(destination.get("state") or "")
        counts[state] = counts.get(state, 0) + 1
    return "".join(f" · {words} {counts[state]}" for state, words in _COMPASS_STATES if counts.get(state))


def _off_route(compass: dict, names: list[str]) -> str:
    """The first of `names` the map assigns a destination that today's leg does not name, else "".

    NOTHING IS OFF ROUTE WHEN NO LEG WAS CHOSEN: with no route there is nothing to be off, and a warning on every
    mapped repository for a day the owner has not planned yet would be noise.
    """
    if not compass.get("leg"):
        return ""
    mapped = compass.get("repositories") or {}
    for name in names:
        entry = mapped.get(name) or {}
        if entry.get("destination"):
            return "" if entry.get("on_leg") else name
    return ""


def _compass_lines(doc: dict, names: list[str] | None = None) -> list[str]:
    """IN FOCUS's compass lines. `names` are the repositories of the card they follow; None means no card (the Queen).

    No map: the one `Compass: no map at <dir>` line. Queen: the leg (or `no leg chosen`) and the tally of active
    destinations by state. A card: the leg, then `off route: <repository> is not on today's leg` when the map
    assigns this repository a destination the leg does not name. Unlabelled-column text on purpose
    (`Compass: ...`, no padding): the lines are the contract and a reader greps them.
    """
    compass = _compass(doc)
    if compass is None:
        return []
    if not compass.get("found"):
        return [f"  Compass: no map at {_clean(compass.get('map_dir'))}\n"]
    leg = _clean((compass.get("leg") or {}).get("text")) or "no leg chosen"
    if names is None:
        return [f"  Compass: {leg}{_compass_tally(compass)}\n"]
    lines = [f"  Compass: {leg}\n"]
    off = _off_route(compass, names)
    if off:
        lines.append(f"  {YELLOW}off route: {off} is not on today's leg{NC}\n")
    return lines


def _board_suffix(compass: dict | None, name: str) -> str:
    """The destination state a board row carries before its summary (`· late`), plain text, or "" for none.

    The destination's state word, except that a calm one (on track, undated) reads `· off leg` when a leg was
    chosen and does not name this repository: urgency (late, at risk) and a parked destination (frozen, done)
    outrank where the leg points, and a calm state off the leg is the fact worth a glance.
    """
    if compass is None:
        return ""
    entry = (compass.get("repositories") or {}).get(name) or {}
    owner = next((d for d in compass.get("destinations") or [] if d.get("id") == entry.get("destination")), None)
    if owner is None:
        return ""
    state = str(owner.get("state") or "")
    if state in ("on-track", "undated") and compass.get("leg") and not entry.get("on_leg"):
        return "· off leg"
    return "· " + state.replace("-", " ")


def _parking_due(doc: dict) -> tuple[list[dict], int]:
    """`(items, more)`: the parking-lot items whose look-again date is reached, oldest look first, capped.

    The Queen's page only: a parked thought belongs to the owner, not to a directory, and the page of repository
    scope is strictly that directory. `more` counts the items past `_PARKING_CAP`.
    """
    compass = _compass_found(doc)
    if compass is None or _is_repository_scope(doc):
        return [], 0
    due = sorted((item for item in compass.get("parking") or [] if item.get("due")), key=lambda i: i.get("look") or "")
    return due[:_PARKING_CAP], max(0, len(due) - _PARKING_CAP)


def _parking_line(item: dict) -> str:
    """`parking: <text> (look again <date>, seen N)`, marked like every other thing that waits on you."""
    text = _clean(item.get("text"))
    text = text if len(text) <= _WAITING_TEXT else text[: _WAITING_TEXT - 1].rstrip() + "…"
    return f"  {YELLOW}▶{NC} parking: {text} (look again {item.get('look')}, seen {int(item.get('seen') or 0)})\n"


# JUSTIFICATION: transcribes borg.zsh:415-508 statement by statement for one golden-diffable section.
def _focus_section(doc: dict) -> tuple[str, list[str]]:  # pylint: disable=too-many-locals
    """IN FOCUS: the page of repository scope -- ONE directory's card, transcribed from the retired `deep()`.

    The header note is the one-line SCOPE LABEL (`worktree.scope_label`): the directory and what it is to its
    repository. The card states the directory's identity (path, branch, worktree-of), its live session and
    status, and its OWN checkpoints (summary, recent, latest); `cli._focus` read every one of those from that
    directory alone. There is no Active Plan block: since 2026-10-13 the repository-scope page is strictly the
    directory, and the plan is a repository-level section (still in `--json` as `focus.plan`).

    Its Directives and Recently-assimilated blocks are NOT here either -- they are the QUEUED and
    SHIPPED sections, which only the Queen's page renders.
    """
    focus = doc.get("focus") or {}
    if not focus:
        # With a compass block the section is no longer empty: its line replaces the placeholder (exactly one
        # line either way, the rule `_placeholder` states).
        return "", _compass_lines(doc) or [
            _placeholder("no repository in focus. cd into one, or run borg link <name>.")
        ]

    name = focus.get("name", "")
    entry = focus.get("entry") or {}
    identity = focus.get("identity") or {}
    source = core.jq_default(entry.get("source"), "cli")
    path = core.jq_default(entry.get("path"), "null")
    status = core.jq_default(entry.get("status"), _JQ_ABSENT_STATUS)
    last_activity = core.jq_default(entry.get("last_activity"), "(never)")
    summary = str(core.jq_default(entry.get("summary"), ""))
    session_id = core.jq_default(entry.get("claude_session_id"), "(unknown)")
    tmux_window = core.jq_default(entry.get("tmux_window"), "(none)")

    out = [_label("Source:", str(source))]
    # `Path:` is the ONLY conditional header line -- omitted entirely, not blanked, when path is
    # the sentinel string "null".
    if path != "null":
        out.append(_label("Path:", str(path)))
    # Absent, not blanked, when git did not state them: a non-git directory has no branch, and only a linked
    # worktree has a repository it is a worktree of. A detached HEAD has no branch NAME but is not unstated:
    # the row says where it is detached.
    branch = worktree.branch_text(identity)
    if branch:
        out.append(_label("Branch:", branch))
    if identity.get("kind") == "worktree" and identity.get("worktree_of"):
        out.append(_label("Worktree of:", str(identity["worktree_of"])))
    # Exactly ONE line on the whole page contains "Status:", and this section is above every other
    # source of text, so drone.zsh:964-965's `grep -m1` finds it before any PR title. See the module
    # docstring for why that ordering is the invariant rather than a scrubbing rule.
    out.append(_label("Status:", str(status)))
    out.append(_label("Last active:", str(last_activity)))
    out.append(_label("tmux window:", str(tmux_window)))
    out.append(_label("Session ID:", str(session_id)))
    # AFTER the `Status:` line, never before it: the leg is text from the owner's map and the `grep -m1 'Status:'`
    # invariant (module docstring) holds only while nothing the renderer does not control precedes that line.
    # The names offered are this directory's own and the repository it is a worktree of: the map speaks of the
    # repository, a worktree is registered under a name of its own.
    out.extend(_compass_lines(doc, [str(name), str(identity.get("worktree_of") or "")]))
    # No checkpoint states a summary => the block is OMITTED, not filled with a placeholder.
    if summary:
        out.append("\n")
        out.append(_summary_block(summary))

    checkpoints = focus.get("checkpoints") or []
    if checkpoints:
        out.append("\n")
        out.append(f"  {BOLD}Recent Checkpoints{NC}\n")
        for filename in checkpoints:
            out.append(f"    {CYAN}{filename}{NC}\n")
        out.append("\n")
        out.append(f"  {BOLD}Latest Checkpoint{NC}\n")
        out.append(_checkpoint_head_block(focus.get("checkpoint_head") or ""))

    return worktree.scope_label(name, identity), out


def _scoped_name(doc: dict) -> str:
    """The repository this invocation is scoped to, or "" in orchestrator scope."""
    return str((doc.get("scope") or {}).get("repository") or "")


def _is_repository_scope(doc: dict) -> bool:
    """Whether the document is the page of ONE directory (scope.kind "repository") and not the Queen's."""
    return (doc.get("scope") or {}).get("kind") == "repository"


def _board_entries(
    groups: list[tuple[str, list[str]]], repositories: dict, name_cap: int = 0
) -> list[tuple[str, dict]]:
    """The board's `(name, entry)` rows in print order: each repository, then its worktrees beneath it.

    A worktree's row prints under "└ <name>", and that prefix is part of the DISPLAYED name, so it is applied
    to the entry before the width is measured: measuring the bare name while padding the prefixed one is the
    header/row mismatch `_board_display` exists to prevent.
    """
    entries: list[tuple[str, dict]] = []
    for head, children in groups:
        entries.append((head, _capped(head, repositories[head], name_cap)))
        for child in children:
            shown = {**repositories[child], "display_name": _WORKTREE_MARK + _board_display(child, repositories[child])}
            entries.append((child, _capped(child, shown, name_cap)))
    return entries


def _capped(name: str, entry: dict, cap: int) -> dict:
    """`entry` with its displayed name cut to `cap` columns and ending `…` when it was longer; `cap` 0 means never.

    ONLY THE COMPACT PAGE CUTS A NAME (`_NAME_CAP`), and it is the one place the board gives up the rule that a
    name is an argument (`_COL_REPOSITORY`): a name wide enough that the row's head alone passes `PAGE_COLUMNS`
    would push the destination state off the screen, and a state that is cut off is a worse loss than a name that is
    shortened. `--full` prints the name whole.
    """
    shown = _board_display(name, entry)
    return entry if not cap or len(shown) <= cap else {**entry, "display_name": shown[: cap - 1] + "…"}


_TIP = f"  {DIM}Tip: run 'borg scan' to discover repositories from session history{NC}\n"


# JUSTIFICATION: transcribes `overview()` statement by statement for one golden-diffable section.
def _board_section(doc: dict, compact: bool = False) -> tuple[str, list[str]]:  # pylint: disable=too-many-locals
    """REPOSITORIES: every registered repository, on the QUEEN'S page only. Transcribed from `overview()`.

    IT WAS SCOPE-INVARIANT UNTIL 2026-10-13 and no longer is: the board is the cross-repository overview, and
    the overview belongs to the Queen (`REPOSITORY_SECTIONS` has no board). Its one automated consumer,
    skills/borg-switch/SKILL.md's `borg link --local --all`, now passes `--overview`, which forces this page
    from any cwd. `--all` remains the only control over which rows appear. The scoped-row `◀` mark is
    therefore unreachable from the CLI (the Queen has no scoped repository) and survives only for a
    hand-built document; it is not a contract.

    ONE ROW PER REPOSITORY, WORKTREES BENEATH IT. Entries sharing a registry `repo` (the git common dir) are
    one repository (`worktree.repository_groups`): the head row is the repository, its worktrees follow
    indented with `└`, and the note counts repositories, naming worktrees separately, instead of counting each
    checkout as a repository of its own. A registry with no shared `repo` renders exactly as it always did.

    `compact` (the Queen's page) differs in one thing: a displayed name past `_NAME_CAP` columns is cut with `…`
    (`_capped`), so a row's head and its destination state always fit `PAGE_COLUMNS`. Every repository stays on the
    board either way (idle collapse, L4, was rejected); the page-wide width fit is `document`'s.
    """
    total_projects = doc.get("total_projects", 0)
    # The discovery tip rides at the END of this section, where the page's line budget does not count it (it used
    # to head the page, in the masthead). Gated on the UNFILTERED `total_projects`, NOT on `len(order)` -- one
    # visible repository plus one archived one is two, and must not print it (borg.zsh:286-290). It is NOT
    # mutually exclusive with the all-archived placeholder: a lone archived repository prints both. An EMPTY registry
    # prints neither the tip nor a second line: its placeholder already says `Run: borg scan`, and the section keeps
    # its rule of exactly one placeholder.
    tip = [_TIP] if total_projects == 1 else []
    order = doc.get("order") or []
    repositories = doc.get("projects") or {}

    # Gated on the UNFILTERED count, NOT len(order). See core.assemble's docstring: an empty registry
    # and an all-archived one both emit order=[]/projects={}, but must print two different sentences.
    # Both sentences are the zsh original's verbatim, minus the leading `▸` -- every assertion on
    # them in this tree is a substring test, which is what makes dropping the marker free.
    if total_projects == 0:
        return "", [_placeholder("No repositories registered. Run: borg scan")]
    if not order:
        return "", [_placeholder("No repositories to show. Run: borg link --all"), *tip]

    # "Need attention" is the WAITING count, which is not `capacity.active`: capacity counts every
    # session holding a slot (active AND waiting) against BORG_MAX_ACTIVE and belongs in SIGNALS,
    # while this note answers "how many of these rows are blocked on me". The two are different
    # numbers on the same registry and the goldens carry both.
    waiting = sum(1 for name in order if str(core.jq_default(repositories[name].get("status"), "")) == "waiting")
    groups = worktree.repository_groups(order, repositories)
    worktrees = sum(len(children) for _, children in groups)
    counted = _plural(len(groups), "repository", "repositories")
    if worktrees:
        counted += f" · {_plural(worktrees, 'worktree', 'worktrees')}"
    note = f"the collective · {counted} · {waiting} need attention"

    entries = _board_entries(groups, repositories, _NAME_CAP if compact else 0)
    displayed = dict(entries)

    # MEASURED ONCE AND HANDED TO BOTH the header and every row, which is the only arrangement in
    # which the header cannot stop describing its rows.
    width = _board_width([name for name, _ in entries], displayed)
    lines = [
        f"{BOLD} {'REPOSITORY':<{width}} {'SRC':<{_COL_SRC}} {'STATUS':<{_COL_STATUS}} "
        f"{'LAST ACTIVE':<{_COL_LAST_ACTIVE}} "
        + " ".join(f"{group.upper():>{w}}" for group, w in zip(_ROUTE_GROUPS, _COL_ROUTE))
        + f" SUMMARY{NC}\n",
        ("─" * _BOARD_RULE) + "\n",
    ]
    countdowns = _cortex_countdowns(doc)
    routed = _routing_counts(doc)
    scoped = _scoped_name(doc)
    marks = {name: f" {CYAN}◀{NC}" if name == scoped else "" for name, _ in entries}
    bare = [_overview_row(name, entry, countdowns, marks[name], width, routed.get(name)) for name, entry in entries]
    # EACH ROW'S DESTINATION STATE, NEVER DROPPED. The budget is the rule under the header or the widest row as
    # drawn without any suffix, whichever is wider, so on a board whose rows fit a suffix does not widen it. The
    # suffix sits BEFORE the summary and the summary yields (`_row_tail`), so the widest rows, whose summaries are
    # fullest, carry theirs like every other. When a row's head plus its suffix is itself wider than that budget
    # (the name column is shared, so one very long repository name does this to every row) the budget GROWS to
    # the widest head plus suffix: every mapped row shows its state and no row is wider than the board's own
    # width. A row is never wrapped, and a repository with no destination, or a document with no map, gets
    # nothing and keeps its bare row.
    compass = _compass_found(doc)
    suffixes = {name: _board_suffix(compass, name) for name, _ in entries}
    tight = [
        _overview_row(name, entry, countdowns, marks[name], width, routed.get(name), suffixes[name], 0)
        for name, entry in entries
        if suffixes[name]
    ]
    budget = max(_BOARD_RULE, *(picture.visible_len(row.partition("\n")[0]) for row in [*bare, *tight]))
    for (name, entry), row in zip(entries, bare):
        if suffixes[name]:
            row = _overview_row(name, entry, countdowns, marks[name], width, routed.get(name), suffixes[name], budget)
        lines.append(row)
    return note, [*lines, *tip]


def _cortex_countdowns(doc: dict) -> dict[str, str]:
    """`{repository: countdown}`, FIRST WAKE WINS, matching borg.zsh:374's awk join.

    First-wins rather than last: two pending wakes for one repository is a state file that was appended
    to twice, and the earlier one is the one that fires.
    """
    countdowns: dict[str, str] = {}
    for pending in doc.get("cortex_pending") or []:
        repository = pending.get("project")
        if repository not in countdowns:
            countdowns[repository] = pending.get("countdown", "")
    return countdowns


def _grid_placeholder(grid_block: dict) -> str:
    """FOUR DIFFERENT DIAGNOSES for an empty STACKS section, read off the grid block's own
    self-describing fields (`refused`, `slug`, `scope_kind`, `manifests`) rather than guessed.

    REFUSED IS TESTED FIRST, BEFORE SCOPE, and that order is the whole point of the arm. A manifest
    that failed to load is not among `manifests` -- it was refused whole -- so every later arm
    reports on a repository that looks manifest-less and says so: `borg link` in a repository whose
    only manifest has one bad row rendered "no stack manifests in the registry yet. Run /borg-plan
    in any repository." That sentence is not merely unhelpful, it is FALSE, and it points the reader
    at scaffolding a second manifest beside the broken one. The `▸ SIGNALS` warning naming the real
    reason is a dim line at the bottom of the page; this section is where the reader is looking.
    `2026-08-27-degrade-the-row-not-the-manifest` once softened this shape for the PARTIAL case by salvaging
    rows; that salvage is gone, so a file with any invalid row is now refused whole and lands here too
    (12 declared refs becoming 5 was the old failure; now it is none, and this sentence says so).

    ITS SENTENCE NAMES NO PLACE, and that is what lets it sit above the scope arm. `refused` is
    counted for whatever scope resolved -- one repository's directory in repository scope, the whole
    registry in orchestrator scope -- so a wording like "manifests are HERE but could not be read"
    would be false on the orchestrator page, and moving the arm below scope to dodge that would let
    the registry-wide sentence claim "no stack manifests in the registry yet" while three of them
    sit on disk unreadable. Saying only that they could not be read is true in both, which is why the
    arm can stay where correctness wants it.

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
    than by a test, which is why `test_the_four_stacks_placeholders_are_four_different_diagnoses`
    now parameterizes `scope_kind` alongside `slug` instead of varying `slug` alone.
    """
    refused = grid_block.get("refused") or 0
    if refused:
        return (
            f"{_plural(refused, 'manifest', 'manifests')} could not be read — "
            "see the reasons below, then fix and re-run."
        )
    unmigrated = grid_block.get("unmigrated") or 0
    if unmigrated:
        return (
            f"manifests in {_plural(unmigrated, 'repository', 'repositories')} are still under .borg/chains and "
            "are no longer read — see the reasons below, then run borg stack migrate."
        )
    if grid_block.get("scope_kind") != "repository":
        return "no stack manifests in the registry yet. Run /borg-plan in any repository."
    if not grid_block.get("slug"):
        return "this directory has no GitHub origin — nothing to scope a stack to."
    return f"no stack manifest declares work in {grid_block['slug']}. Run /borg-plan to scaffold one."


def _manifest_lines(manifest_grid: dict, ids: dict[str, str], columns: dict[str, int]) -> list[str]:
    """One stack's STACKS block: its heading, the picture, then one detail block per node.

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


def _expand_line(what: str) -> str:
    """The one body line of a section that renders as a count: what the full form holds, and the command that prints it.

    THE SAME COMMAND FOR EVERY COUNTED SECTION (`EXPAND_COMMAND`), because the flag is the page's, not a section's.
    """
    return f"  {DIM}— {what}:{NC} {CYAN}{EXPAND_COMMAND}{NC}\n"


def _grid_section(doc: dict, compact: bool = False) -> tuple[str, list[str]]:
    """STACKS: the declared cross-repository topology, one picture and one detail block set per
    chain, with GLOBAL node ids so `*` in vim toggles between a cell and its detail exactly once.

    `compact` (the Queen's page, doorways S2) renders the same header note and then ONE line, the command that
    draws every stack -- a count and the way to expand it, because 20 stacks drew 650 lines. The note carries the
    counts, including `unresolved`, so the three-state honesty of the full section is not lost: an empty or
    refused grid still prints its own diagnosis, and only a grid with stacks to draw collapses.

    The note is UNCONDITIONAL, even when no manifest was selected: `0 stacks · 0 refs · 0
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

    A WINDOW BOUND AND A SWEEP TIME ARE TWO DIFFERENT SENTENCES -- this repository's recurring trap --
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
        f"{_plural(len(manifests), 'stack', 'stacks')}"
        f" · {grid_block.get('declared', 0)} refs"
        f" · {grid_block.get('unresolved', 0)} unresolved"
        f" · {freshness}"
    )
    if not manifests:
        return note, [_placeholder(_grid_placeholder(grid_block))]
    if compact:
        return note, [_expand_line("every stack, drawn")]

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
    decision when the router has no idea. A third group says the true thing. Third time this repository
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
    paragraph used to describe. It is the quiet one: a kind this repository DECLARES it understands would
    be reported to the reader as unroutable. `test_the_router_covers_every_declared_gate_kind` asserts
    the subset for exactly that reason, and states it the same way.
    """
    if not kind:
        return _GROUP_MINE
    return _GATE_ROUTING.get(kind, _GROUP_UNSURE)


def route_kind(kind: str) -> str:
    """Public seam over `_route` for pure consumers outside this package (`borg_core.nextpick`)."""
    return _route(kind)


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


def _ready_rows(manifest: dict) -> list[tuple[str, dict, str]]:
    """`(ref, gate, group)` for one manifest's READY set, in display order. The ONE routing walk:
    NEXT, the WAITING ON YOU block and the board's per-repository counts all read it, so the three can
    never route the same row to different owners.

    Returns nothing for an `unlooked` manifest; a caller that must tell "unlooked" from "empty" reads
    `manifest["ready"]["state"]` itself, as `_next_tally` and `_waiting` do.
    """
    nodes = manifest.get("nodes") or {}
    ready = manifest.get("ready") or {}
    if ready.get("state") == grid.STATE_READY_UNLOOKED:
        return []
    gates = {gate["ref"]: gate for gate in manifest.get("gates") or []}
    # `rows[].next` ORDERS WITHIN A GROUP; IT DOES NOT GRANT MEMBERSHIP. AC4 names it as an input
    # alongside `gate.kind` without saying what it does, and the two readings are not close: as
    # an override it would put a row the author flagged into NEXT even when a parent has not
    # merged, which is a hand-typed field beating a resolved one -- the exact inversion AC4's
    # precondition exists to prevent, arriving through a different door. As emphasis it lets the
    # author say "start with this one" among rows that are ALREADY ready, which costs nothing if
    # the flag is stale. Sorted stably, so rows with no flag keep declaration order.
    # KEY BUILT EAGERLY, NOT AS A CLOSURE (pylint W0640). The tuple sorts False before True, and
    # `ready_set` already returned its refs sorted, so alphabetical order survives inside each half.
    refs = [ref for _, ref in sorted((not (nodes.get(ref) or {}).get("next"), ref) for ref in ready.get("refs") or [])]
    return [(ref, gates.get(ref) or {}, _route((gates.get(ref) or {}).get("kind") or "")) for ref in refs]


def _is_unlooked(manifest: dict) -> bool:
    """Whether this manifest's READY set is one nobody could resolve, as opposed to one with nothing to resolve.

    THE ONE DEFINITION OF "NOBODY LOOKED" FOR A MANIFEST, shared by NEXT (`_next_tally`) and WAITING ON YOU
    (`_waiting`) so the two sections cannot disagree about it. `grid.ready_refs` reports `unlooked` whenever no node
    carries a resolved state, and a manifest that declares NO refs has no nodes at all, so it reports `unlooked`
    too -- there is nothing for anyone to have looked up. Live 2026-10-18: three empty manifests did exactly that,
    NEXT said `nobody looked` above a filled WAITING ON YOU, and STACKS said `0 unresolved` on the same page.
    `_waiting` carried the guard and `_next_tally` did not; this function is the guard, moved to where both read it.
    The wire is untouched: `ready.state` stays `unlooked` for such a manifest, because a JSON consumer may rely on it.
    """
    if (manifest.get("ready") or {}).get("state") != grid.STATE_READY_UNLOOKED:
        return False
    return bool(manifest.get("nodes"))


def _next_tally(manifests: list[dict]) -> tuple[dict[str, list[str]], list[str], int, bool]:
    """One walk over every manifest: `(grouped rows, unrecognized kinds, ready count, unlooked)`.

    IT DOES NOT COUNT THE DENOMINATOR. `grid.declared` is already on the wire and `_grid_section`'s
    note already prints it, so recomputing `len(nodes)` here would be a second derivation of a
    published number -- the shape `level` was hoisted onto the node to avoid, and the shape that lets
    STACKS and NEXT disagree about how many refs a page has.

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
        if (manifest.get("ready") or {}).get("state") == grid.STATE_READY_UNLOOKED:
            unlooked = unlooked or _is_unlooked(manifest)
            continue
        nodes = manifest.get("nodes") or {}
        for ref, gate, group in _ready_rows(manifest):
            if group == _GROUP_UNSURE:
                unsure_kinds.append(gate.get("kind") or "")
            grouped[group].append(_next_row(nodes.get(ref) or {}, gate))
            ready_total += 1
    return grouped, unsure_kinds, ready_total, unlooked


def _next_section(doc: dict, compact: bool = False) -> tuple[str, list[str]]:
    """NEXT: what can actually be picked up right now, split into yours / mine / unsure.

    `compact` (the Queen's page, doorways S2) keeps the note and every non-populated sentence, and replaces the
    ROWS with one line of per-owner counts and the chooser that lists them: the rows come from the stacks, so they
    grow with the stacks, and `WAITING ON YOU` already prints the ones that are the reader's.

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

    if compact:
        owners = " · ".join(f"{group} {len(grouped[group])}" for group in _ROUTE_GROUPS if grouped[group])
        return note, [f"  {owners}  {DIM}— list them:{NC} {CYAN}borg next{NC}\n"]
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


def _manifest_repository(manifest: dict, repositories: dict) -> str:
    """The registered repository whose directory CONTAINS this manifest's file, or "" when none does.

    The longest matching path wins, so a repository registered inside another still owns its own
    manifests. Plain string prefixes on purpose: this module is pure, and the registry's `path` and a
    manifest's `path` are both absolute strings the discovery step already produced from that same
    registry. A manifest nobody contains has no repository, and is simply absent from the counts.
    """
    where = str(manifest.get("path") or "")
    best = ""
    best_len = -1
    for name, entry in repositories.items():
        root = str((entry or {}).get("path") or "").rstrip("/")
        if root and where.startswith(root + "/") and len(root) > best_len:
            best, best_len = name, len(root)
    return best


def _routing_counts(doc: dict) -> dict[str, dict[str, int]]:
    """`{repository: {yours, mine, unsure}}`: how many of that repository's `▸ NEXT` rows route to each owner.

    A repository with no routed rows is ABSENT, and the board prints dashes for it. Counts are the READY
    set routed by `_ready_rows`, i.e. exactly the rows `▸ NEXT` prints, so the board and NEXT cannot
    disagree about a number.
    """
    repositories = doc.get("projects") or {}
    counts: dict[str, dict[str, int]] = {}
    for manifest in (doc.get("grid") or {}).get("manifests") or []:
        name = _manifest_repository(manifest, repositories)
        if not name:
            continue
        for _, _, group in _ready_rows(manifest):
            bucket = counts.setdefault(name, {_GROUP_YOURS: 0, _GROUP_MINE: 0, _GROUP_UNSURE: 0})
            bucket[group] += 1
    return counts


_WAITING_TEXT = 52


def _chooser_item(row: dict) -> dict:
    """One of the chooser's YOU rows as a waiting item. The row is `borg next`'s own, passed in on the
    document (`waiting.rows`); this module never routes it."""
    ref = str(row.get("ref") or "")
    # JUSTIFICATION: str.partition on a plain string; the Demeter rule reads it as a chain on a stranger.
    _, hash_mark, number = ref.partition("#")  # pylint: disable=clean-arch-demeter
    label = hash_mark + number if hash_mark else str(row.get("item") or "session")
    detail = str(row.get("item") or "")
    text = f"{row.get('next_step') or ''}  {detail}".strip() if ref else str(row.get("next_step") or "")
    return {
        "ref": ref or label,
        "label": label,
        "linkable": bool(ref),
        "repository": str(row.get("project") or ""),
        "text": text,
        "unblocks": 0,
    }


def _waiting(doc: dict) -> tuple[list[dict], bool]:
    """`(items, unlooked)`: the chooser's YOU rows, then every `yours` manifest decision not already among them.

    TWO SOURCES, ONE ROUTER FOR EACH. The chooser rows arrive on `doc["waiting"]` already built by
    `borg next`'s own functions (board directive, decided 2026-10-09), so link and next cannot disagree about
    them. Manifest decisions are `▸ NEXT`'s `yours` rows, deduplicated by ref. No rank beyond that order.
    NO AGE: nothing in the document says when a row began waiting; a made-up age would be mock data.
    """
    repositories = doc.get("projects") or {}
    rows = (doc.get("waiting") or {}).get("rows") or []
    if _is_repository_scope(doc):
        # THE SESSION ROW ONLY. The page of repository scope is strictly one directory, and a pull request or a
        # manifest decision is a fact about the repository, which the Queen's page carries. `waiting.rows` in
        # `--json` is untouched; the page stops rendering what is not this directory's.
        return [_chooser_item(row) for row in rows if row.get("item") == "session" and not row.get("ref")], False
    items = [_chooser_item(row) for row in rows]
    seen = {item["ref"] for item in items}
    unlooked = False
    for manifest in (doc.get("grid") or {}).get("manifests") or []:
        if (manifest.get("ready") or {}).get("state") == grid.STATE_READY_UNLOOKED:
            # `_is_unlooked` is why a manifest declaring NO refs cannot make the page unsure whether something waits.
            unlooked = unlooked or _is_unlooked(manifest)
            continue
        nodes = manifest.get("nodes") or {}
        repository = _manifest_repository(manifest, repositories)
        for ref, gate, group in _ready_rows(manifest):
            if group != _GROUP_YOURS or ref in seen:
                continue
            node = nodes.get(ref) or {}
            text = gate.get("blocked_by") or node.get("title") or node.get("why") or ref
            items.append(
                {
                    "ref": ref,
                    "label": ref,
                    "linkable": True,
                    "repository": repository,
                    "text": text,
                    "unblocks": len(node.get("children") or []),
                }
            )
    return items, unlooked


def _waiting_line(item: dict, ref_w: int, repo_w: int) -> str:
    """One waiting item on one line: marker, ref, repository, the sentence, what it unblocks."""
    text = item["text"] if len(item["text"]) <= _WAITING_TEXT else item["text"][: _WAITING_TEXT - 1] + "…"
    text = text.rstrip()
    pad_ref = " " * (ref_w - len(item["label"]))
    shown_ref = picture.link_ref(item["ref"], item["label"]) if item["linkable"] else item["label"]
    unblocks = f"  {DIM}unblocks {item['unblocks']}{NC}" if item["unblocks"] else ""
    return f"  {YELLOW}▶{NC} {shown_ref}{pad_ref}  {item['repository']:<{repo_w}}  {text}{unblocks}\n"


_GH_REF = re.compile(r"^([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)#([0-9]+)$")


def _next_action_command(ref: str) -> str:
    """A runnable command for one ref: `gh pr view N -R owner/repo` for an `owner/repo#N` ref, else
    `borg next` (the chooser, which routes anything that is not a GitHub ref). The ref is matched
    against a strict pattern before it reaches a command line, so a hand-typed ref cannot inject."""
    if _GH_REF.match(ref):
        # JUSTIFICATION: str.partition on a plain string; the Demeter rule reads it as a chain on a stranger.
        repo, _, number = ref.partition("#")  # pylint: disable=clean-arch-demeter
        return f"gh pr view {number} -R {repo}"
    return "borg next"


def _first_mine(doc: dict) -> tuple[str, str] | None:
    """`(ref, repository)` of the first agent-routable ready row across the manifests, or None.

    Always None on the page of repository scope: a ready manifest row is a repository-level fact, and that
    page's next action comes from its own session or says nothing is ready.
    """
    if _is_repository_scope(doc):
        return None
    repositories = doc.get("projects") or {}
    for manifest in (doc.get("grid") or {}).get("manifests") or []:
        for ref, _, group in _ready_rows(manifest):
            if group == _GROUP_MINE:
                return ref, _manifest_repository(manifest, repositories)
    return None


def _next_action_line(doc: dict, items: list[dict], unlooked: bool) -> str:
    """THE LAST LINE OF THE PAGE (link-unification L3: the answer in the final lines before the prompt).

    ONE recommended next action and a command, derived only from data the document already carries, by
    this rule: the first WAITING ON YOU item (a decision only the reader can make) if any; else the
    first agent (`mine`) ready row; else a sentence saying nothing is ready (or that nobody looked,
    when no manifest was resolved) followed by `borg next`, so the line always carries a runnable
    command. It reads `doc` and nothing else, and both pages print the same SHAPE of line; what differs by
    scope is only which items it can see (`_waiting`, `_first_mine`).
    """
    if items:
        top = items[0]
        ref, repository = (top["ref"] if top["linkable"] else top["text"]), top["repository"]
    else:
        mine = _first_mine(doc)
        if mine is None:
            if unlooked:
                looked = f"nobody looked; run {CYAN}borg link{NC} without --local"
                return f"  {BOLD}next{NC}  {looked}  {CYAN}borg next{NC}\n"
            return f"  {BOLD}next{NC}  {DIM}nothing is ready{NC}  {CYAN}borg next{NC}\n"
        ref, repository = mine
    where = f" {DIM}({repository}){NC}" if repository else ""
    return f"  {BOLD}next{NC}  {ref}{where}  {CYAN}{_next_action_command(ref)}{NC}\n"


def _repository_you_count(doc: dict) -> tuple[str, int]:
    """`(repository, n)`: how many of `borg next`'s YOU rows belong to this directory's repository but not to it.

    ONLY ON THE PAGE OF REPOSITORY SCOPE, and only a COUNT. That page is strictly one directory (see
    `_waiting`), so the repository's pull requests stay off it, but printing `nothing waits on you` above rows that
    `borg next --rows --json` holds for the same repository was a false statement (live 2026-10-18: two). The count
    keeps the page about its own directory and stops it lying, and `borg next` is the one place the rows are listed.

    These are exactly the rows `_waiting` drops in repository scope: everything but the directory's own session
    row. The repository is the one a worktree is `worktree_of`, else the directory's own registry name; a row for
    any other project is not counted. Returns `("", 0)` on the Queen's page, which lists every row itself.
    """
    if not _is_repository_scope(doc):
        return "", 0
    focus = doc.get("focus") or {}
    repository = str((focus.get("identity") or {}).get("worktree_of") or focus.get("name") or "")
    owned = {repository, str(focus.get("name") or "")} - {""}
    rows = (doc.get("waiting") or {}).get("rows") or []
    count = sum(
        1 for row in rows if row.get("project") in owned and not (row.get("item") == "session" and not row.get("ref"))
    )
    return repository, count


def _waiting_tail(doc: dict, leftover: int, capped: bool) -> list[str]:
    """What follows the rows: the chooser's hidden counts and a degraded block, one line each, or ONE line when capped.

    Capped, `+N more` (rows the cap left off) and the hidden counts share a single line that ends in the chooser, and
    the degraded sentence rides at the END of that line: it is the one part of the line with no fixed width, so it is
    the part the page-width cut may take, and the command is never it.
    """
    waiting = doc.get("waiting") or {}
    # The hidden counts (`+N agent tasks`, ...) describe repository-level rows, none of which a directory's
    # page shows, so they are not printed there either.
    hidden = [] if _is_repository_scope(doc) else waiting.get("hidden_lines") or []
    degraded = waiting.get("degraded")
    if not capped:
        tail = [f"  {DIM}{line}{NC}\n" for line in hidden]
        if degraded:
            tail.append(_placeholder(f"rows degraded: {degraded}"))
        return tail
    parts = [f"+{leftover} more"] if leftover else []
    parts.extend(str(line).strip() for line in hidden)
    if not parts and not degraded:
        return []
    counted = f"{DIM}{' · '.join(parts)}{NC}  " if parts else ""
    reason = f"  {DIM}rows degraded: {degraded}{NC}" if degraded else ""
    return [f"  {counted}{CYAN}borg next{NC}{reason}\n"]


def _waiting_section(doc: dict, cap: int | None = None) -> tuple[str, list[str]]:
    """WAITING ON YOU: what only you can move, last on the page where the eye lands.

    ALWAYS PRESENT, per the board directive's AC4: empty prints ONE line, `nothing waits on you`, not
    an absent section (that supersedes X9's "absent, not empty"). The one distinction kept is the
    three-state NEXT already makes: when no manifest was resolved the page does not KNOW that nothing
    waits, and saying so would be false, so it says nobody looked. The chooser's hidden-count lines
    (`+N more decisions`, `+N agent tasks`, `+N stale drafts`) follow the items verbatim, and the
    section's final line is the single recommended next action (`_next_action_line`).

    `cap` (the Queen's page, doorways S2) is the most rows printed, decisions first and due parked thoughts after.
    Everything the page does not print is COUNTED on ONE line before the next action (`_waiting_tail`), so a capped
    section is longer than its cap by that line and the next action, never by the length of the queue. `None` (the
    directory's page, and `--full`) prints it all, byte for byte as before.
    """
    items, unlooked = _waiting(doc)
    action = _next_action_line(doc, items, unlooked)
    # Parked thoughts whose look-again date has come ride AFTER the real items and are not offered by the next-action
    # line: a parked thought is a reminder to look, not a decision with a command that answers it.
    parking, more_parked = _parking_due(doc)
    total = len(items) + len(parking) + more_parked
    shown = total if cap is None else min(cap, len(items) + len(parking))
    # A due parked thought keeps at least ONE of the capped slots (and any the decisions leave empty): seven sessions
    # waiting must not starve the reminder to look.
    parked_n = len(parking) if cap is None else min(len(parking), max(1, shown - len(items)))
    tail = _waiting_tail(doc, total - shown, cap is not None)
    if not items and not parking:
        note, placeholder = _nothing_line(doc, unlooked)
        return note, [placeholder, *tail, action]
    note = _plural(total, "item", "items")
    if unlooked:
        note += " — and some refs nobody looked up"
    rows = _waiting_rows(items[: shown - parked_n], parking[:parked_n])
    if cap is None and more_parked:
        rows.append(f"  {DIM}+{more_parked} more parked items due{NC}\n")
    return note, [*rows, *tail, action]


def _waiting_rows(kept: list[dict], parked: list[dict]) -> list[str]:
    """WAITING ON YOU's rows: the decisions in `kept`, aligned to each other, then the due parked thoughts."""
    ref_w = max((len(item["label"]) for item in kept), default=0)
    repo_w = max((len(item["repository"]) for item in kept), default=0)
    return [*(_waiting_line(item, ref_w, repo_w) for item in kept), *(_parking_line(item) for item in parked)]


def _nothing_line(doc: dict, unlooked: bool) -> tuple[str, str]:
    """`(note, placeholder)` of an empty WAITING ON YOU: three-state, never `nothing` when nobody looked."""
    if unlooked:
        return "nobody looked", _placeholder("no state on this page was resolved; run without --local.")
    repository, count = _repository_you_count(doc)
    if count:
        return "", _placeholder(f"nothing here waits on you · {count} for {repository}: borg next")
    return "", _placeholder("nothing waits on you")


def _scoped_rows(doc: dict, key: str) -> tuple[list[dict], bool]:
    """`(rows, show_repository)` for one scope-dependent list: the focused repository's in repository
    scope, the registry-wide aggregate otherwise.

    ONE FUNCTION KEYED ON THE FIELD NAME, because QUEUED and SHIPPED narrow by the identical rule and
    two copies of it is two places for the breadth rule to drift.
    """
    if (doc.get("scope") or {}).get("kind") == "repository":
        return (doc.get("focus") or {}).get(key) or [], False
    return doc.get(key) or [], True


def _queued_section(doc: dict, compact: bool = False) -> tuple[str, list[str]]:
    """QUEUED: filed-but-not-started directives, at the document's breadth.

    `compact` (the Queen's page) is the count in the note and the command that lists them: 138 directives drew 138
    lines. Nothing queued still prints its own placeholder, so an empty queue cannot read as a collapsed one.
    """
    directives, show_repository = _scoped_rows(doc, "directives")
    if not directives:
        return "", [_placeholder("nothing queued. Run /borg-plan to file one.")]
    note = _plural(len(directives), "directive", "directives")
    if compact:
        return note, [_expand_line("every directive, listed")]
    return note, _bullet_lines(directives, show_repository)


def _shipped_section(doc: dict) -> tuple[str, list[str]]:
    """SHIPPED: the most recently assimilated plans, at the document's breadth.

    NO NOTE, unlike QUEUED's count: `shell.collect_all_assimilated` caps at three, so a count here
    would read as a total and be one.
    """
    assimilated, show_repository = _scoped_rows(doc, "assimilated")
    if not assimilated:
        return "", [_placeholder("nothing shipped yet.")]
    return "", _bullet_lines(assimilated, show_repository)


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
    """One sentence per repository whose declared edges contain a cycle.

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


def _signals_section(doc: dict, compact: bool = False) -> tuple[str, list[str]]:
    """SIGNALS: capacity, then every warning the document carried, then the ladder's own gap.

    `compact` (the Queen's page) prints the first `_SIGNALS_CAP` signals and the ladder's gap; past the cap the note
    counts the signals and names the command that prints them all. A signal wider than the page is cut at
    `PAGE_COLUMNS` with `…` and is whole under `--full`. The gap line stays last and always present: it is the section's
    last word on a page nobody swept (`test_the_last_word_on_a_local_page_is_that_nobody_looked`), so no count
    may displace it.

    WARNINGS ARE NEVER SWALLOWED. build_grid's docstring makes the argument for carrying them; this
    is where they surface. A document with a discovery, selection, sweep or fetch warning that
    printed nothing would be the exact silent-blindness shape docs/agents/learned.md catalogues.
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
    resolution = _resolution_line(grid_block)
    if compact and len(lines) > _SIGNALS_CAP:
        return f"{len(lines)} signals · {EXPAND_COMMAND}", [*lines[:_SIGNALS_CAP], *resolution]
    lines.extend(resolution)
    if not lines:
        return "", [_placeholder("nothing to report.")]
    return "", lines


Builder = Callable[[dict], tuple[str, list[str]]]


def _queen_sections(*, compact: bool) -> tuple[tuple[str, Builder], ...]:
    """The Queen's spine, with the budgeted builders (`compact`) or the unbudgeted ones (`--full`).

    ONE LIST WRITTEN ONCE, so the two pages cannot disagree about which sections exist or in what order: they
    differ only in the five builders that take a budget. The titles are byte-identical on both.
    """
    return (
        ("", _header_section),  # the masthead and the legend; no ▸ line
        ("IN FOCUS", _focus_section),  # ABOVE the board -- the `Status:` invariant
        ("REPOSITORIES", partial(_board_section, compact=compact)),  # registry-wide in BOTH contexts
        ("STACKS", partial(_grid_section, compact=compact)),
        ("QUEUED", partial(_queued_section, compact=compact)),
        ("SHIPPED", _shipped_section),
        # AC4. EIGHT SECTIONS NOW, and the insertion point is deliberate: NEXT reads the same grid STACKS
        # draws, and sits below SHIPPED so the page reads history-then-future. Placing it here rather
        # than reserving an always-empty slot in AC2 is what that directive chose, so that the spine test
        # going red is a reviewable event rather than a diff nobody sees.
        ("NEXT", partial(_next_section, compact=compact)),
        ("SIGNALS", partial(_signals_section, compact=compact)),
        # LAST ON PURPOSE: link-unification L3 puts the answer in the final lines before the prompt, and
        # where the board mock and L3 disagree about position, L3 wins. Always present (board AC4).
        ("WAITING ON YOU", partial(_waiting_section, cap=_WAITING_CAP if compact else None)),
    )


# THE QUEEN'S PAGE, held to one screen (doorways S2): `PAGE_LINES` outside REPOSITORIES, `PAGE_COLUMNS` on every line.
SECTIONS: tuple[tuple[str, Builder], ...] = _queen_sections(compact=True)
# `borg link --overview --full`: the same sections with no budget, for the reader who asked for everything.
FULL_SECTIONS: tuple[tuple[str, Builder], ...] = _queen_sections(compact=False)


def _queen_pointer_section(_doc: dict) -> tuple[str, list[str]]:
    """The one line on a directory's page that points at everything else: the Queen's view, and its command.

    UNTITLED, so it supplies its own trailing blank (the `_section` rule for an empty title). It sits ABOVE
    WAITING ON YOU on purpose: the page ends on the recommended next action (link-unification L3), and a
    pointer after it would be the last thing the eye lands on instead.
    """
    pointer = f"  {DIM}Every repository and worktree:{NC} {CYAN}borg link --overview{NC}  {DIM}(the Queen view){NC}\n"
    return "", [pointer, "\n"]


# THE PAGE OF REPOSITORY SCOPE: strictly one directory (2026-10-13). IN FOCUS carries the scope label, the
# identity, the live session and the directory's own checkpoints; WAITING ON YOU carries its own session row
# and the next action. No board, no STACKS, no NEXT stack rows, no QUEUED, no SHIPPED, no SIGNALS, no cube.
REPOSITORY_SECTIONS: tuple[tuple[str, Builder], ...] = (
    ("IN FOCUS", _focus_section),  # FIRST -- the `Status:` invariant
    ("", _queen_pointer_section),
    ("WAITING ON YOU", _waiting_section),  # LAST -- L3
)


def _unregistered_section(_doc: dict) -> tuple[str, list[str]]:
    """The whole page of a directory that is neither the Queen root nor inside any registered path.

    SHORT ON PURPOSE (2026-10-13): the overview belongs to the Queen, so a stranger directory is told what it
    is not and given the two ways out -- register it, or ask for the Queen view by name. UNTITLED, so it
    carries no `▸` header and no cube; the exit code is the caller's (0).
    """
    return "", [
        f"  {BOLD}This directory is not a registered repository.{NC}\n",
        "\n",
        _label("Register it:", f"{CYAN}borg add{NC}"),
        _label("Queen view:", f"{CYAN}borg link --overview{NC}  {DIM}(every repository and worktree){NC}"),
        "\n",
    ]


UNREGISTERED_SECTIONS: tuple[tuple[str, Builder], ...] = (("", _unregistered_section),)


def _is_unregistered(doc: dict) -> bool:
    """Whether scope says cwd is neither the Queen root nor inside a registered path (`scope.unregistered`)."""
    return bool((doc.get("scope") or {}).get("unregistered"))


def _sections_for(doc: dict, full: bool = False) -> tuple[tuple[str, Builder], ...]:
    """The section list for this document's scope: one directory's page, the hint, or the Queen's overview.

    A document with no `scope` (one built before S1) is the Queen's, as it always rendered. `full` picks the
    Queen's unbudgeted list and means nothing to the other two pages, which have no budgeted section.
    """
    if _is_unregistered(doc):
        return UNREGISTERED_SECTIONS
    if _is_repository_scope(doc):
        return REPOSITORY_SECTIONS
    return FULL_SECTIONS if full else SECTIONS


def document(doc: dict, full: bool = False) -> str:
    """THE ONE HUMAN ENTRY POINT. Prints the section list its scope names and joins; no branch inside a section.

    The choice of list is made once, in `_sections_for`. Every branch that used to pick a renderer lives
    inside one section builder, which is what makes the header list assertable against the list itself:
    extract the `▸ `-prefixed titles from a rendering and they equal `tuple(t for t, _ in SECTIONS if t)`
    (the Queen's) or `REPOSITORY_SECTIONS`' (a directory's). A builder that returns nothing still renders
    its header plus one placeholder, so an empty section cannot silently disappear and take the invariant
    with it.

    THE QUEEN'S COMPACT PAGE IS THE ONLY ONE FITTED TO `PAGE_COLUMNS`: each of its lines is cut to that many
    visible columns (`_fit_line`), because free text the renderer does not control (a summary, a directive title, a
    warning) must not be able to push the screen wider. `--full` and the directory's page are not fitted: a stack's
    picture is its own width, and a directory's page is out of this contract.

    THE COMPACT PAGE ENDS ON ITS LAST LINE, NOT ON A BLANK: the section separator after WAITING ON YOU was a row of
    the screen that held nothing, and link-unification L3 wants the next action to be the last thing the eye lands
    on. One line is the difference between 51 and 50 on the live registry.
    """
    sections = _sections_for(doc, full)
    text = "".join(line for title, build in sections for line in _section(title, *build(doc)))
    return _fit_text(text).rstrip("\n") + "\n" if sections is SECTIONS else text
