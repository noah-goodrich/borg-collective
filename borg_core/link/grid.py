"""The manifest GRID: a project's declared topology resolved against a live source sweep.

Pure -- no os, no subprocess, no environment, no clock, no filesystem. Same Domain rules as
borg_core/link/core.py, and pylint enforces them here too (pyproject's clean-arch module map names
this file alongside core.py deliberately, so extracting it EXTENDS the purity gate rather than
escaping one).

WHY THIS IS NOT IN core.py. It started there, and the sweep fold pushed that module past pylint's
1000-line ceiling in one step -- which was the honest signal rather than a threshold to suppress.
`core.py` answers "what does the registry say about every project": entries, ordering, capacity,
relative times, the overview document. This answers "what does one project's manifest declare, and
what is the live state of every ref it names". Two questions, two shapes of data, one shared
coercion. Nothing here is imported BY core.py -- `assemble` takes the finished `grid` block as an
opaque argument -- so there is no cycle and no layering inversion; `borg_core.link.core` is imported
for `jq_default` alone, one Domain module reading another's public helper, exactly as this module
already reads `borg_core.manifest.core`.

THE RESOLVE LADDER IS THE POINT OF THE FILE: swept > fetched > declared > unknown. `state_source`
travels beside every `state` because a hand-authored manifest field and a live adapter answer are not
the same evidence, and rendering them identically is how a merged row keeps announcing itself as
next.

AC3'S TARGETED FETCH IS BUILT AND PARSED HERE, AND RUN IN shell.py. `fetch_query` turns a list of
declared refs into one aliased GraphQL document and `fetched_items` turns the response back into a
ref-keyed map; both are string-in/string-out and neither knows what a subprocess is. Only the spawn,
the deadline and the `BORG_LINK_FETCH_FIXTURE` seam live in the shell tier. Splitting it that way is
what keeps the fetch inside the Domain purity gate instead of needing a new module added to
pyproject's clean-arch map.
"""

from __future__ import annotations

from borg_core import timefmt
from borg_core.link import core
from borg_core.manifest import core as manifest_core

format_iso = timefmt.epoch_to_iso
jq_default = core.jq_default


# The FOUR tokens a node's `state_source` can carry -- WHERE a state came from, kept beside the
# state itself because the two answer different questions and a renderer needs both. `declared` is a
# manifest author's assertion, which can be months stale; `swept` is a source adapter's answer as of
# `grid.since`; `fetched` is a targeted answer for a ref the sweep's window or breadth did not cover
# -- live evidence, but from a narrower question than the sweep asked, and about one ref rather than
# about everything that changed; `unknown` means nobody has one. Rendering a stale `declared`
# identically to a fresh `swept` is how a merged row keeps announcing itself as next.
#
# THE SOURCE-CODE ORDER IS THE LADDER ORDER, deliberately, so a reader of these four lines and a
# reader of resolve_state see the same precedence.
STATE_SOURCE_SWEPT = "swept"
STATE_SOURCE_FETCHED = "fetched"
STATE_SOURCE_DECLARED = "declared"
STATE_SOURCE_UNKNOWN = "unknown"
GRID_STATE_UNKNOWN = "unknown"

# The `state_source` values that mean "somebody actually looked". `unresolved` counts everything
# else; see build_grid.
RESOLVED_STATE_SOURCES = (STATE_SOURCE_SWEPT, STATE_SOURCE_FETCHED)

# The ONLY declared `status` values the ladder will promote to a state, and they are exactly the
# github adapter's three tokens (borg_core/manifest/core.py:103-105). A manifest's `status` field is
# hand-authored and its vocabulary is WIDER than that: the live viz manifest carries `"stacked"`,
# which is a position in a stack, not a PR state. Accepting it would put the token `stacked` in the
# same field a renderer reads `merged` from, and every state glyph downstream would have to grow a
# branch for authoring vocabulary. Anything outside this tuple falls through to `unknown`, which is
# the honest answer until AC3's targeted fetch resolves it.
DECLARABLE_STATES = (manifest_core.STATE_OPEN, manifest_core.STATE_MERGED, manifest_core.STATE_CLOSED)


def _grid_text(value: object) -> str:
    """`str(value or "").strip()`, the same coercion borg_core.manifest.core applies to every field.

    Restated here rather than imported because manifest.core's copy is private (`_text`), and reading
    a foreign module's underscore name is a clean-arch visibility failure, not a style opinion. Both
    copies must stay identical: a ref coerced one way here and another way there indexes one string
    while the graph holds a different one, which is the silent-mismatch class parse_ref exists to
    prevent.
    """
    return str(value or "").strip()


