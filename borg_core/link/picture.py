"""The topological PICTURE: one manifest's grid rasterized into box-drawing rows and detail blocks.

AC2's renderer, minus the page. `render.py` owns the seven-section spine and what goes in each
section; this module owns the geometry -- which column a node sits in, which box character joins two
levels, how a ref becomes a clickable cell, and how wide any of it is. Splitting it that way is what
keeps the column algorithm testable against a hand-authored oracle that predates the page: the two
`.expected` fixtures under tests/fixtures/link/ are diffed by pytest with no CLI, no registry and no
document involved.

PURE, on the same terms as core.py and grid.py, and enforced the same way -- `"picture.py"` is named
in pyproject's `[tool.clean-arch.module_map] Domain` list. No os, no subprocess, no open(), no clock,
no environment, no isatty. That last one is not pedantry: `borg link` has emitted ANSI
unconditionally since it was zsh (render.py's own header records that there is no isatty check
anywhere in the link path), and a terminal-width probe is the single most tempting impurity in a file
whose whole subject is width. The width budget here is a CONSTANT, checked against fixtures, and
PICTURE_BUDGET's docstring says what that does and does not buy.

THE TOKEN `unknown` DOES NOT APPEAR IN THIS FILE, and that is a rule with teeth rather than a style
note. AC3 landed before AC2 precisely so the renderer could be written against an already-truthful
document. Where the grid's unresolved token has to be compared, `grid.STATE_SOURCE_UNKNOWN` is
imported -- so the two modules cannot drift, which a duplicated string literal would allow, and so a
grep for the literal stays a meaningful check. `state_glyph` has no `unknown` branch at all: it has
three named-state branches and a DEFAULT arm, which `unknown` takes alongside an injected Jira
adapter's `in_progress` and the live viz manifest's `stacked`. `resolve_state` takes a swept token
verbatim without checking DECLARABLE_STATES (grid.py's resolve_state docstring carries the argument),
so foreign tokens are a live path here, not a hypothetical.

CORRECTED AGAINST THE APPROVED MOCK, AND THE CORRECTION IS THE REASON `picture-fork.expected` IS
HAND-AUTHORED. The AC2 spec states the rail rule as `up(k) = 1 iff some JOGGING segment has
from_col == k` and `down(k) = 1 iff some JOGGING segment has to_col == k`, and then states that it
verified column 0 of the mock's fan-out as `up=1, down=1, right=1 -> "|-"`. Those two cannot both be
true: at the fan-out, column 0's DOWNWARD stroke belongs to the STRAIGHT segment n1->n2, which the
jogging-only rule cannot see. Executed as written, the rule renders the mock's fan-out as `└┬┐` and
its join as `└┬┘`; the mock says `├┬┐` and `└┼┘`. Both strokes are counted over EVERY segment
crossing the boundary here, which reproduces the mock byte for byte. The `.expected` fixtures are
transcribed from the mock BY HAND and are never writable by BORG_UPDATE_GOLDEN, so a future
regression cannot re-freeze a wrong rule as its own oracle.
"""

from __future__ import annotations

import re

from borg_core.link import grid
from borg_core.manifest import core as manifest_core

# ANSI, duplicated from render.py for exactly one step. AC2/S3 makes render.py import these names
# from here and deletes its own copy; until then nothing imports this module, and a `from
# borg_core.link import render` here would be the import cycle S3 exists to avoid (render calls
# picture, never the reverse). Recorded rather than left to be discovered as drift.
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
RED = "\033[0;31m"
CYAN = "\033[0;36m"
BOLD = "\033[1m"
DIM = "\033[2m"
NC = "\033[0m"

# The ratified glyph set (2026-08-21 review outcome): the mock's `✔ ● ○ ◌` everywhere, the
# prototype's ASCII `X O o` retired.
#
# `✗` IS A NAMED ADDITION to that set, not an oversight in it. The github adapter emits three tokens
# (grid.DECLARABLE_STATES) and the ratified four cover two of them, so without `✗` an abandoned PR
# renders identically to a merged one -- a wrong answer on the command whose whole purpose is derived
# fact. Truthfulness beats glyph-set purity.
#
# `●` AND `◌` SHIP DEAD IN AC2, DELIBERATELY. `●` needs readiness (open AND every parent merged) and
# `◌` needs draft-ness; grid.py emits neither, because `ready` is AC4's routing signal and `isDraft`
# is not yet on the wire. Both branches are covered by their own pytest cases with the fields
# present, so the coverage floor holds and AC4 flips DATA rather than CODE -- it emits `ready: true`
# and the `●` branch lights up with no renderer edit and no second golden regeneration.
GLYPH_MERGED = "✔"
GLYPH_READY = "●"
GLYPH_OPEN = "○"
GLYPH_DRAFT = "◌"
GLYPH_CLOSED = "✗"

# The second character of every cell. A space normally; `!` when a node merged ahead of a parent that
# has not. Required by the 2026-08-21 review ("a node merged before its declared parent renders a
# distinct marker + one drift line, so the picture never silently contradicts itself"), and the live
# case that prompted it was the contract lane's C6 sitting open under merged rows.
DRIFT_MARK = "!"
# AC4 PRECONDITION. Shares DRIFT_MARK's slot -- see `cell_mark` for which wins when both apply.
PROVENANCE_MARK = "?"

INDENT = 4
GUTTER = 2
# FIXED AT 4, not sized to the widest id, so a manifest growing from 9 to 10 nodes cannot reflow every
# column in the picture. The mock's own later render reaches n17 (chains.md), and `n999 ` still fits.
ID_WIDTH = 4

# The widest a picture row may be, in VISIBLE columns. 68 rather than 80 came from the fzf preview
# pane: AC2/S3 sized it at 70, leaving two columns of slack for the pane's own border. THAT PANE IS
# GONE -- `borg switch`'s preview was retired on 2026-08-27 (zero typed invocations in six months),
# and `grep -c -- '--preview-window' borg.zsh` is 0, which cli_contract.bats' B15 asserts. The number
# stays 68 on its own merits: it is the bound every manifest that exists is measured against, and
# raising it is an explicit non-goal of the width-check directive. A future consumer with a real
# width constraint should be checked against ITS number, not have this one bent toward it.
#
# WHAT THIS BUYS AND WHAT IT DOES NOT. It is a CONSTANT, not a terminal probe -- this module is pure,
# so it cannot measure the terminal, and AC2's non-goal list keeps it that way. What it now HAS is a
# runtime measurement to be compared against: `max_row_width` below computes the widest row of
# whatever a caller holds, `link/cli.py` stamps it on the wire as `grid.picture_width`, and
# `render._width_line` says so on the page. So "a future manifest exceeds it and nothing notices" --
# the honest boundary AC2 recorded here -- is no longer true.
PICTURE_BUDGET = 68

