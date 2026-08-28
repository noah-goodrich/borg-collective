"""stdlib argparse CLI entrypoint for `borg link`.

THREE MODES, NOT FOUR: `--json`, `--porcelain`, and the one human document. `--deep` collapsed into
repository scope in AC2 and is now parsed and ignored (see `_build_parser`). Renders through
render.py, which is a pure function of the document this module builds -- unlike
borg_core/recon/cli.py:71, the wall clock is read ONCE in the shell tier (shell.now_epoch()) and
threaded through every derived field; a second `datetime.now()` call in this file would be the exact
layering smell borg_core/link/shell.py:44-52 names and refuses.
"""

from __future__ import annotations

import argparse
import json as jsonlib
import os
import sys
from typing import NoReturn

from borg_core.link import core, grid, picture, render, shell


class ProjectNotFound(Exception):
    """Raised by `_focus` when the requested project is not in the registry.

    `_focus` does NOT call a `_die*` helper itself -- it sits two frames deep inside `_document()`,
    which is shared by all four modes and must stay mode-agnostic. The single exception boundary in
    `_run`/`main` is the only place that already knows which mode is running, and therefore the only
    place allowed to decide which `_die*` format applies.
    """

    def __init__(self, project: str):
        super().__init__(project)
        self.project = project


def _die_json(message: str) -> NoReturn:
    """The `--json` failure shape: `borg link: {message}` on stderr, no ANSI. Correct for a machine
    consumer -- unchanged from Phase 2."""
    print(f"borg link: {message}", file=sys.stderr)
    raise SystemExit(1)


def _die_human(message: str) -> NoReturn:
    """The three human modes' failure shape, reproducing zsh's `die` helper byte for byte
    (borg.zsh:31): `\\033[0;31m▸ ERROR:\\033[0m {message}` on stderr, exit 1, zero bytes on stdout.
    """
    print(f"\033[0;31m▸ ERROR:\033[0m {message}", file=sys.stderr)
    raise SystemExit(1)


def _focus(project: str, registry: dict, now_epoch: int) -> dict | None:
    """The `focus` block for a requested project, or None when no project was given.

    Looks `project` up in the FULL overlaid registry (NOT the --all-filtered map), so
    `borg link --json <archived-project>` behaves like `borg link <archived-project>` does today.
    Raises ProjectNotFound on a miss rather than dying itself -- see ProjectNotFound's docstring.
    """
    if not project:
        return None
    projects = registry.get("projects") or {}
    entry = projects.get(project)
    if entry is None:
        raise ProjectNotFound(project)
    return {
        "name": project,
        "entry": core.public_entry(entry, now_epoch),
        "plan": shell.read_plan(entry.get("path")),
        "checkpoints": shell.read_checkpoints(entry.get("path")),
        "checkpoint_head": shell.read_latest_checkpoint_head(entry.get("path")),
        "directives": shell.read_directives(entry.get("path")),
        "assimilated": shell.read_assimilated(entry.get("path")),
    }