# How far back `link`'s sweep looks, in days. FIXED, WIDE, AND SCOPE-INVARIANT -- three properties,
# each one a bug that shipped in the first pass of the sweep fold.
#
# The first pass reused `recon.shell.resolve_since`, whose ladder is newest-checkpoint-mtime >
# last-run marker > 24h. That ladder answers "what changed since I last looked", which is the right
# question for a morning link-up and the WRONG question for a grid: the grid needs the CURRENT state
# of every declared ref. The shipped adapter honours the mark as a hard filter
# (`select((.updatedAt|split("T")[0]) >= $since)`), so anything that merged before it returns NO item
# and the node falls through to the hand-authored `status`.
#
# Worse, that mark MOVED WITH SCOPE, because the checkpoint rung globs the scoped projects. Measured
# against real checkouts, a real registry and a real filtering adapter: `borg link --json alpha` (one
# 6-day-old checkpoint) reported `testorg/alpha#11` as `merged`/`swept`, while `borg link --json`
# from the workspace root -- wider breadth, and the widest breadth took the NEWEST checkpoint across
# all repositories, so the NARROWEST window -- reported the same ref as `open`/`declared`. One
# document key, one ref, two confident answers, both with `swept: true` and zero warnings.
#
# 90 days costs NOTHING to widen. The batched GraphQL query is `pullRequests(first: 30, orderBy:
# UPDATED_AT DESC)` per repository and the rate-limit cost is flat at 1 point from 14 aliased nodes
# to 112, so a wider window changes neither the round trip nor the quota -- it only stops the adapter
# discarding rows it already fetched. It is a WINDOW and not "no filter at all" because the adapter's
# `first: 30` cap means an unbounded mark would still truncate; what the window must be is
# INDEPENDENT OF SCOPE AND OF HOW RECENTLY ANYONE CHECKPOINTED, which any fixed number is and the
# checkpoint ladder is not. AC3's ref-keyed targeted fetch is the real fix -- it asks about declared
# refs by name, with no time window at all -- and this is the scope-invariant floor until it lands.
DEFAULT_SWEEP_WINDOW_DAYS = 90

SECONDS_PER_DAY = 86400


def sweep_since(now_epoch: int, window_days: int) -> str:
    """The sweep mark: `window_days` before `now_epoch`, in the adapter contract's ISO grammar.

    Pure, and takes the instant rather than reading a clock, so the whole document is built from the
    ONE epoch cli._document threads through every other derived field. A negative or zero window
    would ask an adapter for the future; it is clamped to one day, which is the narrowest mark that
    still means something after the adapter truncates to date granularity.
    """
    return format_iso(now_epoch - max(1, window_days) * SECONDS_PER_DAY)


def no_sweep(warnings: list[str] | None = None) -> dict:
    """The sweep result for "no adapter ran", carrying the reason.

    ONE constructor for the shape, called from four places that all mean different things -- `--local`
    opted down, no adapters on the search path, a fixture that would not parse, a project list that
    would not stage. Each supplies its own warning; none of them may invent a `since`, because a mark
    nobody swept against is a claim about freshness that is not true.
    """
    return {"swept": False, "since": "", "tracks": [], "warnings": list(warnings or [])}


def track_status(track: dict) -> str:
    """One track's health: "failed", "degraded" or "ok". THREE outcomes, not two.

    `ok` IS NOT THE WHOLE STORY, and believing it was is the defect this function exists to close.
    recon.core sets `ok: False` only when the adapter exited non-zero, timed out, or emitted
    unparseable output (recon/core.py:build_failed_track). The shipped github adapter does NONE of
    those for its own unavailability: a missing `gh`, an unauthenticated `gh`, an offline host, a
    rate limit, and "no github repository in scope" all route through `emit_skip`, which prints a
    valid track and exits 0. So the five MOST LIKELY real-world sweep failures used to arrive as
    `ok: True`, `items: []`, `status: "ok"`, zero warnings -- byte-identical to a healthy sweep that
    found nothing, on the one command whose entire purpose is derived fact. Reproduced end to end:
    an unauthenticated `gh` produced `swept: true`, one `ok` source, an empty `warnings`, and a grid
    in which every state came from a hand-authored manifest field.

    "degraded" also covers a track that ANSWERED and had its answer thrown away. recon's
    `normalize_track` filters every item through `validate_item` and records the casualties in
    `dropped` while still stamping `ok: True`, so an adapter whose `action_needed` is the string
    `"false"` instead of a bool contributes nothing and reports success. `dropped` was already on the
    track; it was simply being projected away.

    `track.get("ok", True)` and NOT `track.get("ok")`: recon.core stamps `ok` on every track it
    builds, so an ABSENT key only ever means a hand-recorded fixture, and defaulting that to failure
    would make every fixture emit spurious warnings. A key present and False is a real failure. (This
    is the Python-side shape of the jq `//` trap CLAUDE.md records: `false` is not the same as
    absent, and one operator conflating them is how a failed track becomes invisible.)
    """
    if not track.get("ok", True):
        return "failed"
    if track.get("skipped") or _track_dropped(track):
        return "degraded"
    return "ok"


def _track_dropped(track: dict) -> int:
    """How many items recon's Item validator rejected. Absent (a hand-recorded fixture) means none."""
    dropped = track.get("dropped")
    return dropped if isinstance(dropped, int) and not isinstance(dropped, bool) and dropped > 0 else 0


def _track_warning(track: dict) -> str:
    """The one named warning a non-ok track earns, or "" when it came back clean.

    THE THREE SENTENCES ARE DIFFERENT ON PURPOSE. "returned no usable answer" is a source that broke;
    "could not reach its source" is a source that was never asked; "rejected N item(s)" is a source
    that answered and had the answer discarded. Collapsing them into one string would leave a
    consumer parsing prose to recover the distinction the `status` field is supposed to carry.
    """
    source = _grid_text(track.get("source")) or "?"
    summary = _grid_text(track.get("summary")) or "no summary"
    status = track_status(track)
    if status == "failed":
        return f"sweep: adapter '{source}' returned no usable answer -- {summary}"
    if status != "degraded":
        return ""
    dropped = _track_dropped(track)
    if track.get("skipped"):
        return f"sweep: adapter '{source}' could not reach its source -- {summary}"
    return (
        f"sweep: adapter '{source}' returned {dropped} item(s) the Item schema rejected"
        f" -- they contributed nothing -- {summary}"
    )