# (up, right, down, left) -> the box character with exactly those four strokes. A LOOKUP, never a
# per-case branch: eleven if/elif arms is where a `┤` gets written for a `├` and no test notices,
# because both are "a T-junction" to a reader skimming the diff. The four keys with a single stroke
# and the all-zero key are deliberately ABSENT -- a rail cell with fewer than two strokes is a
# geometry bug upstream, and KeyError is the correct, loud answer to it.
_BOX = {
    (1, 0, 1, 0): "│",
    (0, 1, 0, 1): "─",
    (1, 1, 0, 0): "└",
    (1, 0, 0, 1): "┘",
    (0, 1, 1, 0): "┌",
    (0, 0, 1, 1): "┐",
    (1, 1, 1, 0): "├",
    (1, 0, 1, 1): "┤",
    (0, 1, 1, 1): "┬",
    (1, 1, 0, 1): "┴",
    (1, 1, 1, 1): "┼",
}

_SGR_RE = re.compile(r"\033\[[0-9;]*m")
# OSC 8 opens with `ESC ] 8 ; params ; URL` and closes with ST (`ESC \`). The payload class excludes
# ESC so a malformed sequence cannot swallow the rest of the line into one match.
_OSC8_RE = re.compile(r"\033\]8;;[^\033]*\033\\")


# ── measurement ───────────────────────────────────────────────────────────────────────────────────


def visible_len(text: str) -> int:
    """The number of columns `text` occupies once SGR and OSC-8 sequences are removed.

    THE PADDING PRIMITIVE, and it exists as a named function so a test can assert it rather than
    infer it from a golden. OSC-8 sequences are zero-width but they are BYTES: an f-string that pads
    with `len(cell)` after wrapping a ref in a hyperlink shifts every column right by the length of a
    URL, and the failure is invisible in a diff because the escape bytes do not print. That is the
    single most likely alignment bug in this module, which is why it gets its own invariant
    (`test_visible_width_is_identical_with_and_without_hyperlinks`) instead of a comment.

    Codepoints, not display cells. Every glyph in the ratified set is single-width, refs are ASCII by
    parse_ref's character class, and the one place a double-width character could enter -- a PR title
    off the wire -- lands in a detail block, which is never column-aligned against anything.
    """
    return len(_OSC8_RE.sub("", _SGR_RE.sub("", text)))


def max_row_width(manifest_grids: list[dict]) -> int:
    """The widest picture row a set of manifests rasterizes to, in VISIBLE columns. 0 for none.

    THE MEASUREMENT `PICTURE_BUDGET` NEVER HAD. The budget above is a constant checked against the
    fixture manifests; this is the same number computed over whatever a caller actually holds, so a
    manifest a user writes tomorrow can be compared against it. It is deliberately not a check:
    raising here would take out the two paths that swallow failure silently, and logging would end the
    purity that makes `picture-fork.expected` and `picture-crossing.expected` meaningful as
    hand-authored oracles. The COMPARISON lives at the impure boundary, `link/cli.py`, which stamps
    the result onto `grid.picture_width` for `--json` and for `render._width_line`.

    LIVES IN THIS MODULE ANYWAY, BESIDE `visible_len`, AND IMPORTS NOTHING NEW. It re-runs the caller
    triple `render._grid_section` runs -- `assign_columns` -> `node_ids` -> `picture` -- because
    measuring a row requires rasterizing it, and a copy of that triple anywhere else is a second
    renderer that can disagree with the first about what a picture is. `visible_len` rather than
    `len`: the rows carry SGR and OSC-8 bytes, so `len` overstates a hyperlinked row by the length of
    a URL and would report every manifest over budget.

    `node_ids` IS GLOBAL ACROSS THE LIST, so the whole list must be passed at once rather than folded
    a manifest at a time -- ids widen the id column, and a per-manifest max would measure a narrower
    picture than the one that renders.

    `default=0` because an empty list, and a manifest with no levels, must both yield 0 rather than
    raise: a repository with nothing declared has a picture zero columns wide, not an error.
    """
    columns_by_manifest = [assign_columns(manifest) for manifest in manifest_grids]
    ids = node_ids(manifest_grids, columns_by_manifest)
    return max(
        (
            visible_len(row)
            for manifest, columns in zip(manifest_grids, columns_by_manifest)
            for row in picture(manifest, ids, columns)
        ),
        default=0,
    )


# ── hyperlinks ────────────────────────────────────────────────────────────────────────────────────


def osc8(url: str, text: str) -> str:
    """`text` as an OSC-8 hyperlink to `url`. Degrades to plain text in a terminal that ignores it.

    TERMINATED WITH ST (`ESC \\`), NEVER BEL. ST is the specified terminator and Ghostty, iTerm2,
    WezTerm and VTE all accept it; BEL is a widely-tolerated alternative that would put a literal
    `0x07` byte into two golden files, where it is invisible in a diff and rings the reviewer's
    terminal on every `cat`.
    """
    return f"\033]8;;{url}\033\\{text}\033]8;;\033\\"


def ref_url(ref: str) -> str:
    """The GitHub URL for a full `owner/repo#num` ref, or "" when it is not one.

    `/issues/<n>` AND NEVER `/pull/<n>`, because GitHub redirects the issues form to the pull form for
    a PR but not the reverse -- so one form is correct for both and the renderer never has to know
    which kind a ref names. The manifest schema allows an apex that IS a tracker issue, so both kinds
    genuinely occur. This is also the house rule for every generated document in this tree.

    BUILT ONLY FROM parse_ref's 3-TUPLE, never by string surgery on the raw ref, and that is the
    injection gate rather than tidiness. An OSC-8 payload is INTERPRETED by the terminal emulator: a
    ref carrying an ESC or a `;` would not merely produce a broken link, it would close the sequence
    early and let the remainder run as terminal control input. parse_ref's character class is the one
    recon-adapter-github validates against before interpolating an owner into a GraphQL document, so
    the same gate that protects the query protects the escape sequence.
    """
    parts = manifest_core.parse_ref(ref)
    return f"https://github.com/{parts[0]}/{parts[1]}/issues/{parts[2]}" if parts else ""


