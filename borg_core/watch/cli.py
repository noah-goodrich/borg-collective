"""`python3 -m borg_core.watch.cli` -- one PR-activity sweep.

Read-only by default; `--apply` additionally posts the allowlisted actions. The split matters: the
schedule runs with `--apply`, but a human debugging the watcher runs it without and sees exactly
what WOULD be posted, which is the only way to audit an unattended poster before trusting it.
"""

from __future__ import annotations

import argparse
import subprocess
import sys

from borg_core.watch import core, shell

# Posted bodies are TEMPLATES FILLED WITH DERIVED VALUES ONLY. No PR title, comment body or author
# name is ever interpolated into a comment this watcher posts -- echoing external text back would
# turn the watcher into a relay for whatever was written at it.
_VOID_BODY = """## STACK-APPROVAL void — head moved and the tree changed

Automated notice from `borg-pr-watch`. The approval stamped at `{old}` no longer applies: the head
is now `{new}` and `git diff --quiet {old} {new}` reports a real content difference, so the earlier
verdict was made against code that is no longer here.

Re-review is needed. This notice states a derived fact and is not itself a verdict.
"""

_RESTAMP_BODY = """## STACK-APPROVAL: {machine} APPROVES #{number} @ {new} (carried forward)

Automated re-stamp from `borg-pr-watch`. The head moved `{old}` → `{new}` but the TREE IS
BYTE-IDENTICAL (`git diff --quiet {old} {new}` exits 0), so the approval already given at `{old}`
is still literally true of this code — a rebase or an amended message, not a change.

This carries an existing human verdict forward; it does not create a new one. Any content change
voids it.
"""


def _post(repo: str, number: int, body: str) -> bool:
    """Post a comment. Never merges, never reviews -- `gh pr comment` is the only verb used."""
    try:
        proc = subprocess.run(["gh", "pr", "comment", str(number), "--repo", repo,
                               "--body", body],
                              capture_output=True, text=True, timeout=60, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return False
    return proc.returncode == 0


def _act(args: argparse.Namespace, event: dict, after: dict) -> str:
    """The allowlisted action for one event, performed when `apply`. Returns a report line or "".

    Split out of `main` so the decision path is readable in isolation: fetch the stamp, ask
    `core.decide`, and post only what it authorized. Every branch that is not an explicit
    allowlisted action returns "" and posts nothing.
    """
    number = event["number"]
    stamped = core.prior_stamp(shell.comments(args.repo, number), number)
    action = core.decide(event, stamped, after,
                         shell.trees_identical(args.repo_dir, stamped, after.get("head", "")))
    if action == core.ACTION_NONE:
        return ""
    template = _RESTAMP_BODY if action == core.ACTION_RESTAMP else _VOID_BODY
    body = template.format(old=stamped, new=after.get("head", ""), number=number,
                           machine=args.machine)
    if not args.apply:
        return f"    WOULD POST [{action}] (re-run with --apply)"
    return (f"    posted [{action}]" if _post(args.repo, number, body)
            else f"    POST FAILED [{action}]")


def main(argv: list[str] | None = None) -> int:
    """Sweep, diff against the stored snapshot, report, and optionally act."""
    parser = argparse.ArgumentParser(prog="borg_core.watch.cli", description=__doc__.splitlines()[0])
    parser.add_argument("--repo", required=True, help="owner/name")
    parser.add_argument("--repo-dir", default=".", help="local clone, for the tree comparison")
    parser.add_argument("--apply", action="store_true", help="post allowlisted actions")
    parser.add_argument("--machine", default="watcher", help="machine name used in a re-stamp")
    args = parser.parse_args(argv)

    slug = args.repo
    owner, _, name = slug.partition("/")
    if not owner or not name:
        print(f"bad repo slug: {slug}", file=sys.stderr)
        return 2

    current = shell.sweep(owner, name)
    if not current:
        # A failed sweep must NOT overwrite the snapshot. Storing an empty result would make every
        # open PR look closed on the next run and fire a wave of false MERGED/CLOSED events.
        print("sweep returned nothing (gh unavailable or query failed)", file=sys.stderr)
        return 1

    events = core.diff(shell.load_snapshot(), current)
    shell.save_snapshot(current)
    if not events:
        return 0

    by_number = {pr["number"]: pr for pr in current.get("prs") or []}
    lines = []
    for event in events:
        lines.append(f"#{event['number']} {event['kind']}: {event['detail']}")
        # Only a moved head can authorize anything, so the stamp fetch costs at most one extra
        # call per moved head rather than one per event.
        if event["kind"] != core.HEAD_MOVED:
            continue
        report = _act(args, event, by_number.get(event["number"]) or {})
        if report:
            lines.append(report)

    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