def track_warnings(tracks: list[dict]) -> list[str]:
    """A named warning for every adapter track that did not come back clean. See track_status."""
    return [w for w in (_track_warning(t) for t in tracks if isinstance(t, dict)) if w]


def swept_items(tracks: list[dict]) -> dict[str, dict]:
    """Every Item the sweep returned, keyed by its EXACT ref. The `swept` rung of the resolve ladder.

    FIRST WRITER WINS when two adapters emit the same ref. Deterministic, because
    recon.shell.fanout preserves adapter order and discover_adapters is sorted and deduped
    first-on-path-wins -- so a config-dir adapter shadowing the shipped one wins here too, matching
    what shadowing already means for discovery. Last-wins would make the answer depend on which
    adapter finished first, which is thread-scheduling order.

    NO NORMALIZATION OF ANY KIND is applied to the key. borg_core/manifest/core.py:parse_ref carries
    the argument in full: a case fold or a `.git` strip produces a ref that matches no item and no
    row, and the mismatch never raises -- the node simply renders `unknown` forever.
    """
    items: dict[str, dict] = {}
    for track in tracks:
        if not isinstance(track, dict):
            continue
        for item in track.get("items") or []:
            if not isinstance(item, dict):
                continue
            ref = _grid_text(item.get("ref"))
            if ref:
                items.setdefault(ref, item)
    return items


def grid_sources(tracks: list[dict]) -> list[dict]:
    """One `{source, status, summary, count, dropped}` row per adapter. Never the raw items.

    The grid carries a per-source RECEIPT, not a dump: the items themselves are already projected
    into `nodes`, and re-emitting them under `sources` would double every payload in a document that
    `drone status` parses once per tmux window. What a consumer needs from this list is which sources
    answered and how much they contributed -- enough to tell "nothing changed" from "GitHub was down".

    `status` IS THREE-VALUED (see track_status) AND `dropped` IS ON THE WIRE, because the two-valued
    version of this row could not actually make that distinction: it stamped "ok" on a source that
    was never reached, and it discarded the count of items the Item schema rejected -- so a receipt
    reading `summary: "1 PR item(s)"` sat next to `count: 0` with nothing to explain the gap.
    """
    return [
        {
            "source": _grid_text(track.get("source")),
            "status": track_status(track),
            "summary": _grid_text(track.get("summary")),
            "count": len(track.get("items") or []),
            "dropped": _track_dropped(track),
        }
        for track in tracks
        if isinstance(track, dict)
    ]


def resolve_state(
    ref: str, declared_status: object, items: dict[str, dict], fetched: dict[str, dict]
) -> tuple[str, str]:
    """One ref's `(state, state_source)` down the resolve ladder: swept > fetched > declared > unknown.

    A SWEPT TOKEN IS TAKEN VERBATIM and is NOT checked against DECLARABLE_STATES, while a declared one
    is. The asymmetry is deliberate. A source adapter owns its own state vocabulary -- the github
    adapter emits three tokens, but an injected Jira or Slack adapter emits its own, and coercing
    those to `unknown` would throw away the only real answer anybody has. A manifest `status` is
    hand-typed by whoever wrote the file, in a field with no schema, and `"stacked"` is already in
    the live data; promoting that to a state would put authoring vocabulary in the field renderers
    read PR state from.

    A FETCHED TOKEN IS TAKEN VERBATIM FOR THE SAME REASON. It came off the wire, not out of a text
    editor, so the argument that filters a declared status does not apply to it.

    WHY `fetched` SITS BELOW `swept` RATHER THAN ABOVE IT, since both are live. The sweep asks "what
    changed across these repositories", the fetch asks "what is this one ref". They can disagree --
    they are two round trips at two instants -- and when they do, the sweep's answer is the one that
    also produced the item a renderer reads `title`, `changed` and `action_needed` from. Preferring
    the fetch would split one node's fields across two answers. `fetched` sits ABOVE `declared`
    because a hand-authored status can be months stale and this cannot.

    `fetched` IS REQUIRED, NOT DEFAULTED. There is exactly one production call site, and a default
    would let a future one silently skip the rung -- which fails as a node rendering `unknown`
    forever, with nothing raised and no warning anywhere. Passing `{}` is the explicit way to say
    "no fetch happened", and the tests that mean that say it.
    """
    item = items.get(ref)
    swept = _grid_text(item.get("state")) if isinstance(item, dict) else ""
    if swept:
        return swept, STATE_SOURCE_SWEPT
    answer = fetched.get(ref)
    live = _grid_text(answer.get("state")) if isinstance(answer, dict) else ""
    if live:
        return live, STATE_SOURCE_FETCHED
    declared = _grid_text(declared_status).lower()
    if declared in DECLARABLE_STATES:
        return declared, STATE_SOURCE_DECLARED
    return GRID_STATE_UNKNOWN, STATE_SOURCE_UNKNOWN


# ── AC3: the targeted fetch, built and parsed here, run in shell.py ───────────────────────────────

