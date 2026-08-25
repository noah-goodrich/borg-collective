"""stdlib argparse CLI entrypoint for `borg link` (Phase 3 of the `borg link` port).

Serves all four modes: `--json` (Phase 2), `--porcelain`, `--deep` and the default overview (all
Phase 3). Renders through render.py, which is a pure function of the document this module builds --
unlike borg_core/recon/cli.py:71, the wall clock is read ONCE in the shell tier (shell.now_epoch())
and threaded through every derived field; a second `datetime.now()` call in this file would be the
exact layering smell borg_core/link/shell.py:44-52 names and refuses.
"""

from __future__ import annotations

import argparse
import json as jsonlib
import sys
from typing import NoReturn

from borg_core.link import core, grid, render, shell


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

    `--local` IS CHECKED HERE AND NOWHERE DEEPER. shell.sweep is never called on the opted-down path,
    so no adapter is discovered, no `since` is resolved, no projects file is staged and no subprocess
    of any kind is spawned -- an opt-down that still paid discovery would be a promise the flag does
    not keep, and it is the promise borg.zsh:266's per-keypress preview is relying on.

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
    """
    manifests, warnings = shell.discover_manifests(registry)
    directory = grid.repository_dir(registry, scope)
    slug = shell.repository_slug(directory) if directory else ""
    selected, select_warnings = grid.select_manifests(manifests, scope, slug)
    sweep = (
        grid.no_sweep(["sweep: --local -- states come from what each manifest declares, nothing was fetched"])
        if local
        else shell.sweep(grid.scoped_projects(registry, scope), now=moment)
    )
    return grid.build_grid(scope, slug, sweep, selected, warnings + select_warnings)


def _document(project: str, show_all: bool, mode: str, local: bool = False) -> dict:
    """Assemble the `borg link` document for one invocation, consumed by both `--json` and the three
    renderers in render.py.

    Gathers the two per-registry aggregate collectors (`directives`/`assimilated`, each a
    directory-glob-plus-markdown-read pass over EVERY project) and the single-project `focus` block
    ONLY when the requesting mode's renderer actually reads them: `render.porcelain` reads only
    `order`/`projects`; `render.deep` reads only `focus`; `--json` and the default `overview` read
    everything. Skipping unread work here matters because `_document` is READ-ONLY but re-executed
    per call site -- drone.zsh:964 calls it once per tmux window inside cmd_status's loop, and
    borg.zsh's fzf preview re-executes it synchronously on every cursor move.

    CORRECTION (S1): an earlier version of this docstring said the fzf preview runs `--porcelain`.
    It does not, and the error was load-bearing -- it was cited downstream as proof that the preview
    was already protected from expensive work. borg.zsh:262 uses `cmd_ls --porcelain` to build the
    picker's INPUT LIST, exactly once. borg.zsh:266 is `--preview "borg link {1}"`, and a bare
    positional routes through _borg_link_dispatch to `--deep`. So the mode re-executed on every
    cursor move is DEEP, and `deep` is therefore a hot loop, not a cold one. Any future work that
    puts network or sweep cost behind a mode must treat `deep` as hot and opt the preview down
    explicitly (borg.zsh:266 now passes `--local`), never assume mode gating protects it.

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
    archived filter; (iv) when the aggregate collectors run, registry.json is read a SECOND time
    (`raw`, bare, alongside the state-overlaid `overlaid`) on purpose, because borg.zsh:163 feeds them
    borg_registry_read (the RAW registry), not the state-overlaid one; do not collapse it into one
    read; (v) `total_projects` is `len(overlaid.get("projects"))`, computed from the UNFILTERED
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

    need_aggregate = mode in ("json", "overview")
    need_focus = mode in ("json", "deep")

    directives: list[dict] = []
    assimilated: list[dict] = []
    cortex_pending: list[dict] = []
    if need_aggregate:
        raw = shell.read_registry()
        directives = shell.collect_all_directives(raw)
        assimilated = shell.collect_all_assimilated(raw)
        cortex_pending = shell.cortex_pending(now=moment)

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
        focus=_focus(project, overlaid, moment) if need_focus else None,
        scope=scope,
        grid=_grid(overlaid, scope, local, moment),
    )


def _run(project: str, show_all: bool, mode: str, local: bool = False) -> int:
    """Dispatch one `borg link` invocation; returns the process exit code.

    Mode precedence, strictly: json > porcelain > deep > overview. Renders to a SINGLE string and
    prints it ONCE -- never streams a renderer's output incrementally, so a mid-render exception
    yields zero bytes on stdout, never a half-frame (every consumer here swallows failure: cmd_watch's
    `|| true`, drone status's `|| true`, fzf's preview pane).
    """
    doc = _document(project, show_all, mode, local)
    if mode == "json":
        print(jsonlib.dumps(doc))
        return 0
    if mode == "porcelain":
        print(render.porcelain(doc), end="")
        return 0
    if mode == "deep":
        print(render.deep(doc), end="")
        return 0
    print(render.overview(doc), end="")
    return 0


def _build_parser() -> argparse.ArgumentParser:
    """Build the stdlib argparse parser for all four `borg link` modes."""
    parser = argparse.ArgumentParser(prog="borg link", description="Emit the borg link document.")
    parser.add_argument("project", nargs="?", default="")
    parser.add_argument("--json", dest="json_only", action="store_true")
    parser.add_argument("--porcelain", dest="porcelain", action="store_true")
    parser.add_argument("--deep", dest="deep", action="store_true")
    parser.add_argument("--all", dest="show_all", action="store_true")
    # AC1's ONLY opt-down, and as of S3 it is no longer inert. It makes `_grid` call grid.no_sweep()
    # instead of shell.sweep(), so no adapter is discovered, no `since` is resolved and NO SUBPROCESS
    # of any kind is spawned -- the grid still renders, from what each manifest declares. It is the
    # sole protection for every hot loop in the tree: borg.zsh:266's per-keypress fzf preview,
    # borg.zsh:2225's 5s watch redraw, drone.zsh:964's per-tmux-window loop, bin/link-parity-harness's
    # 34 invocations, and skills/borg-switch's widest-breadth `--all` call.
    #
    # THIS COMMENT USED TO SAY "changes no behavior yet". It was true in S1 and false the moment the
    # sweep landed, and leaving it would have repeated the exact defect the hardened spec's B1 is:
    # a stale comment about `borg link`'s cost, cited downstream as proof of a protection that was
    # not there. Anyone reading this as dead plumbing and deleting a `--local` from a call site is
    # removing a network sweep's only brake.
    parser.add_argument("--local", dest="local", action="store_true")
    return parser


def _mode(args: argparse.Namespace) -> str:
    if args.json_only:
        return "json"
    if args.porcelain:
        return "porcelain"
    if args.deep:
        return "deep"
    return "overview"


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
    registry root) to fall through as a raw traceback on stdout -- verified live before this fix.
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