def link_ref(ref: str, text: str) -> str:
    """`text` linked to `ref`'s URL, or `text` unchanged when the ref is not linkable.

    NO FABRICATION AND NO PLACEHOLDER. A ref that parse_ref rejects renders as plain text -- not as a
    guessed URL, not as an error line, not as a `(unlinkable)` marker. A fabricated URL silently
    points at the wrong repository, which is worse than no link at all, and an error line would put a
    manifest defect in the middle of a picture rather than in the warnings the document already
    carries. In practice such a ref cannot reach here (validate rejects it and shell._load_manifest
    drops the whole file), so this arm keeps the function total and is covered directly.
    """
    url = ref_url(ref)
    return osc8(url, text) if url else text


# ── vocabulary ────────────────────────────────────────────────────────────────────────────────────


def state_glyph(node: dict) -> str:
    """One node's glyph. TOTAL over every state token, including ones no adapter here emits.

    THE DEFAULT ARM IS THE POINT. A dict lookup keyed on state would raise KeyError on the live
    viz manifest, whose rows declare `"status": "stacked"` -- a position in a stack, not a PR state --
    and on any injected Jira or Slack adapter's vocabulary, which resolve_state passes through
    verbatim. It would also raise on the grid's own unresolved token, which reaches this function
    several times a second on the hottest paths in the tree (`--local` opts down from both network
    rungs, and the fzf preview re-renders per keypress). A renderer that raised there would take out
    the preview pane and `drone status` at once.

    `is True` RATHER THAN TRUTHINESS on both optional fields, which is the Python-side shape of the
    jq `//` trap CLAUDE.md records: a missing key and a JSON `false` must read identically, and the
    string `"true"` -- what a hand-edited manifest produces -- must NOT light up a glyph that claims
    live evidence.
    """
    state = node.get("state")
    if state == manifest_core.STATE_MERGED:
        return GLYPH_MERGED
    if state == manifest_core.STATE_CLOSED:
        return GLYPH_CLOSED
    if node.get("draft") is True:
        return GLYPH_DRAFT
    if state == manifest_core.STATE_OPEN:
        return GLYPH_READY if node.get("ready") is True else GLYPH_OPEN
    return GLYPH_OPEN


def resolved_provenance(node: dict) -> bool:
    """Did ANYBODY actually look this state up, or is it a hand-typed field?

    THE ONE PREDICATE ALL THREE PROVENANCE SITES READ, so the cell mark, the glyph colour and the
    detail heading cannot disagree about whether a node was verified. Keyed on `grid`'s own
    `RESOLVED_STATE_SOURCES` rather than a local tuple: `swept` and `fetched` were looked up,
    `declared` and `unknown` were not, and if a fifth rung is ever added this follows it.

    `grid.py:898` computes `unresolved` from the SAME tuple, so the `▸ SIGNALS` count and the marks
    in the picture are two views of one fact rather than two derivations that can drift.
    """
    return node.get("state_source") in grid.RESOLVED_STATE_SOURCES


# Colour keyed on the GLYPH rather than on the state, so the two can never disagree about which
# node is which. A lookup for the same reason _BOX is one: a three-arm if/elif chain over
# visually-similar constants is where `GLYPH_CLOSED` gets the merged colour and nothing notices.
_GLYPH_COLOR = {GLYPH_MERGED: GREEN, GLYPH_CLOSED: DIM, GLYPH_DRAFT: DIM}


def glyph_color(node: dict) -> str:
    """The SGR prefix for a node's glyph. Anything still in flight is YELLOW.

    UNRESOLVED PROVENANCE TAKES THE COLOUR DOWN TO DIM, whatever the state says. A hand-typed
    `"status": "merged"` rendered in the same GREEN as a swept one is the AC4 precondition's exact
    complaint, measured on the live `ingle-t1-cutover` manifest: twelve green checkmarks asserting a
    project is essentially done, from a field no sweep and no fetch ever saw.

    THE COLOUR IS THE REINFORCEMENT, NOT THE SIGNAL. Option (iii) of the precondition — dim the glyph
    and change nothing else — was rejected because a colour change is invisible in a plain-text
    golden diff, which CLAUDE.md's "Learned" section catalogues three times. `cell_mark` below prints
    a literal `?`, so the plain-text diff moves; this makes the screen agree with it.
    """
    if not resolved_provenance(node):
        return DIM
    return _GLYPH_COLOR.get(state_glyph(node), YELLOW)


def cell_mark(node: dict, drift: bool) -> str:
    """The cell's SECOND slot: `?` unverified, `!` drift, or a space. Exactly one character.

    ONE SLOT, TWO CLAIMS, AND `?` WINS. The precondition measured contention at 0 nodes on both live
    manifests but noted the two can collide in principle, and the tie has to break somewhere. It
    breaks toward `?` because DRIFT IS A CLAIM ABOUT TWO STATES: `drift_parents` fires when a merged
    node sits under an open or closed parent. If this node's own state was never verified, the
    contradiction is itself unverified, and `!` is the most confident mark on the page — RED, and
    read as "something is actually wrong here". Printing it off two hand-typed fields would be a
    stronger false claim than the `✔` this whole change exists to qualify.

    Losing the `!` in that case costs nothing a reader needs: `?` already says do not trust this row,
    and the detail block's `drift:` line still names the parents outright.
    """
    if not resolved_provenance(node):
        return f"{YELLOW}{PROVENANCE_MARK}{NC}"
    if drift:
        return f"{RED}{DRIFT_MARK}{NC}"
    return " "


