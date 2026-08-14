"""Pure renderers for the three human `borg link` shapes: porcelain, overview, deep.

Ports _borg_link_porcelain (borg.zsh:245-275), _borg_link_overview (borg.zsh:277-413) and
_borg_link_deep (borg.zsh:415-508), byte for byte, transcribed statement by statement and validated
against the four goldens under tests/fixtures/link/. The goldens are the oracle -- not this
docstring, not the spec that produced this file.

UNCONDITIONALLY PURE, matching core.py's contract: no clock, no os.environ, no subprocess, no
filesystem. Every function here takes the already-assembled `--json` document (cli.py._document())
and returns ONE complete string, trailing newlines included. `generated_at`, every
`relative_activity` and every cortex `countdown` already come from ONE shell.now_epoch() call
threaded through cli._document; a second clock read here would reintroduce the straddle the port
removed.

Every default goes through core.jq_default -- a bare `or` is a review-blocking defect (see
jq_default's docstring for why: jq's `//` does not treat "" or 0 as absent).

NON-REPRODUCED DEVIATION, no test impact (record in the PR body): zsh's `echo` builtin expands
backslash escapes by default (`echo -e` is even more explicit about it), so every deep-dive line and
every Directives/Assimilated/cube line currently interpolates data THROUGH escape expansion -- a
directive title or summary containing a literal `\\n` or `\\t` is EXPANDED today. The overview table
rows go through `printf %s` and are NOT expanded. Python's `print()` expands neither. No golden
covers this; it is not reproduced here.

LOCALE COLLATION NOTE, matching core.sort_assimilated's docstring: any per-project or aggregate
directive listing here inherits shell._markdown_files' codepoint-order glob, not zsh's/coreutils'
locale-collated order. Measured zero-impact across every real filename this repo has seen; recorded
so it does not surprise anyone later.
"""

from __future__ import annotations

from borg_core.link import core

GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
RED = "\033[0;31m"
CYAN = "\033[0;36m"
BOLD = "\033[1m"
DIM = "\033[2m"
NC = "\033[0m"

# ANSI is emitted UNCONDITIONALLY -- there is no isatty check anywhere in the link path (borg.zsh
# never added one) and adding one here would fail all four goldens. Do not "fix" this.

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


def _label(text: str, value: str, col: int = _DEEP_LABEL_COL) -> str:
    """One `  {DIM}<label>{NC}<pad>value` deep-dive header line, padding computed as col - len(text)
    rather than six separately hand-counted space literals (borg.zsh:440-445)."""
    pad = " " * max(col - len(text), 1)
    return f"  {DIM}{text}{NC}{pad}{value}\n"


def _fold_s(text: str, width: int = 70) -> list[str]:
    """Reproduce `fold -s -w <width>`'s break points: break AFTER the last space at or before
    `width` (the space stays on the emitted line); hard-break at exactly `width` when the window
    contains no space at all.

    Pinned by cli_contract.bats:2048-2053: every continuation line must match `^  [^ ]` -- a
    continuation must never begin with a space. If a real divergence against GNU or BSD `fold` is
    found, ESCALATE rather than picking silently; there is no portable oracle for `fold -s`.
    """
    lines: list[str] = []
    remaining = text
    while len(remaining) > width:
        window = remaining[: width + 1]
        break_at = window.rfind(" ")
        if break_at == -1:
            lines.append(remaining[:width])
            remaining = remaining[width:]
        else:
            lines.append(remaining[:break_at])
            remaining = remaining[break_at + 1 :]
    lines.append(remaining)
    return lines


def _summary_block(summary: str) -> str:
    """The deep dive's unconditional Summary block (borg.zsh:447-448):
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

    Empty or fully-filtered -> "" -- absolutely nothing, not even a trailing newline (pinned at
    cli_contract.bats:1726).
    """
    order = doc.get("order") or []
    projects = doc.get("projects") or {}
    rows = []
    for name in order:
        entry = projects[name]
        source = core.jq_default(entry.get("source"), "cli")
        status = core.jq_default(entry.get("status"), "unknown")
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
    """The overview's 50-char cut WITH a literal `...` appended only when the ORIGINAL length is
    STRICTLY greater than 50 (an exactly-50-char summary gets none)."""
    cut = summary[:50]
    return f"{cut}..." if len(summary) > 50 else cut


def _overview_row(name: str, entry: dict, cortex_by_project: dict[str, str]) -> str:
    source = str(core.jq_default(entry.get("source"), "cli"))
    # UNREACHABLE in practice: core.with_state already defaults a missing status to "idle"
    # (DEFAULT_STATUS, mirroring lib/registry.zsh:203) -- which is why the porcelain golden's
    # `golf` row renders "idle" rather than "unknown". Reproduced anyway for parity with the jq.
    status = str(core.jq_default(entry.get("status"), "unknown"))
    last_activity = str(core.jq_default(entry.get("relative_activity"), ""))
    summary_short = _overview_summary_cut(str(core.jq_default(entry.get("summary"), "(no summary)")))
    display = entry.get("display_name") or name
    pin_mark = "*" if entry.get("pinned") is True else " "
    status_display = "waiting <<<" if status == "waiting" else status

    line = (
        f"{pin_mark}{display:<{_COL_PROJECT}} {_src_badge(source):<{_COL_SRC}} "
        f"{_status_color(status)}{status_display:<{_COL_STATUS}}{NC} "
        f"{last_activity:<{_COL_LAST_ACTIVE}} {summary_short}\n"
    )
    countdown = cortex_by_project.get(name)
    if countdown:
        line += f"                       {CYAN}⏸ resumes in {countdown}{NC}\n"
    return line