def _grid(registry: dict, scope: dict, local: bool, moment: int) -> dict:
    """The `grid` block: discover manifests globally, select them scoped, sweep at the scope's breadth.

    THE ORDER OF THE THREE STEPS IS FIXED and each one's breadth is different, which is the whole of
    the hardened spec's B6. Discovery globs EVERY registered repository (a local pass over ~14
    directories, milliseconds) because a manifest declaring rows across four repositories lives under
    exactly one of them. Selection then narrows on what a manifest DECLARES, using the scoped
    repository's `owner/repo`. The sweep's breadth is narrower still -- one registry entry in
    repository scope -- and that is the difference between AC1's 0.69s and its 2.30s.

    THE SLUG COSTS A `git remote get-url`, and only in repository scope. That subprocess is why
    `--local` still calls this function rather than skipping it: `--local` opts down from the NETWORK,
    not from local truth. The fzf preview and `drone status` want the declared topology; what they
    cannot afford is `gh`.

    `--local` IS CHECKED HERE AND NOWHERE DEEPER, and as of AC3 it is checked TWICE, once per network
    path. shell.sweep is never called on the opted-down path, and neither is shell.start_fetch -- so
    no adapter is discovered, no `since` is resolved, no projects file is staged, no `gh` is spawned
    and no subprocess of any kind runs. An opt-down that still paid for one of the two would be a
    promise the flag does not keep, and it is the promise borg.zsh:266's per-keypress preview, the 5s
    `borg watch` redraw and drone.zsh's per-tmux-window loop are all relying on.

    THE FETCH'S GUARD HAS TO BE ITS OWN, and this is the trap in the shape rather than an aside. The
    fetch must START before the sweep for its round trip to overlap, so it sits ABOVE the sweep's
    `local` ternary and is not covered by it. An implementer who inserts the start at the right line
    without the guard makes `borg link --local` spawn `gh` on every cursor move -- which is the
    hardened spec's B1, re-committed. tests/link_sweep.bats' first case ("borg link --local spawns
    zero gh subprocesses, and the same call without it sweeps") is what notices.

    THE FETCH IS UNCONDITIONAL OTHERWISE, over every ref every SELECTED manifest declares. It cannot
    be narrowed to "refs the sweep missed" without waiting for the sweep, which is the serialization
    the overlap exists to avoid; see grid.selected_refs for the measurement that makes narrowing
    worthless anyway.

    `moment` IS THE DOCUMENT'S ONE EPOCH, threaded down so the sweep mark is cut from the same
    instant as `generated_at` and every relative time. A second clock read here would let a document
    state a `since` that does not correspond to its own `generated_at`.

    KNOWN AND ACCEPTED COST, recorded rather than gated: this function is not mode-gated, so
    `drone status` pays one `git remote get-url` per tmux window plus a `.borg/programs` listdir per
    registered repository per window. Measured at 12 windows against a 14-repository registry that is
    12 forks and ~168 listdirs for a table that greps one `Status:` line. It is bounded, it is local,
    and the two obvious "fixes" are both worse: mode-gating the grid is what B1's rejected alternative
    was rejected for (two modes of one command answering the same question with different data, and
    `--json` MUST carry the grid for AC3's verification), and per-process memoization buys nothing for
    a caller that forks a fresh process per window. AC2, which is the step that gives the renderer a
    reason to read the grid, is the right place to revisit the shape of this loop.

    `picture_width` IS STAMPED HERE AND NOT IN `grid.build_grid`, WHICH OWNS EVERY OTHER KEY IN THE
    BLOCK. build_grid cannot: `grid.py` is pure Domain and `picture.py` already imports `grid`, so
    `grid` importing `picture` is a hard cycle -- the exact one picture.py exists on the other side
    of. This module is the impure boundary the width-check directive nominates, for the same reason it
    owns BrokenPipeError. The measurement itself is `picture.max_row_width`, pure; only the decision
    to publish it is here.

    NESTED UNDER `grid`, NOT AT THE TOP LEVEL, and that is a wire fact rather than taste:
    `skills/borg-link/SKILL.md` pipes the document through a `jq` whitelist that selects `grid`
    wholesale, so a nested key rides through and a top-level one is silently dropped on the skill's
    own path.

    `DOCUMENT_VERSION` STAYS 2. Purely additive inside an additive block, no pre-existing key narrows
    -- the same terms `scope`, `grid` and AC4's `ready`/`draft` took. Bumping would fire the skill's
    version-skew warning for a document it can still read perfectly. AC4's amendment ("the wire is not
    additive when a renderer is already reading the key it adds") is checked and clears: no renderer
    read `picture_width` before this change, and `_width_line` is silent at and below the budget, so
    no golden moves.

    KNOWN AND ACCEPTED COST, recorded rather than memoized: on the human path the picture is now
    rasterized twice -- once here for the width, once in `render._grid_section` for the rows. Both are
    pure and in-memory over at most a dozen nodes, and the hot loops that would have made it matter
    (the fzf preview, `borg watch`, `drone status`) were retired on 2026-08-27. A cache keyed on the
    manifest list is more moving parts than the cost it removes.
    """
    manifests, warnings = shell.discover_manifests(registry)
    directory = grid.repository_dir(registry, scope)
    slug = shell.repository_slug(directory) if directory else ""
    selected, select_warnings = grid.select_manifests(manifests, scope, slug)
    # STARTED HERE, COLLECTED BELOW, WITH THE BLOCKING FAN-OUT BETWEEN THEM. `selected` is the first
    # line at which the ref set exists and the sweep is the next thing that blocks, so this is the
    # only pair of lines where the overlap is free. The `--local` result carries no warning of its
    # own: the sweep's already says "nothing was fetched", and two lines saying the same thing is
    # noise on the mode fzf re-renders per keypress.
    pending = None if local else shell.start_fetch(grid.selected_refs(selected))
    sweep = (
        grid.no_sweep(["sweep: --local -- states come from what each manifest declares, nothing was fetched"])
        if local
        else shell.sweep(grid.scoped_projects(registry, scope), now=moment)
    )
    fetch = grid.no_fetch() if pending is None else shell.finish_fetch(pending)
    block = grid.build_grid(scope, slug, sweep, fetch, selected, warnings + select_warnings)
    block["picture_width"] = picture.max_row_width(block["manifests"])
    return block


