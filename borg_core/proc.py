"""The one way borg_core runs a subprocess: run it, capture stdout, degrade instead of raising.

Three modules had grown near-identical copies of the same run/capture/degrade shape --
`borg_core/registry/shell.py`'s `list_tmux_windows`, `borg_core/recon/shell.py`'s `run_adapter`, and
`borg_core/manifest/shell.py`'s `_git_origin_url`. `list_tmux_windows`'s own docstring records that
this shape had ALREADY been deduplicated once, when two byte-identical copies collapsed into it, and
then a third appeared anyway. `borg_core/paths.py` records the rule being followed here: two copies
were tolerated, the third would not have been. pylint stayed green only because
`min-similarity-lines = 8` and the argv and sentinel lines differ.

WHAT IS SHARED IS THE POLICY, NOT THE SENTINEL. Each caller keeps its own answer for "no answer" --
`[]` for tmux, a synthetic failed track for recon, `""` for git -- because what an absent result
means is the caller's business. What lives here is the rule that a subprocess never raises out of
borg_core, and the exact set of exceptions that rule has to cover.

WHY THIS IS Popen + A SESSION + A TEMP FILE AND NOT `subprocess.run`. It used to be one
`subprocess.run(capture_output=True, timeout=...)` call, and that shape has two measured defects
that only became reachable when `borg link` folded the sweep in and started running adapters on a
reflexive command.

  1. `subprocess.run(timeout=...)` SIGKILLs exactly ONE PID. The shipped `recon-adapter-github`
     runs `gh` inside a command substitution, which bash forks as a subshell -- so the network work
     is a GRANDCHILD. Measured: with `gh` replaced by `sleep 300` and a 10s budget, `borg link
     --json` returned at 10.09s having killed the adapter, and left the adapter's subshell and its
     `sleep` reparented to init, still holding an open socket. Three invocations at a 2s budget left
     six orphans. `borg reap-worktrees` does not know about them and nothing else reaps them. So the
     child is started in its own SESSION (`start_new_session=True`) and the timeout path kills the
     whole PROCESS GROUP, not one pid.

  2. A PIPE IS CLOSED BY EOF, AND EOF NEEDS EVERY HOLDER OF THE FD TO CLOSE IT -- not just the
     direct child. An adapter that daemonizes anything (an `ssh` with ControlPersist, a Node runtime
     that forks a helper, a backgrounded token refresher) leaves a grandchild holding fd 1, so
     `run`'s read blocks until the BUDGET expires even though the adapter printed a complete, valid
     answer in milliseconds and exited. Measured: an adapter whose body is `sleep 60 &` followed by
     a valid track took the full budget AND was then reported as a FAILED track -- a wrong answer,
     not a slow one. Writing stdout to a temp file removes EOF from the question entirely: the wait
     is on the direct child's exit status, and whatever it wrote is on disk when it exits.

stderr is DEVNULL rather than a second captured stream: no caller has ever read it, and a second
pipe would reintroduce defect (2) through the other fd.
"""

from __future__ import annotations

import os
import signal
import subprocess
import tempfile


def _kill_session(pid: int) -> None:
    """SIGKILL the whole process group led by `pid`, ignoring an already-dead one.

    Safe to aim at the group id rather than the pid ONLY because every child this module spawns is
    started with `start_new_session=True`, which makes it a session and group leader, so its group
    id IS its pid. A killpg against a group we did not create could reach this interpreter.
    """
    try:
        os.killpg(pid, signal.SIGKILL)
    except OSError:
        # ProcessLookupError (already reaped) and PermissionError are both OSError; one clause covers
        # every way a kill can legitimately fail, and nothing in this module is ever fatal.
        pass


def run_capture(argv: list[str], timeout: float | None = None) -> tuple[int, str] | None:
    """Run `argv` and return `(returncode, stdout)`, or None when it could not be run at all.

    None means the process never produced an answer: a missing binary (FileNotFoundError, an
    OSError), a timeout (the deadline elapsed and the whole session was killed), or any other spawn
    failure. A process that RAN and exited non-zero returns `(code, stdout)` -- that is an answer,
    and reading it is load-bearing: the hardened spec's B5 measured `gh` exiting non-zero with fully
    usable `data`, so a caller that treats a non-zero exit as total failure discards a good sweep.
    Each caller decides which of the two it treats as failure.

    `errors="replace"` IS NOT DEFENSIVE PADDING. Under strict decoding a subprocess whose output is
    not valid UTF-8 raises UnicodeDecodeError, which is a ValueError and therefore caught by NEITHER
    `OSError` nor `subprocess.SubprocessError`. One `.git/config` carrying a stray byte would then
    take down a whole `borg link` invocation from inside a layer whose entire contract is that
    nothing is ever fatal. The mangled byte becomes U+FFFD and is rejected by whatever validates the
    value downstream, which is the correct outcome rather than a crash.

    stdout comes back RAW -- no strip. The three callers want `splitlines()`, `rstrip("\\n")` and a
    JSON parse respectively; normalizing here would silently change all three at once.

    THE DEADLINE IS ON THE DIRECT CHILD'S EXIT, NOT ON EOF, and on expiry the whole session dies.
    See the module docstring for the two measurements that forced both. `timeout=None` means no
    timeout.
    """
    try:
        with tempfile.TemporaryFile(mode="w+b") as sink:
            # JUSTIFICATION: stdlib process construction, not a cross-layer reach.
            with subprocess.Popen(  # pylint: disable=clean-arch-demeter
                argv,
                stdout=sink,
                stderr=subprocess.DEVNULL,
                stdin=subprocess.DEVNULL,
                start_new_session=True,
            ) as child:
                try:
                    child.wait(timeout=timeout)
                except subprocess.TimeoutExpired:
                    _kill_session(child.pid)
                    child.wait()
                    return None
            sink.seek(0)
            stdout = sink.read().decode("utf-8", errors="replace")
    except (OSError, subprocess.SubprocessError):
        return None
    # JUSTIFICATION: reading a Popen this function just produced, not a foreign object.
    return (child.returncode, stdout)  # pylint: disable=clean-arch-demeter