def _cube_lines() -> list[str]:
    """The cube art, verbatim (borg.zsh:319-328)."""
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


def _overview_directives_block(directives: list[dict]) -> list[str]:
    if not directives:
        return []
    out = ["\n", f"  {CYAN}Directives:{NC} {len(directives)} pending\n"]
    out.extend(f"    {DIM}- [{item['project']}] {item['title']}{NC}\n" for item in directives)
    return out


def _overview_assimilated_block(assimilated: list[dict]) -> list[str]:
    if not assimilated:
        return []
    out = ["\n", f"  {GREEN}Recently assimilated:{NC}\n"]
    out.extend(f"    {DIM}- [{item['project']}] {item['title']} ({item['ship_date']}){NC}\n" for item in assimilated)
    return out


def _overview_capacity_block(capacity: dict) -> list[str]:
    if not capacity.get("over_limit"):
        return []
    return [
        "\n",
        f"{YELLOW}▸{NC} {BOLD}{capacity['active']} sessions need attention{NC} (limit: {capacity['limit']})\n",
    ]


def overview(doc: dict) -> str:
    """The default `borg link` overview: the discovery tip, the cube, the table, both aggregate
    sections, and the capacity warning -- in the exact branch order of borg.zsh:286-413.
    """
    total_projects = doc.get("total_projects", 0)
    order = doc.get("order") or []
    projects = doc.get("projects") or {}

    # BRANCH 1 -- gated on the UNFILTERED count, NOT len(order). See core.assemble's docstring: an
    # empty registry and an all-archived one both emit order=[]/projects={}, but must print two
    # different sentences.
    if total_projects == 0:
        return f"{GREEN}▸{NC} No projects registered. Run: borg scan\n"

    out = []
    # BRANCH 2 -- the discovery tip, NOT mutually exclusive with branch 4 (a lone archived project
    # can print both the tip and the all-filtered sentence).
    if total_projects <= 1:
        out.append(f"  {DIM}Tip: run 'borg scan' to discover projects from session history{NC}\n")

    # BRANCH 3 -- the cube.
    out.extend(_cube_lines())

    # BRANCH 4 -- nothing survived the archived filter.
    if not order:
        out.append(f"{GREEN}▸{NC} No projects to show. Run: borg link --all\n")
        return "".join(out)

    # BRANCH 5 -- header + rule + rows.
    out.append(
        f"{BOLD} {'PROJECT':<{_COL_PROJECT}} {'SRC':<{_COL_SRC}} {'STATUS':<{_COL_STATUS}} "
        f"{'LAST ACTIVE':<{_COL_LAST_ACTIVE}} SUMMARY{NC}\n"
    )
    out.append(("─" * 90) + "\n")

    cortex_by_project: dict[str, str] = {}
    for pending in doc.get("cortex_pending") or []:
        project = pending.get("project")
        if project not in cortex_by_project:
            cortex_by_project[project] = pending.get("countdown", "")

    for name in order:
        out.append(_overview_row(name, projects[name], cortex_by_project))

    # BRANCH 6 -- directives. BRANCH 7 -- recently assimilated (aggregate).
    out.extend(_overview_directives_block(doc.get("directives") or []))
    out.extend(_overview_assimilated_block(doc.get("assimilated") or []))

    # BRANCH 8 -- capacity warning, strict >, already computed in core.capacity.
    out.extend(_overview_capacity_block(doc.get("capacity") or {}))

    # BRANCH 9 -- trailing bare newline; overview and deep both end "<last content line>\n\n".
    out.append("\n")
    return "".join(out)


# JUSTIFICATION: transcribes borg.zsh:415-508 statement by statement for one golden-diffable function.
def deep(doc: dict) -> str:  # pylint: disable=too-many-branches,too-many-locals
    """The single-project deep dive, mirroring borg.zsh:415-508."""
    focus = doc.get("focus") or {}
    name = focus.get("name", "")
    entry = focus.get("entry") or {}

    source = core.jq_default(entry.get("source"), "cli")
    path = core.jq_default(entry.get("path"), "null")
    status = core.jq_default(entry.get("status"), "unknown")
    last_activity = core.jq_default(entry.get("last_activity"), "(never)")
    summary = str(core.jq_default(entry.get("summary"), "(no summary)"))
    session_id = core.jq_default(entry.get("claude_session_id"), "(unknown)")
    tmux_window = core.jq_default(entry.get("tmux_window"), "(none)")

    out = [f"\n{BOLD}{name}{NC}\n"]
    out.append(("─" * 40) + "\n")
    out.append(_label("Source:", str(source)))
    # `Path:` is the ONLY conditional header line -- omitted entirely, not blanked, when path is
    # the sentinel string "null".
    if path != "null":
        out.append(_label("Path:", str(path)))
    # Exactly ONE line contains "Status:" and it ends in the status word: drone.zsh:964-965 greps
    # this line and blanks its column silently otherwise (pinned at cli_contract.bats:2210-2219).
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

    directives = focus.get("directives") or []
    if directives:
        out.append("\n")
        out.append(f"  {CYAN}Directives:{NC} {len(directives)} pending\n")
        for item in directives:
            out.append(f"    {DIM}- {item['title']}{NC}\n")

    assimilated = focus.get("assimilated") or []
    if assimilated:
        out.append("\n")
        out.append(f"  {GREEN}Recently assimilated:{NC}\n")
        for item in assimilated:
            out.append(f"    {DIM}- {item['title']} ({item['ship_date']}){NC}\n")

    out.append("\n")
    return "".join(out)