def state_word(node: dict) -> str:
    """The uppercase state for a detail heading, or "" when nobody has a recognized answer.

    "" AND NOT THE RAW TOKEN. A detail heading is prose a human reads; printing `UNKNOWN` there
    states a fact about a PR when what is actually true is a fact about the sweep, and printing
    `STACKED` prints a manifest author's private vocabulary as though it were PR state. Either way
    `state_line` below already says the honest thing on its own line, so the heading stays empty
    rather than confidently wrong.
    """
    # AC4 PRECONDITION, AND THIS IS THE SITE THE PRECONDITION NAMES AS THE COMPOUNDING ONE. Before
    # this guard the heading stamped a confident `MERGED` one line above `state: from the manifest
    # (declared, may be stale)` -- the page contradicting itself within two lines, with the loud half
    # wrong. An unverified state gets no uppercase word at all; `state_line` immediately below says
    # the honest thing, and the cell already carries `?`.
    #
    # "" AND NOT `MERGED (declared)`. The heading is prose a human scans, and a parenthetical is
    # exactly what a scanning eye drops -- which would leave the same false claim in the same place
    # with a footnote nobody read.
    if not resolved_provenance(node):
        return ""
    state = node.get("state")
    # grid.DECLARABLE_STATES rather than the triple spelled out again: a token a manifest may legally
    # declare is a token a heading may legally print, so if a fourth is ever added this follows it
    # instead of silently refusing to name it.
    return str(state).upper() if state in grid.DECLARABLE_STATES else ""


# WHERE a state came from, in a sentence. Keyed on grid's own constants rather than string literals
# so the two modules cannot drift apart -- see the module docstring.
#
# NO ADAPTER IS EVER NAMED. An earlier draft of this line read "from the github sweep", which is
# fabricated provenance on the one line whose entire job is provenance: swept_items merges every
# adapter's items first-writer-wins with NO back-pointer to which adapter supplied one, and the
# injected employer layer (Slack/Jira/Notion) is a live source of items on another machine.
_STATE_SENTENCE = {
    grid.STATE_SOURCE_SWEPT: "from the sweep",
    grid.STATE_SOURCE_FETCHED: "from a targeted fetch",
    grid.STATE_SOURCE_DECLARED: "from the manifest (declared, may be stale)",
    grid.STATE_SOURCE_UNKNOWN: "nobody has an answer for this ref (not swept, not fetched, not declared)",
}


def state_line(node: dict) -> str:
    """The `state:` sentence for a detail block: the CONDITION, never the token."""
    return _STATE_SENTENCE.get(node.get("state_source", ""), _STATE_SENTENCE[grid.STATE_SOURCE_UNKNOWN])


def drift_parents(node: dict, nodes: dict) -> list[str]:
    """Parents that have NOT merged under a node that has. Empty in the healthy case.

    A merged child under an unmerged parent means the declared order and what actually happened
    disagree. The picture cannot express that with position -- the child is still ranked below the
    parent, because ranking reads the DECLARATION -- so without a mark the picture silently
    contradicts the states printed inside it. Reported, never repaired: the manifest may simply be
    stale, and re-ranking on observed state would make the topology jump around as PRs merge.

    A parent nobody resolved is NOT drift. `unknown` is not `open`; treating it as unmerged would
    stamp `!` across an entire `--local` render, where by construction nothing was looked up.
    """
    if node.get("state") != manifest_core.STATE_MERGED:
        return []
    drifted = []
    for parent in node.get("parents") or []:
        parent_state = (nodes.get(parent) or {}).get("state")
        if parent_state in (manifest_core.STATE_OPEN, manifest_core.STATE_CLOSED):
            drifted.append(parent)
    return drifted


# ── topology ──────────────────────────────────────────────────────────────────────────────────────


def level_of(manifest_grid: dict) -> dict[str, int]:
    """`{ref: level}`, READ OFF THE NODE, never re-derived by inverting `levels`.

    `grid._grid_nodes` stamps `level` on every node and its docstring states the reason outright:
    the integer is there "so `drone status`-class consumers read one node and must not have to invert
    a list of lists to learn where it sits". This module is such a consumer. Inverting `levels` here
    would be a second derivation of a published field -- cheap, but it is the shape where two answers
    to one question drift apart, and it was being built five times per manifest per render.
    """
    nodes = manifest_grid.get("nodes") or {}
    return {ref: node.get("level", 0) for ref, node in nodes.items()}


def _forward(manifest_grid: dict) -> tuple[dict[str, int], list[tuple[str, str]], dict, dict]:
    """`(ranks, pairs, parents_of, children_of)` over the edges that DESCEND. ONE pass, one truth.

    THE ONLY THING THIS MODULE ADDS TO THE WIRE IS THE BACK-EDGE FILTER, and that filter is correctly
    here rather than in `grid.py`. `grid._ordering_adjacency` already applied the edge-kind filter,
    the both-endpoints-inside rule and the dedup, and already sorted both lists into declaration
    order; publishing only descending edges would make `--json` lossy, and would leave no consumer
    able to report that a manifest declares a cycle at all. A back edge is a true declared fact; it
    is only undrawable.

    An earlier version flattened `children` into a pair list, filtered THAT by rank, and re-inverted
    it into two dicts -- arriving back at what the wire already carried, minus the wire's own
    ordering guarantee, across five functions and seven traversals per render. Reading the two
    published lists directly preserves `(seq, ref)` order by construction.
    """
    nodes = manifest_grid.get("nodes") or {}
    ranks = {ref: node.get("level", 0) for ref, node in nodes.items()}
    parents_of = {
        ref: [p for p in node.get("parents") or [] if p in ranks and ranks[p] < ranks[ref]]
        for ref, node in nodes.items()
    }
    children_of = {
        ref: [c for c in node.get("children") or [] if c in ranks and ranks[c] > ranks[ref]]
        for ref, node in nodes.items()
    }
    pairs = [(ref, child) for ref in sorted(children_of) for child in children_of[ref]]
    return ranks, pairs, parents_of, children_of


def ordering_pairs(manifest_grid: dict) -> list[tuple[str, str]]:
    """The FORWARD edges: every declared pair whose parent ranks strictly above its child.

    Everything drawn in this module reads this and never the raw adjacency, so a back edge cannot
    appear as a connector anywhere.
    """
    return _forward(manifest_grid)[1]