# One aliased node per declared ref. `issueOrPullRequest`, NOT `pullRequest`, and the difference only
# becomes visible on a manifest nobody has written yet: `apex.ref` is a TRACKER ISSUE
# (manifest.core._validate_apex allows it and declared_refs includes it), so a PR-only query returns
# null for every issue and those nodes render `unknown` -- the one thing AC3 forbids. Both live
# manifests happen to have no apex, so a PR-only fetch is green on every current fixture and stays
# green until the first tracker is declared.
#
# `issueState: state` IS SPEC-CORRECTNESS, AND THE HANDED-DOWN RATIONALE FOR IT WAS WRONG. The claim
# this alias arrived with was that GitHub REJECTS the whole document without it, because
# `PullRequest.state` is `PullRequestState!` and `Issue.state` is `IssueState!` -- two different enums
# under one response name, which the GraphQL spec's SameResponseShape rule forbids. Measured live
# 2026-08-26 against a batch carrying a real Issue AND a real PullRequest: GitHub ACCEPTS BOTH FORMS
# and returns the issue's state under whichever name was asked for. So the rejection claim is false
# for this server today, and it is recorded as false here rather than left to be cited later.
#
# The alias stays anyway, for the reason that survives measurement: the query is spec-valid with it
# and merely tolerated without it, and graphql-ruby's leniency about this rule is not a contract
# GitHub has published. fetched_items reads `state` FIRST and falls back to `issueState`, so the
# parser is correct under either form -- which is what actually makes this robust, and is why
# removing the alias would be a silent bet rather than a visible break.
_FETCH_NODE = (
    '{alias}: repository(owner: "{owner}", name: "{name}") {{'
    " issueOrPullRequest(number: {number}) {{"
    " __typename"
    " ... on PullRequest {{ number title state isDraft updatedAt url }}"
    " ... on Issue {{ number title issueState: state updatedAt url }}"
    " }} }}"
)


def _fetchable(ref: str) -> tuple[str, str, str] | None:
    """`(owner, name, number)` for a ref that can safely go into a GraphQL document, else None.

    TWO REJECTIONS, AND BOTH ARE MEASURED RATHER THAN THEORETICAL.

    manifest.core.parse_ref is the injection gate: its character class is exactly the one
    recon-adapter-github validates against before interpolating an owner into its own query, so no
    quote, brace or newline from a hand-authored ref can reach the query body. Every alias node is
    built from the parsed 3-tuple and never from the raw ref string.

    A ZERO-PADDED NUMBER KILLS THE ENTIRE BATCH, not just its own node. `_REF_RE` accepts `#0158` and
    parse_ref returns the digits verbatim (`o/r#007` -> `"007"`, never `7`, by design -- it repairs
    nothing). Measured: `issueOrPullRequest(number: 0158)` returns
    `{"errors":[{"message":"Expected NAME, actual: INT (\\"158\\")"}]}` with NO `data` key at all, so
    one padded ref anywhere in a selected manifest turns the fetch into total failure for every other
    ref -- and the naive degrade then reports it as "gh unreachable", a wrong diagnosis. Such a ref
    could never match a swept item either (the adapter emits `.number|tostring`), so excluding it
    loses nothing and the caller names it in a warning.
    """
    parsed = manifest_core.parse_ref(ref)
    if parsed is None:
        return None
    number = parsed[2]
    try:
        # A REF WHOSE NUMBER OUTGROWS PYTHON'S INTEGER-PARSE LIMIT (~4300 digits by default) must
        # take the same excluded-and-named path a zero-padded one already takes, not raise
        # ValueError out of a module whose header promises nothing in the grid path is ever fatal.
        canonical = number == str(int(number))
    except ValueError:
        return None
    return parsed if canonical else None


def fetch_query(refs: list[str]) -> tuple[str, dict[str, str], list[str]]:
    """`(query, alias -> ref, warnings)` for one batched targeted fetch over `refs`.

    ONE QUERY, NO CHUNKING, AND NO `MAX_CHUNKS` GUARD. Measured on this machine: 10 aliased nodes
    cost 1 rate-limit point and 0.75s, 200 nodes (a 46.8KB query) cost 1 point and 2.11s. The whole
    declared surface across both live manifests is 17 refs. A chunk loop would be dead code that a
    monotonic deadline then has to be threaded through, which is how the deadline gets reset per
    chunk and the budget silently multiplies.

    ALIASES FOLLOW THE ORDER OF `refs`, which declared_refs guarantees is sorted -- so two runs over
    the same manifest with its rows reordered produce a byte-identical query, which is what makes a
    recorded fixture and a diffed log worth anything.

    A ref that cannot go into the document is EXCLUDED AND NAMED rather than dropped silently; see
    _fetchable for the two ways that happens. An empty `refs`, or one where every ref is
    unfetchable, yields an empty query string, and the caller must not spawn anything for it.
    """
    aliases: dict[str, str] = {}
    warnings: list[str] = []
    nodes: list[str] = []
    for ref in refs:
        parts = _fetchable(ref)
        if parts is None:
            warnings.append(f"fetch: ref {ref} is not a fetchable owner/repo#number -- excluded from the fetch")
            continue
        alias = f"n{len(aliases)}"
        aliases[alias] = ref
        nodes.append(_FETCH_NODE.format(alias=alias, owner=parts[0], name=parts[1], number=parts[2]))
    if not nodes:
        return "", {}, warnings
    return "query { " + " ".join(nodes) + " }", aliases, warnings