def _aggregates(wanted: bool) -> tuple[list[dict], list[dict]]:
    """The two per-registry aggregate collectors, or two empty lists when nothing will read them.

    THE REGISTRY IS READ A SECOND TIME HERE, BARE, and that is deliberate rather than a missed
    dedup: borg.zsh:163 feeds these two collectors `borg_registry_read` (the RAW registry), not the
    state-overlaid one `_document` already holds. Collapsing the two reads changes which snapshot
    the aggregates describe. Kept as its own function so `raw` cannot leak into `_document`, whose
    locals are otherwise at pylint's ceiling.
    """
    if not wanted:
        return [], []
    raw = shell.read_registry()
    return shell.collect_all_directives(raw), shell.collect_all_assimilated(raw)


def _document(project: str, show_all: bool, mode: str, local: bool = False) -> dict:
    """Assemble the `borg link` document for one invocation, consumed by `--json`, `--porcelain` and
    the one human renderer.

    BREADTH IS APPLIED HERE AND NARROWED IN THE RENDERER, WHICH IS WHY `DOCUMENT_VERSION` STAYS 2.
    core.assemble's docstring prices a version bump at the moment a PRE-EXISTING key narrows; under
    AC2 none does. The `--json` wire is byte-compatible with v2 from any cwd (see `need_aggregate`
    below), and what "scope" changes is which ROWS render.document prints, not what the document
    carries.

    Skipping unread work still matters, because `_document` is READ-ONLY but re-executed per call
    site: drone.zsh:964 calls it once per tmux window inside cmd_status's loop, and borg.zsh's fzf
    preview re-executes it synchronously on every cursor move. Both of those pass a NAME, so both are
    repository scope, so both skip the 14-project `directives`/`assimilated` glob exactly as the old
    `deep` mode did -- net latency delta zero, plus one ~40-line file read (`cortex_pending`).

    CORRECTION (S1), still true: an earlier version of this docstring said the fzf preview runs
    `--porcelain`. It does not, and the error was load-bearing -- it was cited downstream as proof
    that the preview was already protected from expensive work. borg.zsh:262 uses `cmd_ls
    --porcelain` to build the picker's INPUT LIST, exactly once. borg.zsh:266 is `--preview "borg
    link --local {1}"`, and a bare positional routes through _borg_link_dispatch. So the mode
    re-executed on every cursor move is the HUMAN one, and it is a hot loop, not a cold one. Any
    future work that puts network or sweep cost behind a mode must treat it as hot and opt the
    preview down explicitly, never assume mode gating protects it.

    THE GRID IS DELIBERATELY NOT MODE-GATED (S3), unlike everything above. Skipping unread work is
    the rule for `directives`/`assimilated`/`focus` because those are display sections a given
    renderer either prints or does not. The grid is not a section, it is the DERIVED FACT the front
    door exists to serve, and gating it by mode would reconstitute exactly what B1's rejected
    alternative was rejected for: two modes of one command answering the same question with different
    data. `--json` in particular must always carry it -- AC3's verification is an assertion over
    `.grid.manifests[].nodes[].state` with no renderer involved. The cost of carrying it on a mode
    that does not print it is bounded and known: a local directory glob, plus one `git remote get-url`
    in repository scope, plus a sweep that `--local` removes at every hot call site.

    FIVE further judgment calls, unchanged from before this function became mode-aware: (i)
    `shell.now_epoch()` is called EXACTLY ONCE and threaded into registry_with_state, format_iso,
    visible_projects, public_entry and cortex_pending -- a second clock read would let a countdown
    and a relative time in one document describe different instants; (ii) registry_with_state() is
    called exactly ONCE (it forks tmux and globs every project's state.json; two calls give two
    snapshots and make the table, the order and the active count disagree -- the bug shell.py's
    registry_with_state docstring says the port fixed); (iii) `core.active_count` runs on the
    UNFILTERED overlaid registry, matching _borg_active_count (borg.zsh:115), which never applied the
    archived filter; (iv) when the aggregate collectors run, registry.json is read a SECOND time --
    bare, inside `_aggregates`, alongside the state-overlaid `overlaid` here -- on purpose, because
    borg.zsh:163 feeds them borg_registry_read (the RAW registry), not the state-overlaid one; do not
    collapse it into one read; (v) `total_projects` is `len(overlaid.get("projects"))`, from the UNFILTERED
    overlaid map -- NOT from `projects` (the --all-filtered map) or `order`.
    """
    moment = shell.now_epoch()
    overlaid = shell.registry_with_state(now=moment)
    projects = core.visible_projects(overlaid, show_all, moment)
    order = core.order_projects(projects)

    # Scope is computed from the UNFILTERED overlaid registry, not `projects`: --all is a display
    # filter, and an archived repository is still the repository you are standing in. Resolving
    # scope against the filtered map would make `borg link` inside an archived repository silently
    # report orchestrator breadth.
    scope = core.scope_for(
        shell.cwd(),
        shell.orchestrator_root(),
        shell.resolved_project_paths(overlaid),
        local=local,
        requested_project=project,
    )

    # `bool(project) or ...` AND NOT A PURELY SCOPE-DERIVED TEST. scope_for honours a positional only
    # when it is IN THE REGISTRY; an unregistered name deliberately falls through to cwd resolution
    # and yields kind="orchestrator". Gating focus on scope alone therefore DELETES the
    # ProjectNotFound path for `borg link ghost` from any cwd outside a registered repository -- exit
    # 0 with a full board instead of exit 1. cli_contract.bats' "link <project> dies non-zero on a
    # project that is not registered" and test_cli.py's three ProjectNotFound cases are the evidence,
    # and they are untouched by AC2 on purpose.
    need_focus = mode != "porcelain" and (bool(project) or scope["kind"] == "repository")
    # COMPUTED ABOVE THE AGGREGATE BLOCK, and the hoist is load-bearing rather than tidy. `_focus`
    # raises ProjectNotFound before anything else runs, which is what keeps a tmux window name that
    # is not a registry key as cheap as it is today (drone.zsh:964 calls this once per window). Below
    # the aggregates, that same miss would first pay a 14-project directives-and-assimilated glob.
    #
    # `project or scope["repository"]` IS THE FIX FOR THE MODAL HUMAN INVOCATION. `_focus`
    # short-circuits on an empty positional, so passing `project` alone would make `cd <repo> &&
    # borg link` -- no argument at all -- render the IN FOCUS placeholder, no `Status:` line, and
    # empty QUEUED/SHIPPED for a repository with directives on disk. The golden harness renders
    # repository context BOTH ways against the SAME golden so no future edit can un-fix it.
    focus = _focus(project or scope.get("repository") or "", overlaid, moment) if need_focus else None

    # `--json` IS SCOPE-INDEPENDENT, and that is the actual precondition for not bumping
    # DOCUMENT_VERSION. skills/borg-link/SKILL.md runs a bare `borg link --json | jq '.directives |=
    # (...)'`, and only borg-collective carries a `.borg-project` marker, so that call routes from
    # INSIDE whatever repository the session is in. Scope-gating the aggregates would report
    # "Queued: 0 directives" for the whole collective at `.version == 2` -- which SKILL.md maps to
    # "CLI path. Never fall back." A wrong answer, not a missing one. Neither hot loop is `--json`.
    need_aggregate = mode == "json" or (mode != "porcelain" and scope["kind"] == "orchestrator")

    directives, assimilated = _aggregates(need_aggregate)
    # NOT gated with the aggregates any more: the cortex pause row hangs off a BOARD row, and the
    # board renders in both contexts. It is a single ~40-line file read (shell.cortex_pending), not a
    # per-project glob, so it is priced with the render rather than with the aggregates.
    cortex_pending = [] if mode == "porcelain" else shell.cortex_pending(now=moment)

    return core.assemble(
        generated_at=core.format_iso(moment),
        show_all=show_all,
        total_projects=len(overlaid.get("projects") or {}),
        capacity=core.capacity(core.active_count(overlaid), shell.max_active()),
        projects=projects,
        order=order,
        directives=directives,
        assimilated=assimilated,
        cortex_pending=cortex_pending,
        focus=focus,
        scope=scope,
        grid=_grid(overlaid, scope, local, moment),
    )


