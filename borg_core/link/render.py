"""The one human renderer for `borg link`, plus the machine TSV `--porcelain` still serializes.

TWO PUBLIC CALLABLES, AND THAT IS THE WHOLE OF AC2's "one front door". `document(doc)` is the single
human entry point: a fixed SEVEN-SECTION SPINE whose `▸` headers are byte-identical in every context,
where `scope` narrows the ROW SET of the four scope-dependent sections and never the board, never the
section list and never the order. `porcelain(doc)` is UNCHANGED byte for byte and is deliberately
outside "everywhere" -- it is not a renderer, it is the TSV feeding fzf's input list
(borg.zsh:262 builds the picker input with `cmd_ls --porcelain`, borg.zsh:264-269 consumes it with
`--delimiter '\\t' --with-nth 1,3,5`), and box drawing in that stream breaks `borg switch` outright.

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

from __future__ import annotations

from typing import Callable

from borg_core.link import core, grid, picture
from borg_core.link.picture import BOLD, CYAN, DIM, GREEN, NC, YELLOW

# Overview column widths, hoisted so the header line and every row format string share ONE source
# of truth and cannot drift apart (borg.zsh:329, :371-372).
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
    """`--porcelain`: one TSV row per visible project, no color, no padding, no header.

    Empty or fully-filtered -> "" -- absolutely nothing, not even a trailing newline (pinned by
    cli_contract.bats's "link --porcelain prints nothing at all on an empty registry").

    UNCHANGED BY AC2, DELIBERATELY, and `tests/fixtures/link/link-porcelain.golden` must not move.
    See the module docstring: this is fzf's input list, not a page.
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
    STRICTLY greater than 50 (an exactly-50-char summary gets none)."""
    cut = summary[:50]
    return f"{cut}..." if len(summary) > 50 else cut


def _overview_row(name: str, entry: dict, cortex_by_project: dict[str, str], mark: str = "") -> str:
    """One board row, plus its cortex pause continuation when the project has a pending wake.

    `mark` IS APPENDED INSIDE THE ROW'S OWN f-STRING and defaults to "", which keeps every byte of
    this function identical for a caller that does not pass one. It exists so the scoped `◀` lands on
    the ROW and never on the countdown continuation, without the caller having to split the returned
    string back apart to find the boundary.
    """
    source = str(core.jq_default(entry.get("source"), "cli"))
    # UNREACHABLE in practice: core.with_state already defaults a missing status to "idle"
    # (DEFAULT_STATUS, mirroring lib/registry.zsh:203) -- which is why the porcelain golden's
    # `golf` row renders "idle" rather than the absent-status fallback. Reproduced anyway for
    # parity with the jq.
    status = str(core.jq_default(entry.get("status"), _JQ_ABSENT_STATUS))
    last_activity = str(core.jq_default(entry.get("relative_activity"), ""))
    summary_short = _overview_summary_cut(str(core.jq_default(entry.get("summary"), "(no summary)")))
    display = entry.get("display_name") or name
    pin_mark = "*" if entry.get("pinned") is True else " "
    status_display = "waiting <<<" if status == "waiting" else status

    line = (
        f"{pin_mark}{display:<{_COL_PROJECT}} {_src_badge(source):<{_COL_SRC}} "
        f"{_status_color(status)}{status_display:<{_COL_STATUS}}{NC} "
        f"{last_activity:<{_COL_LAST_ACTIVE}} {summary_short}{mark}\n"
    )
    countdown = cortex_by_project.get(name)
    if countdown:
        line += f"                       {CYAN}⏸ resumes in {countdown}{NC}\n"
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
            out.append(f"  {CYAN}Objective:{NC} {objective}\n")
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
    Three consumers read it precisely for a cross-project list: skills/borg-switch/SKILL.md's
    `borg link --local --all` (run from a project session's cwd), borg.zsh:2225's 5s `borg watch`
    redraw, and the fzf preview's own orientation. Narrowing it to the scoped repository would turn
    all three into a one-row table. `--all` remains the only control over which rows appear; the
    scoped row is MARKED, with a trailing `◀`, rather than made the only row.
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

    lines = [
        f"{BOLD} {'PROJECT':<{_COL_PROJECT}} {'SRC':<{_COL_SRC}} {'STATUS':<{_COL_STATUS}} "
        f"{'LAST ACTIVE':<{_COL_LAST_ACTIVE}} SUMMARY{NC}\n",
        ("─" * 90) + "\n",
    ]
    countdowns = _cortex_countdowns(doc)
    scoped = _scoped_name(doc)
    for name in order:
        mark = f" {CYAN}◀{NC}" if name == scoped else ""
        lines.append(_overview_row(name, projects[name], countdowns, mark))
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
    unresolved · swept <mark>` is the honest reading of a repository with nothing declared, and it is
    what separates that from a repository nobody swept.
    """
    grid_block = doc.get("grid") or {}
    manifests = grid_block.get("manifests") or []
    since = str(grid_block.get("since") or "")
    freshness = f"swept {since}" if grid_block.get("swept") and since else "not swept"
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
_GROUP_HEADINGS = {
    _GROUP_YOURS: "a decision only you can make",
    _GROUP_MINE: "nothing is blocking these",
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

    `unsure` IS UNREACHABLE THROUGH THE FRONT DOOR TODAY, AND THAT IS A VALIDATOR FACT, NOT A
    RENDERER ONE. `manifest_core.GATE_KINDS` is `{"decision", "verification"}` and validation rejects
    anything else with `gate.kind must be one of [...]`, whereupon `shell._load_manifest` drops the
    WHOLE FILE -- so a manifest carrying `kind: "review"` never reaches this function at all. Measured
    by trying it: adding such a row to `auth-hardening.json` took the orchestrator grid from 12
    declared refs to 5 and produced an `invalid manifest` warning instead of a routed row.

    Kept anyway, dead-but-tested, on the same terms `GLYPH_DRAFT` was kept through AC2 and AC3: the
    branch is one line, its unit tests are real, and the alternative is that the day someone widens
    `GATE_KINDS` -- or the day a row-level degrade replaces the whole-file drop -- the router silently
    defaults a kind it does not understand to one of the two real sides. That is the failure this
    group exists to prevent, and it would arrive with nothing mis-set.

    THE OPEN QUESTION THIS RAISES IS NOT MINE TO CLOSE: a typo'd `kind` currently costs the entire
    manifest, which is a far worse outcome than routing one row to `unsure`. Whether the validator
    should degrade the ROW instead of dropping the FILE is filed, not decided here.
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
        refs = sorted(ready.get("refs") or [], key=lambda ref: not (nodes.get(ref) or {}).get("next"))
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
    header over nothing. Zero manifests in existence declare an unrecognized kind today.
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