def fetch_payload_is_usable(payload: object) -> bool:
    """Whether a parsed `gh api graphql` response is an answer at all. The ONLY total-failure test.

    EXIT STATUS IS NEVER CONSULTED (the hardened spec's B5). Verified live: a batch containing one
    bogus repository exits 1, prints its `Could not resolve...` lines to stderr, and still carries
    every valid sibling in `data` with the casualties named per-node in `errors[].path`. Code that
    read `returncode != 0` as total failure would discard a good fetch over one dead ref and render
    exactly the `unknown` AC3 exists to remove.

    "PARSED AS JSON" IS NOT SUCCESS EITHER, and that is the inverse trap -- the one that ships
    silent. Measured: an unauthenticated `gh` exits 1 with stdout
    `{"message":"Bad credentials","status":"401"}`, which is valid JSON with no `data`. `json.loads`
    succeeds, zero refs merge, and without this test the grid looks exactly like a fetch that found
    nothing. A rate limit has the same shape with `data: null`. This mirrors
    recon-adapter-github's own discriminator, `jq -e 'has("data") and (.data != null)'`.
    """
    return isinstance(payload, dict) and payload.get("data") is not None


def fetched_items(payload: dict, aliases: dict[str, str]) -> dict[str, dict]:
    """The fetch's answers keyed by the ORIGINAL declared ref. The `fetched` rung's map.

    KEYED ON THE REF THE CALLER ASKED WITH, never on a slug reconstructed from the parsed parts.
    Reconstruction happens to be byte-identical today (parse_ref's every element is an exact
    substring of its input), but swept_items' rule binds this map too: a key that differs from the
    one `_grid_nodes` looks up never raises -- the node simply renders `unknown` forever, which is
    the precise failure AC3 exists to remove, reintroduced by AC3's own implementation.

    THREE SHAPES OF "MISSING", ALL PER-NODE, ALL ROUTINE, and the second one is the crash. A dead PR
    or issue nulls only the inner field (`{"issueOrPullRequest": null}`); a repository that was
    renamed, deleted or made private nulls the WHOLE ALIAS (`"n2": null`) -- so `data[alias]["..."]`
    raises TypeError out of a module whose header promises nothing in the grid path is ever fatal,
    and cli.main's broad `except` turns that into exit 1 with zero bytes on stdout for every consumer
    that swallows failure. The third is an `errors[]` entry, which is IGNORED for control flow
    entirely: it duplicates what the null already says, and treating it as per-query is B5.

    `state` IS LOWERCASED to match the github adapter's `(.state | ascii_downcase)`, so a node
    resolved by the fetch and the same node resolved by the sweep carry the same token. `issueState`
    is read as a fallback because an Issue's state arrives under the alias the query had to give it.
    """
    data = payload.get("data")
    if not isinstance(data, dict):
        return {}
    items: dict[str, dict] = {}
    for alias, ref in aliases.items():
        node = data.get(alias)
        if not isinstance(node, dict):
            continue
        answer = node.get("issueOrPullRequest")
        if not isinstance(answer, dict):
            continue
        state = _grid_text(answer.get("state")) or _grid_text(answer.get("issueState"))
        if not state:
            continue
        items[ref] = {"ref": ref, "state": state.lower(), "title": _grid_text(answer.get("title"))}
    return items


def replayed_items(nodes: object) -> dict[str, dict]:
    """A recorded fetch's `nodes` map coerced to the item shape, for BORG_LINK_FETCH_FIXTURE.

    Recording the ANSWERS rather than a raw GraphQL body is the one place this seam deliberately
    differs from BORG_LINK_SWEEP_FIXTURE, and the reason is that the two seams sit at different
    depths. The sweep fixture records the fan-out's output because everything interesting downstream
    of it -- the Item validator, the ladder, level assignment -- is still production code. A raw
    GraphQL body would additionally exercise fetch_query's alias numbering, which the harness would
    then have to reproduce by hand in order to write the recording at all: a fixture that has to
    predict `n0..nN` is a fixture that breaks whenever the ref set changes, for reasons unrelated to
    what it is pinning. The parser is covered directly by fetched_items' own cases instead.

    Entries with no usable state are dropped rather than half-merged, so a hand-edited recording
    degrades to the rung below instead of putting an empty token in a node's `state`.
    """
    if not isinstance(nodes, dict):
        return {}
    items: dict[str, dict] = {}
    for ref, node in nodes.items():
        key = _grid_text(ref)
        if not key or not isinstance(node, dict):
            continue
        state = _grid_text(node.get("state"))
        if state:
            items[key] = {"ref": key, "state": state.lower(), "title": _grid_text(node.get("title"))}
    return items


def no_fetch(warnings: list[str] | None = None, requested: int = 0) -> dict:
    """The fetch result for "nothing was asked", carrying the reason. Mirrors no_sweep.

    `attempted: False` is the field that separates "I could not look" from "I looked and found
    nothing", and the two are otherwise byte-identical -- which is exactly the conflation the
    adapter contract's `skipped: true` and track_status' third value were both added to remove.
    Called for `--local`, for a manifest set that declares no ref at all, for a `gh` that is not
    installed, and for a fixture that would not parse.
    """
    return {
        "attempted": False,
        "status": "skipped",
        "requested": requested,
        "items": {},
        "warnings": list(warnings or []),
    }