def _emit(text: str) -> int:
    """Print one already-complete string, and survive a consumer that stopped reading.

    SIGPIPE IS CAUGHT HERE AND NEVER IN render.py, WHICH STAYS PURE. The seven-section document is
    substantially larger than the deep dive it replaces and can exceed the 64KB pipe buffer, so
    `borg link | grep -m1 Status:` -- grep exits on its first match -- can leave this `print` writing
    into a closed pipe. Uncaught, CPython prints a BrokenPipeError traceback, and drone.zsh's status
    table would merge it into a column. Redirecting the remaining stdout at devnull is the documented
    idiom (Python's own `signal` HOWTO): closing or leaving it alone makes the interpreter emit
    "Exception ignored in: <_io.TextIOWrapper ...>" at shutdown instead, which is the same leak by a
    different route.
    """
    try:
        print(text, end="")
        # JUSTIFICATION: this process's own standard stream, not a caller-supplied collaborator.
        sys.stdout.flush()  # pylint: disable=clean-arch-demeter
    except BrokenPipeError:
        # JUSTIFICATION: same stream, and this line is the documented CPython idiom verbatim.
        os.dup2(os.open(os.devnull, os.O_WRONLY), sys.stdout.fileno())  # pylint: disable=clean-arch-demeter
    return 0


