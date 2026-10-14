"""`python3 -m borg_core.link.overlay`: the registry with state.json and the reap overlay applied, as JSON.

THE ONE STATE OVERLAY. `borg link` builds its view with `shell.registry_with_state`; `borg next` used to build
its own with the zsh `borg_registry_with_state` and hand that to nextpick, so the two commands read the same
registry through two readers. This is the seam that ends it: `borg next` pipes THIS output into nextpick, so a
session that `borg link` shows as waiting is a session `borg next` sees as waiting, by construction rather than
by two implementations staying in step. Fail loud: a traceback on stderr and a non-zero exit, never a plausible
empty registry (the zsh caller turns that into a visible `die`).

THE ONE SUMMARY READ TOO. The registry's stored `summary` is a transcript heuristic written once at session end,
stale once a newer checkpoint lands, so no reader prints it. `with_checkpoint_summaries` replaces every
repository's `summary` with its newest checkpoint's tl;dr (else its first Accomplished bullet, else null), from
the directory's OWN checkpoints, and `borg link`'s document, this overlay and the two modes below all call it.
No checkpoint, or one stating nothing, gives null and NEVER the stored value, so a reader degrades to
`waiting_reason` or the relative activity. Expand step only: summarize.py and the registry writer are untouched.
Each mode is ONE Python call however many repositories there are:

- no argument: the overlaid registry with derived summaries (`borg next`, nextpick).
- `--summaries`: read a registry document on stdin, print it with every `summary` derived. For the readers that
  already hold a registry (the switch picker, the Queen's orchestrator context).
- `--summary NAME`: print that one repository's derived summary (nothing when it has none). For the switch brief.
"""

from __future__ import annotations

import json
import sys

from borg_core.link import shell, worktree


def own_checkpoint_summary(name: str, repositories: dict) -> str | None:
    """The summary stated by the newest checkpoint of `name`'s OWN directory, or None.

    The directory's own checkpoints, not its repo group's, so a worktree never carries a sibling's sentence.
    """
    return shell.read_checkpoint_summary(worktree.own_source(name, repositories))


def with_checkpoint_summaries(registry: dict) -> dict:
    """The registry with every repository's `summary` REPLACED by its latest checkpoint's, or null."""
    repositories = registry.get("projects") or {}
    return {
        **registry,
        "projects": {
            name: {**entry, "summary": own_checkpoint_summary(name, repositories)} if isinstance(entry, dict) else entry
            for name, entry in repositories.items()
        },
    }


def main(argv: list[str] | None = None) -> int:
    """Print the overlaid registry (or, per the mode, one derived summary) on stdout."""
    args = sys.argv[1:] if argv is None else argv
    if args[:1] == ["--summaries"]:
        print(json.dumps(with_checkpoint_summaries(json.load(sys.stdin))))
        return 0
    if args[:1] == ["--summary"] and len(args) == 2:
        repositories = shell.read_registry().get("projects") or {}
        entry = repositories.get(args[1])
        print((own_checkpoint_summary(args[1], repositories) if isinstance(entry, dict) else None) or "")
        return 0
    if args:
        print(f"usage: overlay [--summaries | --summary NAME]; got {' '.join(args)}", file=sys.stderr)
        return 2
    print(json.dumps(with_checkpoint_summaries(shell.registry_with_state())))
    return 0


if __name__ == "__main__":
    sys.exit(main())