def fetch_failed(warnings: list[str], requested: int) -> dict:
    """The fetch result for "gh ran and gave nothing usable": offline, unauthenticated, rate-limited,
    or past the deadline. Distinct from no_fetch because something WAS asked and did not answer."""
    return {"attempted": True, "status": "failed", "requested": requested, "items": {}, "warnings": list(warnings)}


def fetch_answered(items: dict[str, dict], requested: int, warnings: list[str] | None = None) -> dict:
    """The fetch result for a usable payload. `ok` when every requested ref came back, else `degraded`.

    The three-valued vocabulary is track_status', reused rather than reinvented: `failed` = nobody
    answered, `degraded` = an answer arrived with holes in it, `ok` = complete. A per-node NOT_FOUND
    is a hole, not a failure, and it earns a named warning of its own so that a grid where half the
    refs quietly fell back to their declared status cannot look like one the fetch resolved.
    """
    missing = max(0, requested - len(items))
    notes = list(warnings or [])
    if missing:
        notes.append(
            f"fetch: {missing} of {requested} declared ref(s) did not resolve"
            " (deleted, renamed, or not visible) -- they fall back to what the manifest declares"
        )
    return {
        "attempted": True,
        "status": "ok" if not missing else "degraded",
        "requested": requested,
        "items": items,
        "warnings": notes,
    }


def selected_refs(manifests: list[dict]) -> list[str]:
    """Every ref the SELECTED manifests declare, deduplicated and sorted. The fetch's input.

    THE UNION IS OVER SELECTED MANIFESTS, NOT DISCOVERED ONES. build_grid only renders what selection
    kept, so a ref from a manifest belonging to another repository is network cost with nowhere to
    land.

    EVERY DECLARED REF IS ASKED ABOUT, INCLUDING ONES THE SWEEP WILL ALSO ANSWER, and that is forced
    rather than lazy. The fetch has to START before the fan-out for its round trip to overlap, so at
    the moment this list is built nothing knows which refs the sweep will cover. Narrowing it to
    "refs the sweep missed" would require the sweep to have finished, which serializes the two and
    costs ~0.9s on a command budgeted at 2.7s. The saving would be nil anyway: cost is flat at one
    rate-limit point from 14 aliased nodes to 112, and the ladder's swept > fetched precedence
    resolves the overlap correctly. Narrowing by BREADTH instead (skip refs in the scoped repository)
    is the same mistake wearing a different hat -- the adapter's `pullRequests(first: 30)` cap means
    an in-scope ref can be outside the sweep too, measured live on `stillpoint-labs/ingle#330`.
    """
    return sorted({ref for manifest in manifests for ref in manifest_core.declared_refs(manifest)})


def scoped_projects(registry: dict, scope: dict) -> dict:
    """The registry's `.projects` narrowed to the scope's SWEEP BREADTH.

    This function is the entire difference between AC1's two measured latencies -- 0.69s for one
    repository, 2.30s for all fourteen. Repository scope yields exactly one entry; orchestrator scope
    yields every entry. A repository named in the scope but absent from (or malformed in) the registry
    yields `{}` rather than falling back to everything: silently widening a narrowed sweep is how a
    reflexive command becomes a 2.3s one with nothing on screen to say why.
    """
    projects = registry.get("projects") or {}
    if scope.get("kind") != "repository":
        return dict(projects)
    entry = projects.get(scope.get("repository") or "")
    return {scope["repository"]: entry} if isinstance(entry, dict) else {}


def repository_dir(registry: dict, scope: dict) -> str:
    """The on-disk directory of the scoped repository, or "" (orchestrator scope, or no usable path).

    "" is the correct answer for orchestrator scope, not a missing one: there is no single repository
    to resolve a slug for, and manifest selection is unscoped there by design (B6 -- discovery is
    global, selection is scoped, and orchestrator scope simply does not narrow).
    """
    if scope.get("kind") != "repository":
        return ""
    entry = (registry.get("projects") or {}).get(scope.get("repository") or "")
    if not isinstance(entry, dict):
        return ""
    path = str(jq_default(entry.get("path"), ""))
    return "" if path == "null" else path


def select_manifests(manifests: list[dict], scope: dict, slug: str) -> tuple[list[dict], list[str]]:
    """B6's selection half: which of the globally-discovered manifests belong to this scope.

    DISCOVERY IS GLOBAL, SELECTION IS SCOPED. `stillpoint/.borg/programs/ingle-t1-cutover.json`
    declares rows across four repositories but lives under exactly one of them; scoping DISCOVERY to
    the repository in hand renders an empty grid in three of the four, which the plan's own risk
    section says "reads as broken". So every registered repository is globbed and the narrowing
    happens here, on what a manifest DECLARES rather than on where its file sits.

    AN UNRESOLVABLE SLUG SELECTS NOTHING, and says so. The tempting degrade -- fall back to showing
    every discovered manifest -- is exactly the B3 failure class this front door exists to remove: it
    would render another project's entire grid under this repository's header, a wrong answer rather
    than a missing one. A directory with no git origin, a plain subdirectory of a checkout, or a
    registry entry with no path all land here.
    """
    if scope.get("kind") != "repository":
        return list(manifests), []
    name = _grid_text(scope.get("repository")) or "?"
    if not slug:
        return [], [f"grid: no owner/repo resolved for '{name}' (no git origin, or not a checkout) -- no grid scoped"]
    selected = manifest_core.select_for_repository(manifests, slug)
    if manifests and not selected:
        return selected, [f"grid: {len(manifests)} manifest(s) discovered, none declaring a row in {slug}"]
    return selected, []


