"""The impure half of the arrival brief: `hooks/borg-arrival-brief.sh` runs `python3 -m borg_core.link.arrival_hook`.

Reads the SessionStart input on stdin, fetches ONE document with a `borg` subprocess, hands it to the pure
`arrival.brief`, and prints a top-level `systemMessage` (plus a `sessionTitle` when the session has none). It reads no
registry and runs no `git`: the Queen session asks `borg next --line` (the board's own derivation, already age-tagged,
a cache read) and a repository session asks `borg link <repository> --json`, exactly one call each.

FAIL LOUD, NEVER SILENT: any failure after the source is known to be `startup` or `resume` prints a one-line
`systemMessage` containing `unavailable` and exits 0. A hook that exits non-zero would surface as a hook error on
every start; one that prints nothing would be indistinguishable from "there was nothing to say".
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

from borg_core.link import arrival

SOURCES = ("startup", "resume")
# The hook's own budget is 2 s at p95 (measured, not promised: tests/arrival_brief.bats). The subprocess ceiling is
# above the p95 so a slow disk degrades to a loud line instead of a hung start, and below the plugin entry's timeout.
CALL_TIMEOUT_S = 10


def find_repository(cwd: str) -> str:
    """The registry name for `cwd`: the nearest `.borg-project` file's content, else the directory's own name.

    `lib/borg-hooks.sh::_borg_find_repository`, ported; tests/arrival_brief.bats runs both on one table.
    """
    directory = cwd
    while directory not in ("/", ""):
        marker = Path(directory) / ".borg-project"
        if marker.is_file():
            return marker.read_text(encoding="utf-8", errors="replace").strip()
        directory = directory.rsplit("/", 1)[0]
    return cwd.rstrip("/").rsplit("/", 1)[-1]


def _orchestrator_root() -> str:
    return os.environ.get("BORG_ORCHESTRATOR_ROOT") or f"{os.environ.get('HOME', '')}/dev"


def _ask(argv: list[str]) -> str:
    """Stdout of one `borg` call. Raises RuntimeError with a short reason on any failure."""
    try:
        done = subprocess.run(argv, capture_output=True, text=True, timeout=CALL_TIMEOUT_S, check=False)
    except FileNotFoundError as err:
        raise RuntimeError("borg not found on PATH") from err
    except subprocess.TimeoutExpired as err:
        raise RuntimeError(f"{' '.join(argv[:2])} timed out") from err
    if done.returncode != 0:
        raise RuntimeError(f"{' '.join(argv[:2])} exited {done.returncode}")
    return done.stdout


def _message(cwd: str) -> str:
    if arrival.session_mode(cwd, _orchestrator_root()) == "orchestrator":
        lines = [line for line in _ask(["borg", "next", "--line"]).splitlines() if line.strip()]
        if len(lines) != 1:
            raise RuntimeError("borg next --line gave no single line")
        return lines[0]
    try:
        doc = json.loads(_ask(["borg", "link", find_repository(cwd), "--json"]))
        return arrival.brief(doc)
    except (ValueError, TypeError, AttributeError, KeyError) as err:
        raise RuntimeError(f"bad link document: {err}") from err


def run(raw: str) -> dict | None:
    """The hook's JSON output for one SessionStart input, or None when it must print nothing."""
    try:
        payload = json.loads(raw)
        if not isinstance(payload, dict):
            raise ValueError("not an object")
    except ValueError:
        return {"systemMessage": arrival.unavailable("unreadable hook input")}
    if payload.get("source") not in SOURCES:
        return None
    cwd = str(payload.get("cwd") or "")
    if cwd in ("", "/"):
        return None
    try:
        out: dict = {"systemMessage": _message(cwd)}
    except RuntimeError as err:
        return {"systemMessage": arrival.unavailable(str(err))}
    # Never in the Queen session (her ListAgents address keeps its default form), and never over a title already set.
    if arrival.session_mode(cwd, _orchestrator_root()) != "orchestrator" and not payload.get("session_title"):
        out["hookSpecificOutput"] = {"hookEventName": "SessionStart", "sessionTitle": arrival.session_title(cwd)}
    return out


def _stdin() -> str:
    # JUSTIFICATION: sys.stdin.read is the standard library's own stream, not a stranger's object graph.
    return sys.stdin.read()  # pylint: disable=clean-arch-demeter


def main() -> int:
    """Print the hook output, if any. Always exits 0."""
    if os.environ.get("BORG_NO_SESSION_HOOKS") == "1":
        return 0
    result = run(_stdin())
    if result is not None:
        print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
