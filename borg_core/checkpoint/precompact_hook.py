"""The impure half of the PreCompact checkpoint: `hooks/borg-precompact-checkpoint.sh` runs `python3 -m` on this.

Reads the PreCompact payload on stdin, and writes ONE file, `<root>/.borg/checkpoints/<stem>.md`, where `<root>` and
`<stem>` come from the SAME code `/borg-link-up` uses (`prepare_shell.repository_root`, `shell.checkpoint_stem`,
`prepare.first_free_path`), so the Queen session lands in the orchestrator root's store exactly as link-up does.

SCOPED, because a plugin hook fires in every session on the machine: it writes only where borg already lives, meaning
`<root>/.borg/` or `<root>/.borg-project` exists, or the session is the Queen's (cwd equal to
`BORG_ORCHESTRATOR_ROOT`). A repository nobody registered with borg never grows a `.borg/` directory because of this.

FAILS OPEN AND PRINTS NOTHING: PreCompact may not block compaction through any path here, so every failure, including
a crash, is swallowed and the exit status is 0. Atomic write: a temp file in the same directory (no `.md` suffix, so
no reader globs it), then `os.replace`.
"""

from __future__ import annotations

import json
import os
from datetime import datetime

from borg_core.checkpoint import precompact, prepare, prepare_shell, shell

TAIL_BYTES = 4 * 1024 * 1024


def _transcript_tail(path: str) -> list[str]:
    """The last `TAIL_BYTES` of the transcript as lines, the first (possibly cut) line dropped."""
    with open(path, "rb") as handle:
        size = handle.seek(0, os.SEEK_END)
        handle.seek(max(0, size - TAIL_BYTES))
        raw = handle.read().decode("utf-8", errors="replace")
    lines = str.splitlines(raw)
    return lines[1:] if size > TAIL_BYTES else lines


def _in_scope(root: str, cwd: str) -> bool:
    """Borg lives here: a `.borg` directory, a `.borg-project` marker, or the Queen's own directory."""
    orchestrator = os.environ.get("BORG_ORCHESTRATOR_ROOT") or os.path.join(os.environ.get("HOME", ""), "dev")
    if os.path.realpath(cwd) == os.path.realpath(orchestrator):
        return True
    return os.path.isdir(os.path.join(root, ".borg")) or os.path.isfile(os.path.join(root, ".borg-project"))


def _newest_checkpoint(directory: str) -> tuple[str, str]:
    """`(name, body)` of the newest `*.md` by NAME (the readers' order), or ("", "")."""
    try:
        names = sorted((n for n in os.listdir(directory) if n.endswith(".md") and not n.startswith(".")), reverse=True)
    except OSError:
        return "", ""
    for name in names[:1]:
        try:
            with open(os.path.join(directory, name), encoding="utf-8", errors="replace") as handle:
                return name, handle.read()
        except OSError:
            return "", ""
    return "", ""


def timefmt_stamp(moment: datetime) -> str:
    """`YYYY-MM-DD HH:MM:SS`, the moment a checkpoint says it was written."""
    return datetime.strftime(moment, "%Y-%m-%d %H:%M:%S")


def _last_message(payload: dict) -> str:
    """The last user message in the payload's transcript, or "" when there is no readable transcript."""
    transcript = payload.get("transcript_path")
    if not isinstance(transcript, str) or not transcript:
        return ""
    try:
        if transcript.endswith(".json"):
            # Cortex: transcript_path is the conversation's metadata document; its messages are the JSONL beside it.
            return precompact.last_user_text_cortex(_transcript_tail(transcript[: -len(".json")] + ".history.jsonl"))
        return precompact.last_user_text(_transcript_tail(transcript))
    except OSError:
        return ""


def _write_atomically(path: str, body: str) -> None:
    """Temp file beside `path` (a dot name with no `.md`, so no reader globs it), then `os.replace`."""
    directory = os.path.dirname(path)
    os.makedirs(directory, exist_ok=True)
    temp = os.path.join(directory, f".{os.path.basename(path)}.{os.getpid()}.tmp")
    with open(temp, "w", encoding="utf-8") as handle:
        handle.write(body)
    os.replace(temp, path)


def write_checkpoint(payload: dict) -> str:
    """Write the checkpoint for one PreCompact payload; returns its path, or "" when out of scope or nothing to do."""
    cwd = payload.get("cwd") or ""
    if not isinstance(cwd, str) or not os.path.isdir(cwd):
        return ""
    budget = prepare_shell.Budget()
    root = prepare_shell.repository_root(cwd, budget)
    if not _in_scope(root, cwd):
        return ""
    session = str(payload.get("session_id") or "")
    moment = prepare_shell.now()
    directory = os.path.join(root, ".borg", "checkpoints")
    previous_name, previous = _newest_checkpoint(directory)
    path = ""
    marker = precompact.auto_marker(previous)
    if marker and session and marker[0] == session:
        # The newest file is this session's own automatic checkpoint (a compaction that failed and retried, or a
        # second one): refresh it in place rather than pile up files. Its carried-from stays the original source.
        path = os.path.join(directory, previous_name)
        previous_name = "" if marker[1] == "none" else marker[1]
    git_output, _ = prepare_shell.git_status(root, budget)
    body = precompact.render(
        precompact.Facts(
            when=timefmt_stamp(moment),
            trigger=str(payload.get("trigger") or "unknown"),
            session=session,
            git_status=git_output,
            last_message=_last_message(payload),
            previous=previous,
            previous_name=previous_name,
        )
    )
    stem = shell.checkpoint_stem(session, moment)
    path = path or prepare.first_free_path(root, stem, os.path.exists)
    _write_atomically(path, body)
    return path


def _stdin_text() -> str:
    with open(0, encoding="utf-8", errors="replace", closefd=False) as handle:
        return handle.read()


def main() -> None:
    """Read the payload from stdin and write the checkpoint. Silent, and exit 0 whatever happens."""
    if os.environ.get("BORG_NO_SESSION_HOOKS") == "1":
        return
    try:
        payload = json.loads(_stdin_text() or "{}")
        if isinstance(payload, dict) and payload.get("hook_event_name", "PreCompact") == "PreCompact":
            write_checkpoint(payload)
    # JUSTIFICATION: a PreCompact hook that raises must not disturb compaction; the fail-open contract is the point.
    except Exception:  # pylint: disable=broad-exception-caught
        return


if __name__ == "__main__":
    main()
