"""`python3 -m borg_core.extensions.cli` -- the surface `borg doctor` and the hook call.

Three verbs, all read-only:

    survey            every discoverable `prefer-tool` extension, with liveness   (--json for machines)
    check <command>   does a live preference say this shell command should be delegated?
"""

from __future__ import annotations

import argparse
import json
import sys

from borg_core.extensions import shell


def _survey(args: argparse.Namespace) -> int:
    rows = shell.survey(args.repository)
    if args.json:
        print(json.dumps({"extensions": rows}, indent=2))
        return 0
    if not rows:
        print("no prefer-tool extensions on this machine or in this repository")
        return 0
    for row in rows:
        # No default: `survey` only emits rows whose status came from `core.status`, which for a
        # prefer-tool row is always one of these three. A "?" fallback would be unreachable code
        # asserting that the two modules can disagree.
        mark = {"live": "ok", "dead": "DEAD", "unprobed": "UNPROBED"}[row["status"]]
        print(f"[{mark}] {row['name']}/{row['hook']} ({row['layer']}) prefer {row['prefer']!r}")
        if row["instead_of"]:
            print(f"        instead of: {row['instead_of']}")
        if row["status"] == "dead":
            print(f"        requirement NOT satisfied: {row['requires']} -- falling back to the default")
        if row["status"] == "unprobed":
            print("        declares no `- Requires:` line, so its absence cannot be checked")
        if row["conflicted"]:
            print("        both layers assert the same key; the machine layer wins for prefer-tool")
    return 0


def _check(args: argparse.Namespace) -> int:
    """Exit 0 and print the preference when `command` matches a LIVE preference, else exit 1.

    Deliberately one-sided and deliberately not a blocker. This answers "was a live preference
    bypassed", which is the only side of compliance a shell command can witness -- invoking the
    preferred SKILL is not a Bash call and leaves no trace here. A hook that reported this as a
    compliance RATE would be overclaiming; see hooks/borg-prefer-tool-log.sh.
    """
    for row in shell.survey(args.repository):
        if row["status"] != "live" or not row["instead_of"]:
            continue
        if row["instead_of"] in args.command:
            print(json.dumps(row))
            return 0
    return 1


def main(argv: list[str] | None = None) -> int:
    """Parse argv and dispatch. Returns the verb's exit code; 0 on a closed pipe.

    One FLAT parser with a positional verb, not `add_subparsers`, for the reason
    `borg_core/manifest/cli.py::_build_parser` documents at length: the clean-architecture linter
    reports the `add_subparsers(...).add_parser(...).set_defaults(...)` chain as a string of
    Law-of-Demeter violations (W9006), and all four sibling CLIs in this package are flat rather
    than carrying inline disables for argparse boilerplate. `command` is optional because only
    `check` takes it; `survey` ignores it, the same way `link/cli.py` parses and ignores `--deep`.
    """
    parser = argparse.ArgumentParser(prog="borg_core.extensions.cli",
                                     description=__doc__.splitlines()[0])
    parser.add_argument("verb", choices=("survey", "check"))
    parser.add_argument("command", nargs="?", default="",
                        help="for `check`: the shell command to test against live preferences")
    parser.add_argument("--repository", default="", help="repository root (default: discovered)")
    parser.add_argument("--json", action="store_true", help="for `survey`: machine-readable output")

    args = parser.parse_args(argv)
    try:
        if args.verb == "survey":
            return _survey(args)
        if not args.command:
            parser.error("check requires a command")
        return _check(args)
    except BrokenPipeError:
        return 0


if __name__ == "__main__":
    sys.exit(main())