def back_edges(manifest_grid: dict) -> list[tuple[str, str]]:
    """What `ordering_pairs` dropped: declared pairs that do not descend.

    ONLY A CYCLE PRODUCES ONE. manifest_core._rank_nodes breaks a cycle by admitting the smallest
    remaining ref outright rather than raising, so a cyclic manifest still ranks every node -- and one
    of its edges necessarily points level-flat or upward. Excluded from the drawing (an upward
    connector would assert an ordering the ranking itself refused) and surfaced here so a caller can
    SAY so, rather than silently rendering a chain that reads as acyclic.

    NOT YET CONSUMED BY THE PAGE. AC2/S3's SIGNALS section is where a non-empty result becomes a
    sentence; until then its only readers are tests asserting that a fixture really is cyclic. Kept
    public rather than made private because that consumer is one step away and named -- if S3 lands
    without it, this should become `_back_edges` rather than stay a public function whose whole job
    is validating fixtures.
    """
    nodes = manifest_grid.get("nodes") or {}
    ranks = level_of(manifest_grid)
    return [
        (ref, child)
        for ref in sorted(nodes)
        for child in nodes[ref].get("children") or []
        if child in ranks and ranks[ref] >= ranks[child]
    ]


def span_end(ref: str, ranks: dict[str, int], children_of: dict[str, list[str]]) -> int:
    """The deepest level this node's own connectors reach: its level, or its lowest child's.

    Computable BEFORE any column is assigned, which is what breaks the apparent circularity in
    reserving a column through a skip-level gap -- the reservation needs to know how far a node
    reaches, and how far it reaches depends only on the ranking.

    Takes `children_of` from `_forward`, which has already dropped every non-descending child, so no
    `> own` filter is needed here. An earlier version carried one; it could never be false, and a
    guard that cannot execute invites the next reader to trust it for something it does not do.
    """
    own = ranks.get(ref, 0)
    return max([own] + [ranks[child] for child in children_of.get(ref, [])])


