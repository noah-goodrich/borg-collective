"""stdlib argparse CLI entrypoint for `borg link --json` (Phase 2 of the `borg link` port).

This ports NO renderer. cmd_link's three human modes (porcelain/overview/deep) still render in zsh
and must stay byte-identical until Phase 3 flips all three atomically. The only mode served here is
`--json`. Unlike borg_core/recon/cli.py:71, the wall clock is read ONCE in the shell tier
(shell.now_epoch()) and threaded through every derived field -- not read again here; a `datetime.now()`
call in this file would be the exact layering smell borg_core/link/shell.py:44-52 names and refuses.
"""

from __future__ import annotations

import argparse
import json as jsonlib
import sys
from typing import NoReturn

from borg_core.link import core, shell


def _die(message: str) -> NoReturn:
    """Print an error to stderr and exit non-zero, mirroring the zsh `die` helper.

    The zsh version prints `▸ ERROR: ` with ANSI color, deliberately not reproduced on a
    machine-readable path.
    """
    print(f"borg link: {message}", file=sys.stderr)
    raise SystemExit(1)


def _focus(project: str, registry: dict, now_epoch: int) -> dict | None:
    """The `focus` block for a requested project, or None when no project was given.

    Looks `project` up in the FULL overlaid registry (NOT the --all-filtered map), so
    `borg link --json <archived-project>` behaves like `borg link <archived-project>` does today.
    Dies with the deep dive's message on a miss. Does NOT reproduce _borg_link_deep's
    `project="${PWD##*/}"` fallback: in cmd_link an empty positional means overview, so that branch
    is unreachable here.
    """
    if not project:
        return None
    projects = registry.get("projects") or {}
    entry = projects.get(project)
    if entry is None:
        _die(f"project '{project}' not in registry. Run: borg add [path]")
    return {
        "name": project,
        "entry": core.public_entry(entry, now_epoch),
        "plan": shell.read_plan(entry.get("path")),
        "checkpoints": shell.read_checkpoints(entry.get("path")),
        "checkpoint_head": shell.read_latest_checkpoint_head(entry.get("path")),
        "directives": shell.read_directives(entry.get("path")),
        "assimilated": shell.read_assimilated(entry.get("path")),
    }


def _document(project: str, show_all: bool) -> dict:
    """Assemble the full `borg link --json` document for one invocation.

    FOUR judgment calls: (i) `shell.now_epoch()` is called EXACTLY ONCE and threaded into
    registry_with_state, format_iso, visible_projects, public_entry and cortex_pending -- a second
    clock read would let a countdown and a relative time in one document describe different
    instants; (ii) registry_with_state() is called exactly ONCE (it forks tmux and globs every
    project's state.json; two calls give two snapshots and make the table, the order and the active
    count disagree -- the bug shell.py's registry_with_state docstring says the port fixed);
    (iii) `core.active_count` runs on the UNFILTERED overlaid registry, matching _borg_active_count
    (borg.zsh:115), which never applied the archived filter; (iv) registry.json is read TWICE on
    purpose -- once inside registry_with_state and once bare for the two collectors, because
    borg.zsh:163 feeds them borg_registry_read (the RAW registry), not the state-overlaid one; do
    not collapse it into one read.
    """
    moment = shell.now_epoch()
    overlaid = shell.registry_with_state(now=moment)
    raw = shell.read_registry()
    projects = core.visible_projects(overlaid, show_all, moment)
    order = core.order_projects(projects)
    return core.assemble(
        generated_at=core.format_iso(moment),
        show_all=show_all,
        capacity=core.capacity(core.active_count(overlaid), shell.max_active()),
        projects=projects,
        order=order,
        directives=shell.collect_all_directives(raw),
        assimilated=shell.collect_all_assimilated(raw),
        cortex_pending=shell.cortex_pending(now=moment),
        focus=_focus(project, overlaid, moment),
    )


def _run(project: str, show_all: bool, json_only: bool) -> int:
    """Dispatch one `borg link` invocation; returns the process exit code."""
    if not json_only:
        _die("only --json is implemented in Python; the human renderers are still zsh (Phase 3)")
    print(jsonlib.dumps(_document(project, show_all)))
    return 0


def _build_parser() -> argparse.ArgumentParser:
    """Build the stdlib argparse parser for the `--json` seam."""
    parser = argparse.ArgumentParser(prog="borg link", description="Emit the borg link document as JSON.")
    parser.add_argument("project", nargs="?", default="")
    parser.add_argument("--json", dest="json_only", action="store_true")
    parser.add_argument("--all", dest="show_all", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> None:
    """Entrypoint for `python3 -m borg_core.link.cli`."""
    args = _build_parser().parse_args(argv)
    try:
        exit_code = _run(args.project, args.show_all, args.json_only)
    except ValueError as exc:
        _die(str(exc))
    raise SystemExit(exit_code)


if __name__ == "__main__":
    main()
