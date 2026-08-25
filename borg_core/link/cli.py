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

from borg_core.link import core, render, shell


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
    # AC1's only opt-down. Inert in S1 -- it records intent in the document's `scope.local` and
    # changes no behavior yet -- but it is wired at the hot call sites NOW (borg.zsh:266's fzf
    # preview, drone.zsh:964's per-window loop) so the protection predates the cost it protects
    # against. Landing the flag with the sweep instead would mean shipping one commit in which
    # every cursor move in `borg switch` fires a network sweep.
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