def _level_plan(
    refs: list[str], parents_of: dict[str, list[str]], columns: dict[str, int], seq_of: dict[str, int]
) -> list[tuple[str, int | None]]:
    """`[(ref, preferred_column)]` for one level, in the order those nodes claim their columns.

    ONE FUNCTION BECAUSE THERE IS ONE QUESTION. This was three -- an ordering pass and a preference
    pass that each recomputed the same "which parents has this node got" list and then answered
    "where does this node belong" with DIFFERENT rules: the ordering used the parents' MINIMUM
    column, the preference used their MEDIAN. Nothing was wrong, but two definitions of one concept
    is precisely what `grid._declared_order` exists one module over to prevent, and the duplicate
    traversal was per node per level.

    THE PREFERENCE, in one rule:
      * two or more parents -- a JOIN -- centres on `sorted(columns)[len // 2]`. For an odd count
        that is the middle, which is what puts the approved mock's three-parent join in column 1
        under columns 0/1/2. For an EVEN count it is the upper of the two central columns; stated
        because the phrase "lower median" was attached to this formula in the spec and the two
        disagree. The formula is what ships and a two-parent case pins it.
      * exactly one parent -- a CHAIN -- inherits that parent's column, which is what keeps a linear
        track in one column for its whole life.
      * no parent -- preference `None`, and it takes the smallest free column.

    ORDER: by the column a node wants, then `seq` -- DECLARATION order, not ascending ref (see
    grid._grid_nodes' `seq` paragraph for the live measurement that forces it) -- then the ref.

    NO INHERITOR-BEFORE-ORPHAN GROUPING, because A LEVEL CANNOT CONTAIN BOTH. Longest-path ranking
    puts every node with no descending parent at rank 0, and a node at rank L > 0 reached it by
    relaxation from a parent at a strictly lower rank -- which is a descending parent by definition.
    So level 0 is entirely orphans and every level below it is entirely inheritors. An earlier
    version carried a leading group term for this; inverting it changed no output on any fixture,
    including cyclic ones, because there is no level for the two groups to compete on.
    `test_a_level_never_mixes_parentless_and_inheriting_nodes` states the invariant so that a future
    ranking change which breaks it surfaces here rather than as a quietly reordered picture.

    NO `p in columns` GUARD either, and that is safe by construction rather than by optimism:
    `parents_of` carries only edges that DESCEND (see `_forward`), and levels are processed in
    ascending order, so every parent of a node at level L sits at a level below L and is already
    placed. The guard that used to sit here could not execute.
    """
    plan: list[tuple[str, int | None]] = []
    for ref in refs:
        parents = parents_of.get(ref, [])
        if len(parents) >= 2:
            preferred: int | None = sorted(columns[parent] for parent in parents)[len(parents) // 2]
        elif parents:
            preferred = columns[parents[0]]
        else:
            preferred = None
        plan.append((ref, preferred))
    return sorted(plan, key=lambda entry: (entry[1] or 0, seq_of[entry[0]], entry[0]))


def _free_column(taken: set[int], preferred: int | None) -> int:
    """`preferred` when it is available, else the smallest non-negative column that is."""
    if preferred is not None and preferred not in taken:
        return preferred
    column = 0
    while column in taken:
        column += 1
    return column


def assign_columns(manifest_grid: dict) -> dict[str, int]:
    """`{ref: column}` for one manifest. Pure, deterministic, one top-down pass.

    Columns are BRANCHES: a linear chain holds one column for its whole life, a fork spreads, and a
    join returns to the middle of its parents. Nothing here reads state, urgency or time -- the
    picture is a picture of the DECLARED topology, and a node moving column because a PR merged would
    make the shape jump around underneath a reader between two runs.

    RESERVATION SPANS THE GAP. When a node is placed in column `k`, that column is marked used at
    every level from its own down to (but excluding) its deepest child's -- so a skip-level edge
    passing through intermediate levels cannot have another node dropped on top of its connector.
    The exclusive upper bound is right because the child claims its own level itself when it is
    placed.

    `max(span_end(n), L + 1)` IS BINDING, NOT COSMETIC. `span_end` of a childless node is its own
    level, so the naive `range(L, span_end(n))` is EMPTY for every leaf and never marks a leaf's own
    column used at its own level. A fork whose children are all leaves -- the modal shape the moment
    anyone authors `after` on an open frontier -- then places every child in column 0, two nodes in
    one cell. Neither live manifest nor the approved mock reaches it (every one of the mock's fork
    children has a child of its own), which is exactly why it needs a fixture and a test of its own.

    Complexity `O(V + E + V*C)` for `C` the widest level; the free-column scan is the only non-linear
    part, and both live manifests are tens of operations.
    """
    ranks, _, parents_of, children_of = _forward(manifest_grid)
    nodes = manifest_grid.get("nodes") or {}
    seq_of = {ref: node.get("seq", 0) for ref, node in nodes.items()}

    columns: dict[str, int] = {}
    used: dict[int, set[int]] = {}
    for index, refs in enumerate(manifest_grid.get("levels") or []):
        for ref, preferred in _level_plan(list(refs), parents_of, columns, seq_of):
            column = _free_column(used.setdefault(index, set()), preferred)
            columns[ref] = column
            for level in range(index, max(span_end(ref, ranks, children_of), index + 1)):
                used.setdefault(level, set()).add(column)
    return columns


def node_ids(manifest_grids: list[dict], columns_by_manifest: list[dict[str, int]]) -> dict[str, str]:
    """`{ref: "n<N>"}` numbered GLOBALLY across every rendered manifest, reading-order first.

    GLOBAL AND NOT PER-MANIFEST, because the ids are a jump target: every id appears EXACTLY TWICE on
    the page -- once in a picture cell, once as a detail heading -- so `*` in vim toggles between them
    with no plugin. Two manifests each numbering from n1 would put four `n1`s on the page and break
    the jump for both.

    Ordered by `(manifest index, level, column)` -- the order an eye crosses the page, so n1 is the
    top-left node of the first project.
    """
    ids: dict[str, str] = {}
    ordered: list[tuple[int, int, int, str]] = []
    for index, (manifest, columns) in enumerate(zip(manifest_grids, columns_by_manifest)):
        ranks = level_of(manifest)
        for ref in manifest.get("nodes") or {}:
            ordered.append((index, ranks.get(ref, 0), columns.get(ref, 0), ref))
    for number, (_, _, _, ref) in enumerate(sorted(ordered), start=1):
        ids.setdefault(ref, f"n{number}")
    return ids


# ── rasterization ─────────────────────────────────────────────────────────────────────────────────


def short_refs(manifest_grid: dict) -> dict[str, str]:
    """`{ref: "repo#num"}`, or full refs for the WHOLE manifest when two owners share a repo name.

    The picture cell carries the short form and the detail heading the full one -- the approved
    mock's own rule, and what keeps a two-column live picture inside PICTURE_BUDGET: full refs put
    `stillpoint-labs/stillpoint#57` at 29 columns and a two-column row at 79.

    THE COLLISION CHECK IS ALL-OR-NOTHING for the manifest rather than per-ref, because the failure it
    prevents is two DIFFERENT pull requests rendering as the same cell text. Shortening one and not
    the other would fix the ambiguity while leaving two cells whose widths no longer come from one
    rule, so the columns stop aligning. A ref parse_ref rejects keeps its raw string: it cannot be
    shortened and must still occupy a cell.
    """
    nodes = manifest_grid.get("nodes") or {}
    short: dict[str, str] = {}
    owners: dict[str, set[str]] = {}
    for ref in nodes:
        parts = manifest_core.parse_ref(ref)
        if parts is None:
            short[ref] = ref
            continue
        short[ref] = f"{parts[1]}#{parts[2]}"
        owners.setdefault(parts[1], set()).add(parts[0])
    if any(len(seen) > 1 for seen in owners.values()):
        return {ref: ref for ref in nodes}
    return short


def ref_width(short: dict[str, str]) -> int:
    """The cell's ref field width: the longest short ref in this manifest.

    FIXED-WIDTH COLUMNS COMPUTED FROM THE LONGEST REF, never proportional -- the 2026-08-21 review
    spec'd that before any golden existed, so that a node merging or a title arriving cannot reflow
    the picture.
    """
    return max((len(text) for text in short.values()), default=0)


def _pitch(width: int) -> int:
    """Columns between one node's glyph and the next: the cell plus the gutter.

    The cell is `glyph + drift + id + separator + ref` = `width + 7`; see the ID_WIDTH constant for
    why the id field does not grow with the node count.
    """
    return width + 7 + GUTTER


def node_cell(node: dict, node_id: str, short: str, width: int, drift: bool) -> str:
    """One node's compact cell: glyph, drift slot, id, linked short ref, padded to the column pitch.

    PADDING IS COMPUTED ON THE VISIBLE TEXT and applied after the hyperlink wrap. `link_ref` returns a
    string tens of bytes longer than what prints, so padding with `len()` on the wrapped string shifts
    every subsequent column right by the length of a URL -- invisible in a diff, obvious on screen.
    """
    mark = cell_mark(node, drift)
    return (
        f"{glyph_color(node)}{state_glyph(node)}{NC}{mark}{node_id.ljust(ID_WIDTH)} "
        f"{link_ref(node['ref'], short)}{' ' * (width - len(short))}"
    )


def _segments(boundary: int, pairs: list[tuple[str, str]], ranks: dict, columns: dict) -> list[tuple[int, int]]:
    """`(from_column, to_column)` for every edge crossing the boundary between `boundary` and the next.

    AN EDGE JOGS AT ITS LAST BOUNDARY ONLY. A skip-level edge holds its parent's column straight down
    through every intermediate boundary and moves sideways once, into its child's column, at the
    boundary immediately above the child. Drawing it as a diagonal across several boundaries would
    make it cross other columns at levels where those columns hold real nodes.
    """
    segments = []
    for parent, child in pairs:
        if ranks[parent] <= boundary < ranks[child]:
            source = columns[parent]
            target = columns[child] if boundary + 1 == ranks[child] else source
            segments.append((source, target))
    return segments


def _row(cells: dict[int, str], width: int, span: tuple[int, int] | None = None) -> str:
    """Lay `{column: text}` onto one line at the fixed pitch, right-trimmed.

    `span` names an inclusive column range whose GAPS are filled with `─` instead of spaces, which is
    the only thing a rail row needs that a node row does not. It was a second near-identical function
    until it was not: that copy measured its running width with bare `len` while this one used
    `visible_len`, so the first coloured or hyperlinked rail cell would have shifted every column to
    its right -- silently, because escape bytes do not print in a diff.

    WIDTH IS TRACKED, NOT REMEASURED. The earlier version called `visible_len` on the whole
    accumulated line once per column, which is two regex passes over a growing string per column.
    Each cell's visible width is known as it is appended.
    """
    if not cells:
        return ""
    pitch = _pitch(width)
    parts: list[str] = []
    visible = 0
    for column in sorted(cells):
        pad = INDENT + column * pitch - visible
        fill = "─" if span and span[0] < column <= span[1] else " "
        parts.append(fill * pad + cells[column])
        visible += pad + visible_len(cells[column])
    return "".join(parts).rstrip()


def stem_row(columns_with_stems: set[int], width: int) -> str:
    """A vertical run: `│` at each named column, nothing anywhere else."""
    return _row({column: f"{DIM}│{NC}" for column in columns_with_stems}, width)


def rail_row(segments: list[tuple[int, int]], width: int) -> str:
    """The horizontal row that moves edges between columns, drawn character by character.

    BOTH STROKES ARE COUNTED OVER EVERY CROSSING SEGMENT, straight ones included, and that is a
    correction to the rule this was specified with -- see the module docstring for the measurement.
    At a fan-out, the column the parent sits in also carries a STRAIGHT segment continuing downward;
    counting only the jogging segments renders that column as `└` (a corner) where the mock says `├`
    (a tee), and renders the mock's join as `└┬┘` where it says `└┼┘`.

    THE `crossing` ARM IS THE ONE THING A PURE 4-BIT MASK CANNOT EXPRESS. A column that merely PASSES
    THROUGH the interior of a rail's span has an upward and a downward stroke of its own, and the
    rail's horizontal fill supplies left and right -- so the mask says `┼`, which asserts that the
    pass-through merges into the join. It does not. Such a column is drawn `│`, with the fill
    continuing on both sides (`──│──`). Neither the approved mock nor either live manifest reaches
    this (in all three, every pass-through is a rail ENDPOINT), so it gets a hand-authored fixture.
    """
    jogging = [pair for pair in segments if pair[0] != pair[1]]
    if not jogging:
        return ""
    involved = {column for pair in jogging for column in pair}
    low, high = min(involved), max(involved)

    # THREE SETS, HOISTED. Each of these was an `any(... for pair in ...)` rescan of the segment list
    # inside the per-column loop; as sets, the stroke tuple below reads directly against _BOX's
    # (up, right, down, left) key order instead of hiding it in three generator expressions.
    sources = {pair[0] for pair in segments}
    targets = {pair[1] for pair in segments}
    standing = {pair[0] for pair in segments if pair[0] == pair[1]}

    cells: dict[int, str] = {}
    for column in range(low, high + 1):
        if column in involved:
            strokes = (int(column in sources), int(column < high), int(column in targets), int(column > low))
            cells[column] = _BOX[strokes]
        elif column in standing:
            cells[column] = "│"
        else:
            cells[column] = "─"

    # A straight segment OUTSIDE the rail's span still crosses this boundary and still needs its
    # stroke, or an untouched chain appears to stop dead for one row beside an unrelated fork.
    for column in standing:
        cells.setdefault(column, "│")

    return f"{DIM}{_row(cells, width, (low, high))}{NC}"


# JUSTIFICATION (too-many-locals): six of these are per-manifest CONSTANTS, each derived by a
# different module-level function above (ranks, pairs, short, width, nodes, levels), and the rest are
# the loop's own. Every decomposition tried produces a helper taking seven-to-nine parameters -- and
# the class version additionally trips the clean-arch Demeter rule, which forbids calling a method on
# a local object. A container that exists only to satisfy a counter would move the same seven names
# one line further from the docstrings that explain them.
# pylint: disable-next=too-many-locals
def picture(manifest_grid: dict, ids: dict[str, str], columns: dict[str, int]) -> list[str]:
    """One manifest's grid as box-drawing rows: node rows top to bottom, connectors between them.

    THE CADENCE IS stem / [stem, rail, stem]. A boundary every one of whose edges runs straight down
    emits ONE stem row; a boundary with any sideways movement emits three, and the two stem rows carry
    DIFFERENT column sets -- the upper one the columns edges LEAVE, the lower one the columns they
    ARRIVE IN. Using one set for both is what renders `│ │ │` above a fan-out where the mock shows a
    single `│`, because before the rail there is only one edge.

    A NODE ROW ALSO CARRIES PASS-THROUGHS. A column reserved by a skip-level edge crossing this level
    gets a `│` beside the nodes, which is what makes such an edge visible at all rather than appearing
    to vanish for a row and reappear below.
    """
    nodes = manifest_grid.get("nodes") or {}
    levels = manifest_grid.get("levels") or []
    if not levels:
        return []

    ranks = level_of(manifest_grid)
    pairs = ordering_pairs(manifest_grid)
    short = short_refs(manifest_grid)
    width = ref_width(short)

    rows: list[str] = []
    for index, refs in enumerate(levels):
        occupied = {columns[ref] for ref in refs}
        cells = {
            columns[ref]: node_cell(
                nodes[ref], ids.get(ref, ""), short[ref], width, bool(drift_parents(nodes[ref], nodes))
            )
            for ref in refs
        }
        # A column reserved by a skip-level edge crossing THIS level gets a stroke beside the nodes.
        for parent, child in pairs:
            if ranks[parent] < index < ranks[child] and columns[parent] not in occupied:
                cells[columns[parent]] = f"{DIM}│{NC}"
        rows.append(_row(cells, width))

        if index + 1 >= len(levels):
            continue
        segments = _segments(index, pairs, ranks, columns)
        if not segments:
            continue
        # The two stem rows carry DIFFERENT column sets: the upper one the columns edges LEAVE, the
        # lower one the columns they ARRIVE IN.
        rows.append(stem_row({pair[0] for pair in segments}, width))
        if any(pair[0] != pair[1] for pair in segments):
            rows.append(rail_row(segments, width))
            rows.append(stem_row({pair[1] for pair in segments}, width))
    return rows


def reading_order(manifest_grid: dict, ids: dict[str, str]) -> list[str]:
    """One manifest's refs in the order an eye crosses its picture: top to bottom, then left to right.

    THE ONE DEFINITION OF THAT ORDER, and it is public because `render.py` needs it too -- the glance
    strip and the detail blocks under it must agree, or a reader moving between the picture and the
    details re-sorts in their head. Node ids are assigned by `(manifest, level, column)` in
    `node_ids`, so ordering by id IS reading order; deriving it a second time from levels and columns
    would be a second rule for one question, which is the shape `_id_order`'s own comment records
    going wrong once already.
    """
    return sorted(manifest_grid.get("nodes") or {}, key=lambda ref: _id_order(ref, ids))


def glance_row(manifest_grid: dict, ids: dict[str, str]) -> str:
    """One glyph per node, in node-id order. The at-a-glance strip, with NO ids in it.

    Ids are deliberately absent: the strip answers "how much of this is done" at a glance, and
    repeating every id here would put each one on the page three times, breaking the exactly-twice
    rule that makes `*` a working jump key.
    """
    nodes = manifest_grid.get("nodes") or {}
    return " ".join(
        f"{glyph_color(nodes[ref])}{state_glyph(nodes[ref])}{NC}" for ref in reading_order(manifest_grid, ids)
    )


def _id_order(ref: str, ids: dict[str, str]) -> int:
    """A ref's position in reading order, from its node id. Unnumbered refs sort last.

    Node ids are assigned by `(manifest, level, column)`, so ordering by id IS the order an eye
    crosses the picture -- top to bottom, then left to right.
    """
    label = ids.get(ref, "")
    return int(label[1:]) if label[1:].isdigit() else len(ids) + 1


def _detail_refs(refs: list[str], nodes: dict, ids: dict[str, str]) -> str:
    """`ref (state)` for each of a node's neighbours, `·`-joined, IN NODE-ID ORDER.

    NOT in the order `grid.py` put them on the wire, and the difference is worth the sort. The wire
    orders `parents`/`children` by `(seq, ref)` -- declaration order -- which is the key the COLUMN
    assignment consults and which no reader of the finished page can see. Node ids are assigned from
    `(manifest, level, column)`, so this lists neighbours in the order their DETAIL BLOCKS appear
    further down the page: `waits on: ... n4-ish ref` then the ref n5 heads, and so on. A reader
    walking a chain scrolls forward, never back.

    THREE ORDERS EXIST HERE AND THEY DISAGREE, which is worth stating because the AC2 spec's own
    sample block is one of them. For the mock's three-parent join the candidates are: declaration
    order on the wire (`infra#12, platform#431, warehouse#93`, by row seq), the raw `after` array as
    the manifest author typed it (`platform#431, warehouse#93, infra#12` -- what §2.1's sample shows,
    and what the wire deliberately does not preserve), and node-id order (`infra#12, platform#431,
    warehouse#93`, because infra#12 sits a level HIGHER and its id is therefore lower). The three
    coincide for a same-level fan-out and come apart only for a SKIP-LEVEL parent.

    Node-id order ships, and the reason is that the ids are the page's navigation handles: the detail
    blocks are laid out in id order, so naming neighbours in any other order sends a reader backwards
    through the page. Column order -- left-to-right along the rail, which is what §2.1's sample
    happens to match -- was the alternative; it reads the PICTURE better and the DETAILS worse, and
    only one of the two is a list of jump targets. Recorded rather than left implicit: an earlier
    version of this docstring claimed node-id order reproduced §2.1's sample, and it does not.
    """
    parts = []
    for ref in sorted(refs, key=lambda r: _id_order(r, ids)):
        state = state_word(nodes.get(ref) or {}).lower()
        parts.append(f"{ref} ({state})" if state else ref)
    return " · ".join(parts)


def detail_block(node: dict, node_id: str, nodes: dict, ids: dict[str, str]) -> list[str]:
    """One node's detail block: the heading a `*` jump lands on, then what it waits on and unlocks.

    THE HEADING CARRIES THE FULL REF, and the picture cell carries the short one. The full form is
    self-addressing -- the nvim `gp` keymap opens `owner/repo#num` under the cursor -- so the detail
    block is where a reader goes to actually open the PR, and it must never be the abbreviated form.

    THE ID APPEARS EXACTLY ONCE HERE and exactly once in the picture. That is the whole mechanism
    behind `*` toggling between the two with no plugin, and any third occurrence anywhere on the page
    breaks it.

    `ids` ORDERS THE NEIGHBOUR LISTS into picture reading order; see _detail_refs for why that is not
    the order the wire carries them in. REQUIRED, not optional with a wire-order fallback: the only
    thing that ever exercised the fallback was the test naming it, and a parameter that exists so a
    test can test it is one moving part too many. A caller with no ids passes `{}` and gets wire
    order, explicitly.
    """
    ref = node["ref"]
    word = state_word(node)
    parents = node.get("parents") or []
    children = node.get("children") or []
    drifted = drift_parents(node, nodes)

    # PADDED TO A FIXED FIELD, not four literal spaces, for the same reason `node_cell` ljusts the id
    # and `_label` computes `col - len(text)`: with a hard-coded run of spaces the ref column is
    # aligned for n1..n9 and ragged from n10 on, and the approved mock's own later render reaches
    # n17. Computed as `ID_WIDTH + 2` so a heading's ref sits two columns right of where the picture
    # cell's does -- the detail block is indented one level less and the two must not collide.
    heading = f"  {DIM}{node_id}{NC}{' ' * max(ID_WIDTH + 2 - len(node_id), 1)}{link_ref(ref, ref)}"
    if word:
        heading += f"  {glyph_color(node)}{word}{NC}"
    if len(parents) > 1:
        heading += f"  {DIM}(join: {len(parents)} parents){NC}"
    lines = [heading]

    title = node.get("title") or ""
    if title:
        lines.append(f"      {title}")
    why = node.get("why") or ""
    if why:
        lines.append(f"      {DIM}why:{NC}       {why}")
    if parents:
        lines.append(f"      {DIM}waits on:{NC}  {_detail_refs(parents, nodes, ids)}")
    lines.append(
        f"      {DIM}unlocks:{NC}   {_detail_refs(children, nodes, ids)}"
        if children
        else f"      {DIM}unlocks:{NC}   {DIM}nothing — end of the chain{NC}"
    )
    if drifted:
        lines.append(f"      {RED}drift:{NC}     merged ahead of {_detail_refs(drifted, nodes, ids)}")
    gate = node.get("gate")
    if isinstance(gate, dict) and gate.get("blocked_by"):
        lines.append(f"      {CYAN}gate:{NC}      {gate.get('kind', '')} — {gate['blocked_by']}")
        if gate.get("resolved_by"):
            lines.append(f"      {CYAN}unparked:{NC}  {gate['resolved_by']}")
    lines.append(f"      {DIM}state:{NC}     {state_line(node)}")
    return lines