def _run(project: str, show_all: bool, mode: str, local: bool = False) -> int:
    """Dispatch one `borg link` invocation; returns the process exit code.

    Mode precedence, strictly: json > porcelain > human. Renders to a SINGLE string and prints it
    ONCE -- never streams a renderer's output incrementally, so a mid-render exception yields zero
    bytes on stdout, never a half-frame (every consumer here swallows failure: cmd_watch's `|| true`,
    drone status's `|| true`, fzf's preview pane).

    ONE HUMAN ARM, ONE RENDERER CALL. `render.document` is named exactly once in this function, and
    test_render.py asserts that on the source text: a second call site is how "one front door" decays
    back into two modes of one command answering the same question with different data.
    """
    doc = _document(project, show_all, mode, local)
    if mode == "json":
        return _emit(jsonlib.dumps(doc) + "\n")
    if mode == "porcelain":
        return _emit(render.porcelain(doc))
    return _emit(render.document(doc))


def _build_parser() -> argparse.ArgumentParser:
    """Build the stdlib argparse parser for all four `borg link` modes."""
    parser = argparse.ArgumentParser(prog="borg link", description="Emit the borg link document.")
    parser.add_argument("project", nargs="?", default="")
    parser.add_argument("--json", dest="json_only", action="store_true")
    parser.add_argument("--porcelain", dest="porcelain", action="store_true")
    # PARSED AND IGNORED SINCE AC2, AND IT MUST STAY THAT WAY. `--deep` collapsed into repository
    # scope -- scope_for already resolves `borg link <project>` to {kind: repository}, so the one
    # document says everything the deep dive said, and keeping it as a MODE would be a third context
    # rendering the same data, which is exactly what "the contexts differ in breadth only" forbids.
    # It stays in the parser because ONE LIVE COPY OF THE DISPATCHER PASSES IT, and it is the worst
    # one to break: borg.zsh's `_borg_link_dispatch` positional arm (borg.zsh:3111), which IS the fzf
    # preview's path, re-executed on every cursor move. Delete the argument and argparse exits 2
    # where `drone status` and the fzf preview both swallow the failure silently -- a blank pane and
    # a blank column, with nothing on stderr anyone would see.
    #
    # THE COUNT WAS CORRECTED IN AC2/S4. It used to say THREE copies, naming bin/link-parity-harness
    # and the byte-copy at ~/.claude/bin/link-parity-harness alongside borg.zsh. Neither ever passed
    # `--deep`: the harness looped a bare POSITIONAL (`modes.extend(("deep:" + p, [p]) ...)`), and
    # `git log -S -- bin/link-parity-harness` finds the flag in no revision of that file. The two
    # phantom copies were wrong from the commit that wrote them; S4 then retired the harness's render
    # leg, so they are now gone twice over. The justification does not weaken by losing them -- one
    # copy on the path that swallows the failure silently was always the entire argument.
    parser.add_argument("--deep", dest="deep", action="store_true")
    parser.add_argument("--all", dest="show_all", action="store_true")
    # AC1's ONLY opt-down, and as of S3 it is no longer inert. It makes `_grid` call grid.no_sweep()
    # instead of shell.sweep(), so no adapter is discovered, no `since` is resolved and NO SUBPROCESS
    # of any kind is spawned -- the grid still renders, from what each manifest declares. It is the
    # sole protection for every hot loop in the tree: borg.zsh:266's per-keypress fzf preview,
    # borg.zsh:2225's 5s watch redraw, drone.zsh:964's per-tmux-window loop, and
    # skills/borg-switch's widest-breadth `--all` call. (bin/link-parity-harness's 34 invocations
    # were the fifth until AC2/S4 retired the render leg that made them; the surviving `primitives`
    # leg spawns no `borg` subcommand at all.)
    #
    # THIS COMMENT USED TO SAY "changes no behavior yet". It was true in S1 and false the moment the
    # sweep landed, and leaving it would have repeated the exact defect the hardened spec's B1 is:
    # a stale comment about `borg link`'s cost, cited downstream as proof of a protection that was
    # not there. Anyone reading this as dead plumbing and deleting a `--local` from a call site is
    # removing a network sweep's only brake.
    parser.add_argument("--local", dest="local", action="store_true")
    return parser