def _grid_nodes(
    manifest: dict, items: dict[str, dict], fetched: dict[str, dict]
) -> tuple[dict[str, dict], list[list[str]]]:
    """`(nodes, levels)` for one manifest. Every DECLARED ref gets a node, not only every row.

    THE NODE SET IS declared_refs, NOT row_refs, and the difference is AC3's whole subject. A row's
    `after` entry or `gate.blocked_by_ref` may name work in another manifest entirely; those are the
    refs that fall outside the sweep window, and they are exactly what the targeted fetch resolves.
    If nodes covered rows only, the fetch would have nowhere to put its answer and `ready_set` could
    never learn a fork parent's state, so every forked row would be permanently not-ready.

    `title` COMES OFF THE WIRE, not from the manifest, and a manifest row has no title field at all
    -- `why` is the author's sentence about the work, `title` is the pull request's own name. It
    falls back from the sweep's item to the fetch's answer in the SAME order the state ladder uses,
    so one node's `state` and `title` can never come from two different round trips. Measured before
    the fetch existed: from /Users/noah/dev/ingle, 13 of 14 nodes carried an empty title.

    `level` IS AN INDEX INTO `levels`, and `levels` is manifest_core.levels' output where the index
    IS the level. Storing the integer on the node too is redundant by construction and deliberately
    so: `drone status`-class consumers read one node and must not have to invert a list of lists to
    learn where it sits.
    """
    refs = manifest_core.declared_refs(manifest)
    ranked = manifest_core.levels(refs, manifest_core.derive_edges(manifest))
    level_of = {ref: index for index, level in enumerate(ranked) for ref in level}
    # KEYED THROUGH _grid_text, NOT ON THE RAW STRING, and the difference is a silent data loss.
    # `declared_refs`, every edge builder and `ready_set` all key on manifest.core's `_text`
    # (`str(x or "").strip()`); `lanes()` hands back the RAW row dicts. Validation does not close the
    # gap either -- `_row_ref_error` strips before calling `parse_ref`, so a hand-authored
    # `"ref": "owner/repo#11 "` with one trailing space validates CLEAN. Keyed raw, the lookup below
    # then misses, `row` becomes `{}`, and that node loses its declared status, lane, order, why and
    # next while reporting `unknown` -- with no warning anywhere, because nothing failed. Measured:
    # a two-row manifest where the parent carried one trailing space announced the startable child as
    # blocked. _grid_text's own docstring states the rule this line used to break.
    rows = {
        _grid_text(row.get("ref")): row for lane_rows in manifest_core.lanes(manifest).values() for row in lane_rows
    }
    gates = {gate["ref"]: gate for gate in manifest_core.gates(manifest)}

    nodes: dict[str, dict] = {}
    for ref in refs:
        row = rows.get(ref) or {}
        item = items.get(ref) or {}
        answer = fetched.get(ref) or {}
        state, source = resolve_state(ref, row.get("status"), items, fetched)
        nodes[ref] = {
            "ref": ref,
            # No isinstance guard, unlike resolve_state's `items.get(ref)`: both maps are `... or {}`
            # above and swept_items/fetched_items only ever store values that already passed
            # isinstance, so the guard that used to sit here could not execute. coverage.py does not
            # instrument conditional expressions, so the floor could never have caught it -- and two
            # visually identical lines, one live and one dead, invite the next editor to delete the
            # live one.
            "title": _grid_text(item.get("title")) or _grid_text(answer.get("title")),
            "state": state,
            "state_source": source,
            "lane": _grid_text(row.get("lane")),
            "order": _grid_text(row.get("order")),
            "why": _grid_text(row.get("why")),
            "next": bool(row.get("next")),
            "gate": gates.get(ref),
            "level": level_of.get(ref, 0),
        }
    return nodes, ranked


