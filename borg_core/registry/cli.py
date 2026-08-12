"""CLI entrypoint for `borg add` / `borg rm` (ports cmd_add / cmd_rm in borg.zsh).

One module, two subcommands -- registry CRUD is small enough on both sides that a second file
would be ceremony.

Deliberately NOT argparse (unlike borg_core.recon.cli): the original cmd_add/cmd_rm have zero flag
surface -- each reads only `$1` (`local ppath="${1:-$PWD}"` / `local project="${1:-}"`) and never
references `$2` onward, so extra positional args are silently ignored, and a value like "-h" or
"--help" is treated as ordinary data (a literal path/project name), not a flag. argparse's
positional matching would reject extra args and auto-intercept -h/--help, which are both
confirmed, real divergences from that behavior (found in adversarial review of this migration) --
so for a genuinely zero-flag command, direct `argv` indexing is the more faithful port, not a step
backward from argparse.

KNOWN BUG, preserved for parity (see tests/cli_contract.bats around the `add` tests): cmd_add in
borg.zsh exits 1 whenever no Claude session is found for the newly-registered project, even though
registration itself succeeded -- an accident of `set -e` tripping on the truthiness of its last
line. Part 3's non-negotiables are parity first, improvements after, so `cmd_add` here
deliberately returns the same exit code for the same condition. A future deliberate fix should
flip this contract on purpose, not as a silent side effect of an unrelated change.
"""

from __future__ import annotations

import sys
from typing import NoReturn

from borg_core.registry import core, shell


def _die(message: str) -> NoReturn:
    """Print an error to stderr and exit non-zero, mirroring the zsh CLI's `die` helper."""
    print(message, file=sys.stderr)
    raise SystemExit(1)


def _basename(path: str) -> str:
    """Mirror zsh's `${path##*/}` (last path segment; empty if path ends in '/')."""
    return path.rpartition("/")[2]


def cmd_add(path_arg: str | None) -> int:
    """`borg add [path]` -- register a project. Returns 1 if no Claude session is found (known bug,
    preserved intentionally -- see module docstring), 0 otherwise."""
    ppath = shell.resolve_path(path_arg or ".")
    name = _basename(ppath)

    tmux_window = name if shell.tmux_window_exists(name) else None

    session_id = shell.claude_latest_session_id(ppath)

    last_activity = None
    if session_id:
        jsonl = shell.claude_session_jsonl(ppath, session_id)
        if jsonl.is_file():
            last_activity = shell.file_mtime_iso(jsonl)

    entry = core.build_add_entry(
        path=ppath,
        source="cli",
        tmux_session=shell.tmux_session_name(),
        tmux_window=tmux_window,
        session_id=session_id,
        last_activity=last_activity,
    )
    shell.registry_merge(name, entry)
    print(f"Registered: {name}")

    if session_id:
        print(f"Latest session: {session_id}")
        return 0
    return 1


def cmd_rm(project: str | None) -> int:
    """`borg rm <project>` -- unregister a project."""
    if not project:
        _die("usage: borg rm <project>")
    if not shell.registry_has(project):
        _die(f"project '{project}' not in registry")
    shell.registry_remove(project)
    print(f"Removed: {project}")
    return 0


def main(argv: list[str] | None = None) -> None:
    """Entrypoint for `python3 -m borg_core.registry.cli add|rm ...`.

    Indexes into argv directly rather than parsing flags -- see the module docstring for why.
    `args[0]` is the subcommand, `args[1]` (if present) is its one positional value; anything past
    that is silently ignored, mirroring zsh's `$1`-only reads.
    """
    args = sys.argv[1:] if argv is None else argv
    if not args:
        _die("usage: borg <add|rm> ...")
    command, rest = args[0], args[1:]
    value = rest[0] if rest else None

    if command not in ("add", "rm"):
        _die(f"borg: unknown registry command '{command}' (expected add or rm)")

    try:
        exit_code = cmd_add(value) if command == "add" else cmd_rm(value)
    except ValueError as exc:
        _die(str(exc))
    raise SystemExit(exit_code)


if __name__ == "__main__":
    main()