def _mode(args: argparse.Namespace) -> str:
    """THREE MODES, not four: `json`, `porcelain`, `human`. `args.deep` is deliberately not read --
    see `_build_parser` for why the flag still exists."""
    if args.json_only:
        return "json"
    if args.porcelain:
        return "porcelain"
    return "human"


def main(argv: list[str] | None = None) -> None:
    """Entrypoint for `python3 -m borg_core.link.cli`.

    A SINGLE exception boundary, formatter chosen by mode: `_die_json` for `--json` (no ANSI, the
    `borg link: {message}` shape a machine consumer can rely on), `_die_human` for the three human
    modes. Both die formatters print to stderr and exit 1 with zero bytes on stdout -- A3 depends on
    `--json` never leaking a traceback onto stdout, so the catch here must be as broad as the human
    path's always was. A syntactically-valid registry with a non-dict project entry (e.g.
    `{"projects":{"foo":null}}`, a plausible partial-write artifact) raises AttributeError from
    core.py's `entry.items()`/`entry.get()` -- not ValueError, not OSError, and NOT ProjectNotFound.
    borg_core/registry/shell.py already wraps JSONDecodeError in ValueError, so corrupt JSON was
    never the uncovered case; a narrow `except (ValueError, OSError)` on the `--json` path left every
    entry-shape violation (null entry, list entry, string entry, non-dict `projects`, non-dict
    registry root) to fall through as an UNCAUGHT TRACEBACK -- stderr, exit 1, and no document.

    THAT CLAUSE USED TO NAME THE WRONG STREAM -- it said the traceback landed on the OUT stream,
    "verified live before this fix" -- and it could only ever have been wrong: Python writes an
    uncaught traceback to STDERR, always, so no live run could have produced what it claimed. Filed
    as F2 of `docs/plans/directives/2026-08-16-link-port-latent-defects.md`, corrected here. The
    justification for the broad `except` does not depend on it and is untouched: what a `--json`
    consumer gets from an uncaught AttributeError is an EMPTY out stream and a non-zero exit carrying
    no machine-readable reason, and `_die_json` exists to make that a parseable failure instead.

    This is the ONLY exception boundary in this module, placed here because `_run`/`main` is the
    only point that already knows the mode.
    """
    args = _build_parser().parse_args(argv)
    mode = _mode(args)
    die = _die_json if mode == "json" else _die_human
    try:
        exit_code = _run(args.project, args.show_all, mode, args.local)
    except ProjectNotFound as exc:
        die(_not_found_message(exc))
    # JUSTIFICATION: entry-shape violations raise AttributeError, not ValueError/OSError; must die clean.
    except Exception as exc:  # pylint: disable=broad-except
        die(str(exc))
    raise SystemExit(exit_code)


def _not_found_message(exc: ProjectNotFound) -> str:
    return f"project '{exc.project}' not in registry. Run: borg add [path]"


if __name__ == "__main__":
    main()