def grid_manifest(manifest: dict, items: dict[str, dict], fetched: dict[str, dict]) -> dict:
    """One manifest projected into the grid: its levels, its nodes and its gates.

    GATES ARE gates(), NOT unmapped_gates(). AC4 routes yours-vs-mine off `gate.kind`, and
    unmapped_gates deliberately EXCLUDES the gates that carry a `blocked_by_ref` -- reaching for it
    as the routing source would silently drop exactly the decisions that were careful enough to name
    their blocker.

    `unmapped_gates` IS NOT CARRIED, and the paragraph above is the reason rather than an exception
    to it. It is a pure projection of `gates()` -- same order, filtered to `blocked_by and not
    blocked_by_ref`, minus one key -- so emitting both puts a near-byte-for-byte second copy of every
    gate on a wire `drone status` serializes once per tmux window, for a consumer that does not exist
    and that this docstring already forbids from using it. Both live manifests are 100% prose gates,
    so the second copy is the first copy. AC2's renderer can derive the subset in one comprehension.

    `ready` IS NOT CARRIED EITHER, and that is a deliberate deferral to AC4 rather than an omission.
    Readiness is the routing signal -- "open AND every parent merged" -- and computing it here means
    computing it from a state map that has had its PROVENANCE ERASED: `ready_set` takes
    `{ref: state}`, so a hand-authored `"status": "merged"` and a live GitHub answer are the same
    token to it. Two independent reviews reproduced the consequence: a manifest whose parent row is
    declared merged and whose child is declared open puts the child in `ready`, on the strength of
    two hand-typed fields and a sweep that never saw either ref -- which is precisely the "a merged
    row keeps announcing itself as next" failure the STATE_SOURCE block above says the grid exists to
    remove. The honest alternative (exclude declared-only refs) was no better before AC3: under
    repository scope the sweep covers ONE repository, so on the modal cross-repository manifest every
    parent outside it was `unknown` and `ready` was permanently empty. The `fetched` rung is what
    makes the ladder trustworthy enough to compute readiness from, and it now exists -- but `ready`
    stays AC4's, because the honest version has to decide what a `degraded` fetch means for a parent
    it could not resolve, and that decision belongs with the consumer that reads the answer.
    `manifest_core.ready_set` is untouched and still tested in its own suite.
    """
    nodes, ranked = _grid_nodes(manifest, items, fetched)
    return {
        "id": _grid_text(manifest.get("_id")),
        "path": _grid_text(manifest.get("_path")),
        "levels": ranked,
        "nodes": nodes,
        "gates": manifest_core.gates(manifest),
    }


# JUSTIFICATION (too-many-arguments / too-many-positional-arguments): six INDEPENDENT inputs, and the
# only way under pylint's five is to invent a container that exists to satisfy a counter. `sweep` and
# `fetch` are two different round trips with two different failure vocabularies, and the ladder
# deliberately keeps them apart; `warnings` arrives from discovery and selection, which happen before
# either; `scope` and `slug` are the two halves of B6 (breadth and identity) and collapsing them is
# what B3 was. A `GridInputs` dataclass would move the same six names one line further from the
# docstring that explains them.
# pylint: disable-next=too-many-arguments,too-many-positional-arguments
def build_grid(scope: dict, slug: str, sweep: dict, fetch: dict, manifests: list[dict], warnings: list[str]) -> dict:
    """The document's `grid` key: the scoped repository's declared topology, resolved against a sweep.

    SELF-DESCRIBING ON PURPOSE. `slug`, `scope_kind`, `swept` and `since` are carried so a consumer
    reading only this block can tell an empty grid apart from an un-swept one apart from a
    wrong-repository one, without cross-referencing `.scope`. `drone status` and the fzf preview both
    read a fragment of this document out of context; a block that cannot explain itself becomes a
    blank frame with no diagnosis, which is the exact shape of every silent-blindness incident in
    CLAUDE.md's "Learned".

    WARNINGS ARE NEVER SWALLOWED and never merged into prose. Manifest-discovery warnings, selection
    warnings and sweep warnings all land in one named list, because zero manifests plus zero warnings
    is indistinguishable from a correct empty sweep -- and the renderer is free to show one line or
    none, but it cannot show what the document did not carry.

    `declared` / `unresolved` ARE A NAMED NUMBER FOR THE LADDER'S GAP. `state_source` already tells a
    consumer where ONE node's state came from, but that is per-node, and the question a reader of the
    block actually has is "how much of this grid did anybody actually look at". Without the count, a
    document in which every single state fell back to a hand-authored manifest field looks exactly
    like one that was resolved completely -- same `swept: true`, same `since`. `unresolved` counts
    declared refs whose `state_source` is neither `swept` NOR `fetched`; the targeted fetch is what
    drives it toward zero, and AC3's own verification is an assertion about these nodes.

    `fetch` IS A SIBLING OF `sources`, NEVER A ROW INSIDE IT, and that placement is load-bearing in
    two directions. grid_sources' contract is "one row per ADAPTER" and _track_warning hard-codes the
    word "adapter" into all three of its sentences, so routing the fetch through them would emit a
    false sentence about an adapter that does not exist -- the fetch is deliberately borg_core-side
    precisely so adapters never learn about manifest rows. And tests/link_sweep.bats' latency gate
    ("repository-scoped borg link holds its 2.7s median") guards itself with
    `[.grid.swept, (.grid.sources | length)]` and calls `skip` on a mismatch, not `fail`: appending a
    fetch row would make AC1's only executable latency check turn ITSELF OFF, silently, with a green
    suite.
    """
    items = swept_items(sweep.get("tracks") or [])
    fetched = fetch.get("items") or {}
    grids = [grid_manifest(manifest, items, fetched) for manifest in manifests]
    nodes = [node for grid in grids for node in grid["nodes"].values()]
    return {
        "slug": slug,
        "scope_kind": _grid_text(scope.get("kind")),
        "swept": bool(sweep.get("swept")),
        "since": _grid_text(sweep.get("since")),
        "sources": grid_sources(sweep.get("tracks") or []),
        "fetch": {
            "attempted": bool(fetch.get("attempted")),
            "status": _grid_text(fetch.get("status")) or "skipped",
            "requested": fetch.get("requested") or 0,
            "resolved": len(fetched),
        },
        "manifests": grids,
        "declared": len(nodes),
        "unresolved": sum(1 for node in nodes if node["state_source"] not in RESOLVED_STATE_SOURCES),
        "warnings": list(warnings) + list(sweep.get("warnings") or []) + list(fetch.get("warnings") or []),
    }
