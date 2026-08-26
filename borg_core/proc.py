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

WHY THE RUN IS SPLIT INTO `run_background` + `collect`, AND WHY THAT SPLIT LIVES HERE. AC3's targeted
fetch has to START before `borg link`'s adapter fan-out and be COLLECTED after it, so the network
round trip overlaps work that was going to happen anyway. `run_capture` cannot do that: it waits
inside the same call that spawns, with no seam between the two. The hardened spec's B4 prescribed a
bare `subprocess.Popen` in `borg_core/link/shell.py` for this, and test_proc.py's
`test_no_module_forks_a_subprocess_of_its_own` already ruled that out by name -- a fourth copy of the
run/capture/degrade shape is exactly what this module exists to prevent, and the two measured hazards
above would have to be re-derived in it. So the seam is opened HERE, once, and `run_capture` becomes
literally `collect(run_background(argv), timeout)`. Both hazards are inherited rather than repeated:
`start_new_session=True` on the spawn, `_kill_session` on the deadline, a temp file instead of a pipe.

NEITHER CONTEXT MANAGER SURVIVES THE SPLIT, and that is the one real regression risk in it.
`Popen.__exit__` waits for the child and `TemporaryFile.__exit__` closes the sink, so a `with` on
either side would defeat the whole point of handing the pair back to a caller. `collect` therefore
owns the close on EVERY path -- success, timeout, exception -- in a `finally`. A caller that starts
and never collects leaks one fd and one zombie, which is why `run_background`'s docstring says the
pairing is mandatory.
"""

from __future__ import annotations

import os
import signal
import subprocess
import tempfile
from typing import IO, NamedTuple


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


class Running(NamedTuple):
    """A started child and the temp file its stdout is landing in. Only `collect` may open it.

    Opaque to callers on purpose: the pairing of a pid and the sink that pid is writing to is the
    invariant `collect` needs, and handing back two loose values invites a caller to wait on one
    without closing the other.
    """

    child: subprocess.Popen
    sink: IO[bytes]


def run_background(argv: list[str]) -> Running | None:
    """Start `argv` and return its handle WITHOUT waiting, or None when it could not be started.

    THE HANDLE MUST BE PASSED TO `collect`, exactly once. Nothing else closes the sink or reaps the
    child. This exists so a caller can overlap one subprocess with other work -- `borg link` starts
    AC3's targeted `gh` fetch, fans out its recon adapters, and only then collects -- and the price
    of that seam is that the cleanup is no longer scoped by a `with`.

    None means the process never started at all: a missing binary, a non-executable file, a temp
    file that could not be created. `collect(None)` is None in turn, so a caller needs no branch
    here; see run_capture, which is now exactly that composition.

    The two hardened properties both live on this line rather than in any caller.
    `start_new_session=True` makes the child a session leader so its pid IS its process group id,
    which is what lets the deadline path kill a grandchild the adapter forked. stdout goes to a
    `tempfile.TemporaryFile` and never to a pipe, so the wait is on the child's exit status rather
    than on EOF. See the module docstring for the measurement behind each.
    """
    try:
        sink: IO[bytes] = tempfile.TemporaryFile(mode="w+b")
    except OSError:
        return None
    try:
        # A `with` here is the ONE thing this function must not do: `Popen.__exit__` waits for the
        # child, which is precisely the wait this function exists to defer. Scoping it would collapse
        # `run_background` back into `run_capture` and delete the overlap seam. `collect` owns the
        # reap and the close, on every path, in a `finally`; see the module docstring.
        # JUSTIFICATION: stdlib process construction, not a cross-layer reach; deferred wait by design.
        child = subprocess.Popen(  # pylint: disable=clean-arch-demeter,consider-using-with
            argv,
            stdout=sink,
            stderr=subprocess.DEVNULL,
            stdin=subprocess.DEVNULL,
            start_new_session=True,
        )
    except (OSError, subprocess.SubprocessError):
        sink.close()
        return None
    return Running(child, sink)


def collect(handle: Running | None, timeout: float | None = None) -> tuple[int, str] | None:
    """Wait for a `run_background` handle and return `(returncode, stdout)`, or None.

    None means the process never produced an answer: it could not be started (`handle is None`), or
    the deadline elapsed and the whole session was killed. A process that RAN and exited non-zero
    returns `(code, stdout)` -- that is an answer, and reading it is load-bearing: the hardened
    spec's B5 measured `gh` exiting non-zero with fully usable `data`, so a caller that treats a
    non-zero exit as total failure discards a good fetch over one dead ref. Each caller decides
    which of the two it treats as failure.

    `errors="replace"` IS NOT DEFENSIVE PADDING. Under strict decoding a subprocess whose output is
    not valid UTF-8 raises UnicodeDecodeError, which is a ValueError and therefore caught by NEITHER
    `OSError` nor `subprocess.SubprocessError`. One `.git/config` carrying a stray byte would then
    take down a whole `borg link` invocation from inside a layer whose entire contract is that
    nothing is ever fatal. The mangled byte becomes U+FFFD and is rejected by whatever validates the
    value downstream, which is the correct outcome rather than a crash.

    stdout comes back RAW -- no strip. The four callers want `splitlines()`, `rstrip("\\n")` and two
    JSON parses respectively; normalizing here would silently change all of them at once.

    THE DEADLINE IS ON THE DIRECT CHILD'S EXIT, NOT ON EOF, and on expiry the whole session dies.
    `timeout=None` means no timeout. `timeout=0` is honoured as an immediately-expired deadline
    rather than as "no deadline", which is what a caller threading a monotonic deadline through a
    fan-out that already overran needs.

    THE SINK IS CLOSED ON EVERY PATH. `run_background` deliberately does not scope it with a `with`,
    so this `finally` is the only thing standing between the overlap seam and an fd leak on a
    command that runs once per tmux window.
    """
    if handle is None:
        return None
    child, sink = handle.child, handle.sink
    try:
        try:
            child.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            _kill_session(child.pid)
            # BOUNDED REAP: the child is already SIGKILLed and in its own session, so an
            # unbounded wait() here is the only unbounded wait on either of `borg link`'s
            # network paths -- every consumer (cmd_watch, `drone status`, the fzf preview)
            # swallows failure with `|| true`, so a hang here surfaces as a silent stall,
            # never an error. Abandoning the reap after this ceiling leaks at most one
            # short-lived zombie the interpreter reaps at exit.
            try:
                child.wait(timeout=2)
            except subprocess.TimeoutExpired:
                pass
            return None
        sink.seek(0)
        # JUSTIFICATION: reading a Popen this module just produced, not a foreign object.
        return (child.returncode, sink.read().decode("utf-8", errors="replace"))  # pylint: disable=clean-arch-demeter
    except (OSError, subprocess.SubprocessError):
        return None
    finally:
        sink.close()


def run_capture(argv: list[str], timeout: float | None = None) -> tuple[int, str] | None:
    """Run `argv` to completion and return `(returncode, stdout)`, or None. See `collect`.

    ONE IMPLEMENTATION, NOT TWO. This is literally `collect(run_background(argv), timeout)` so the
    synchronous callers (tmux, the recon adapters, `git remote get-url`) and the overlapped one
    (AC3's targeted fetch) cannot drift apart -- and so `run_background` is now the single place in
    borg_core where a subprocess is constructed at all, which is what makes test_grid.py's
    `record_forks` probe able to see every fork by wrapping one name.
    """
    return collect(run_background(argv), timeout)
