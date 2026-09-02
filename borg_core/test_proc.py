"""Unit tests for borg_core.proc — the one run/capture/degrade subprocess helper.

Calling convention: real subprocesses against real binaries and real scripts under `tmp_path`. The
whole point of this module is what happens when a process misbehaves, so a mocked `subprocess.run`
would assert the mock rather than the policy. Only the timeout case is driven by a script that
sleeps, and it sleeps for a tenth of a second.
"""

from __future__ import annotations

import os
import subprocess
import time

import pytest

from borg_core import proc


def _script(tmp_path, name, body):
    """An executable /bin/sh script under tmp_path. Returns its path."""
    path = tmp_path / name
    path.write_bytes(b"#!/bin/sh\n" + body + b"\n")
    path.chmod(0o755)
    return str(path)


def test_a_successful_run_returns_its_code_and_stdout(tmp_path):
    argv = [_script(tmp_path, "ok", b"printf 'hello\\n'")]
    assert proc.run_capture(argv) == (0, "hello\n")


def test_a_non_zero_exit_is_an_ANSWER_not_a_failure(tmp_path):
    """THE distinction this module exists to make, and it is load-bearing rather than pedantic.

    The hardened spec's B5 measured `gh` exiting non-zero while `data` was fully usable (one bogus
    ref in a batch, every valid sibling resolved). Collapsing a non-zero exit into the same None as
    a missing binary would discard a good sweep over one dead ref. Each caller decides.
    """
    argv = [_script(tmp_path, "partial", b"printf 'usable output\\n'; exit 3")]
    assert proc.run_capture(argv) == (3, "usable output\n")


def test_a_missing_binary_is_None_rather_than_an_exception(tmp_path):
    assert proc.run_capture([str(tmp_path / "does-not-exist")]) is None


def test_a_non_executable_file_is_None(tmp_path):
    path = tmp_path / "not-executable"
    path.write_text("#!/bin/sh\ntrue\n", encoding="utf-8")
    assert proc.run_capture([str(path)]) is None


def test_a_timeout_is_None(tmp_path):
    # TimeoutExpired is a SubprocessError, not an OSError; both have to be covered or a hung network
    # mount takes the command down.
    argv = [_script(tmp_path, "slow", b"sleep 5")]
    assert proc.run_capture(argv, timeout=0.1) is None


def test_no_timeout_means_no_timeout(tmp_path):
    assert proc.run_capture([_script(tmp_path, "quick", b"printf 'x'")], timeout=None) == (0, "x")


def test_output_that_is_not_valid_utf8_degrades_instead_of_raising(tmp_path):
    """UnicodeDecodeError is a ValueError, so it is caught by NEITHER `OSError` NOR
    `subprocess.SubprocessError`.

    With strict decoding, one subprocess emitting a stray byte -- a `.git/config` carrying a
    mangled remote URL is the real case -- raised straight out through every caller and killed the
    whole invocation. `errors="replace"` makes it U+FFFD, which whatever validates the value then
    rejects on its own terms.

    OCTAL `\\377`, NOT HEX `\\xff`. `_script` writes `#!/bin/sh`; on macOS `/bin/sh` is
    bash-in-sh-mode, whose `printf` understands `\\xNN` hex escapes -- a bash-ism, not POSIX. On
    Linux `/bin/sh` is dash, which does not: it emits the literal four characters `\\`, `x`, `f`,
    `f` and never produces an invalid byte at all, so this test's premise (that the child emits
    binary garbage) was false on Linux and it asserted on a string that was never binary -- the
    macOS-only pass proved nothing about the `errors="replace"` path this test exists to cover.
    `\\377` is POSIX octal and both shells' `printf` agree on it. Verified in
    `debian:stable-slim`: `printf 'ok-\\xff-end'` prints the four literal characters; `printf
    'ok-\\377-end'` prints the single byte 0xFF.
    """
    argv = [_script(tmp_path, "binary", b"printf 'ok-\\377-end'")]
    result = proc.run_capture(argv)
    assert result is not None, "must not raise, and must not be swallowed as a spawn failure either"
    returncode, stdout = result
    assert returncode == 0
    assert "�" in stdout and stdout.startswith("ok-")


def test_stdout_is_returned_raw_with_no_trimming(tmp_path):
    # Three callers want splitlines(), rstrip("\n") and a JSON parse; normalizing here would
    # silently change all three at once.
    argv = [_script(tmp_path, "spacey", b"printf '  padded  \\n\\n'")]
    assert proc.run_capture(argv) == (0, "  padded  \n\n")


def test_stderr_is_discarded_and_never_reaches_the_terminal(tmp_path, capfd):
    argv = [_script(tmp_path, "noisy", b"printf 'out'; printf 'err' >&2")]
    assert proc.run_capture(argv) == (0, "out")
    captured = capfd.readouterr()
    assert captured.out == "" and captured.err == ""


def _descendants_alive(marker_pid_file) -> bool:
    """Whether the pid recorded by a test script is still running. Signal 0 is the liveness probe."""
    try:
        os.kill(int(marker_pid_file.read_text().strip()), 0)
    except (OSError, ValueError):
        return False
    return True


def test_a_timeout_kills_the_whole_process_tree_not_just_the_direct_child(tmp_path):
    """THE ORPHAN REGRESSION, measured before it was fixed.

    `subprocess.run(timeout=...)` SIGKILLs exactly one pid. The shipped `recon-adapter-github` runs
    `gh` inside a command substitution, which bash forks as a subshell, so the network work is a
    GRANDCHILD -- and with `gh` replaced by `sleep 300` and a 10s budget, `borg link --json` returned
    at 10.09s having left the adapter's subshell and its `sleep` reparented to init, holding an open
    socket, with nothing in the tree that reaps them. Three invocations at a 2s budget left six.

    The script writes its grandchild's pid where this test can probe it, so the assertion is about a
    REAL process's liveness after the deadline, not about which flags were passed.
    """
    pid_file = tmp_path / "grandchild.pid"
    argv = [
        _script(
            tmp_path,
            "forker",
            b"sleep 30 & printf '%s' \"$!\" > '" + str(pid_file).encode() + b"'; sleep 30",
        )
    ]
    assert proc.run_capture(argv, timeout=0.5) is None

    deadline = time.monotonic() + 3
    while _descendants_alive(pid_file) and time.monotonic() < deadline:
        time.sleep(0.05)
    assert not _descendants_alive(pid_file), "the grandchild outlived the deadline -- only the direct child was killed"


def test_a_completed_child_is_not_held_hostage_by_a_backgrounded_grandchild(tmp_path):
    """B4's ACTUAL shape: output complete at t=0, a detached grandchild still holding fd 1.

    A pipe closes on EOF, and EOF requires EVERY holder of the fd to close it. An adapter that
    daemonizes anything -- `ssh` with ControlPersist, a Node runtime that forks a helper, a
    backgrounded token refresher -- leaves a grandchild on stdout, so a pipe-based read blocks for the
    FULL BUDGET even though the adapter printed a complete valid answer in milliseconds and exited.
    Measured under the old implementation with a 5s budget: 5.11s, and the good payload was then
    discarded and reported as a FAILED track -- a wrong answer, not a slow one.

    The re-measurement that once declared B4 absent used a `sleep 30` adapter that produces NO
    OUTPUT, which is a different shape entirely and cannot reproduce this.
    """
    argv = [_script(tmp_path, "daemonizer", b"sleep 30 & printf 'complete answer\\n'")]

    started = time.monotonic()
    result = proc.run_capture(argv, timeout=5)
    elapsed = time.monotonic() - started

    assert result == (0, "complete answer\n"), "the child's complete output must not be discarded"
    assert elapsed < 2, f"waited {elapsed:.2f}s for a child that exited immediately -- the read is still EOF-bound"


# ── the start/collect pair AC3's targeted fetch needs ─────────────────────────────────────────────


def test_run_capture_really_is_collect_over_run_background(tmp_path, monkeypatch):
    """ONE IMPLEMENTATION, PINNED MECHANICALLY, because two probes depend on it being one.

    `run_background` is now the only place in borg_core that constructs a `subprocess.Popen`, and
    test_grid.py's `record_forks` wraps that one name on exactly that strength -- so if `run_capture`
    ever grew a second Popen of its own, every "nothing forked" assertion in the link suite would go
    blind at once while staying green. Rebinding the module global here is the same lever
    `record_forks` pulls, so this is a direct test of that assumption rather than a paraphrase of it.
    """
    seen: list[list[str]] = []
    real = proc.run_background

    def spy(argv):
        seen.append(list(argv))
        return real(argv)

    monkeypatch.setattr(proc, "run_background", spy)
    argv = [_script(tmp_path, "through", b"printf 'via the pair'")]
    assert proc.run_capture(argv) == (0, "via the pair")
    assert seen == [argv], "run_capture must reach the child through run_background and nowhere else"


def test_a_handle_that_could_not_be_started_collects_to_None(tmp_path):
    """`collect(None)` is None, so a caller needs no branch for a missing binary.

    That is what lets `run_capture` be a one-line composition and what lets link's start_fetch treat
    "gh is not installed" as one named degrade rather than as a second control path.
    """
    assert proc.run_background([str(tmp_path / "does-not-exist")]) is None
    assert proc.collect(None) is None
    assert proc.collect(None, timeout=5) is None


def test_a_sink_that_cannot_be_created_is_None_rather_than_an_exception(tmp_path, monkeypatch):
    """A full /tmp or an exhausted fd table must degrade, not raise.

    The sink is opened BEFORE the Popen so a failure there has no child to reap -- but it is also the
    first thing in the whole `borg link` grid path that touches the filesystem for its own purposes,
    and this module's contract is that a subprocess never raises out of borg_core.
    """

    def no_temp_files(*_args, **_kwargs):
        raise OSError(28, "No space left on device")

    monkeypatch.setattr(proc.tempfile, "TemporaryFile", no_temp_files)
    assert proc.run_background([_script(tmp_path, "unreached", b"printf 'x'")]) is None
    assert proc.run_capture([_script(tmp_path, "unreached2", b"printf 'x'")]) is None


def test_the_work_runs_between_the_start_and_the_collect(tmp_path):
    """THE WHOLE REASON THE PAIR EXISTS: the child's time overlaps the caller's, it does not add to it.

    ASSERTED BY SIBLING VISIBILITY, NOT BY WALL CLOCK, and the difference is the difference between a
    structural assertion and a benchmark of whatever else the machine is doing. Each child drops a
    marker, sleeps, then reports whether it can see the other's. Run concurrently both are already on
    disk, so both report `saw-sibling`. Run serially the FIRST cannot possibly see the second's marker
    -- it has not started -- so it reports `alone` and this fails. No duration appears anywhere.

    THIS REPLACED AN `elapsed < 1.0` CEILING OVER TWO 0.6s CHILDREN, and the replacement is not the
    forbidden move of widening a threshold after seeing an inconvenient number -- it deletes the
    threshold. That ceiling measured the RUNNER: it passed on an idle machine and failed under load,
    and it failed 2 of 2 runs once the suite reached 991 tests, having failed intermittently at 980
    and rarely at 966. A test whose verdict tracks the size of the suite around it is not reporting on
    the code under test. The docstring already claimed to be "a structural assertion rather than a
    benchmark of the runner"; now it is one.

    `borg link` uses exactly this shape to absorb AC3's `gh` round trip into the adapter fan-out it
    was going to pay for anyway.
    """
    marks = tmp_path / "marks"
    marks.mkdir()

    # `sleep` must span the sibling's START, not its finish -- both children write their marker
    # before sleeping, so 0.3s of overlap is enough and the test costs half what the old one did.
    def _sees(me, them):
        return (
            f"touch '{marks}/{me}'; sleep 0.3; "
            f"if [ -e '{marks}/{them}' ]; then printf 'saw-sibling'; else printf 'alone'; fi"
        ).encode()

    first = proc.run_background([_script(tmp_path, "one", _sees("one", "two"))])
    second = proc.run_background([_script(tmp_path, "two", _sees("two", "one"))])

    assert proc.collect(first, timeout=30) == (0, "saw-sibling"), (
        "the first child ran to completion before the second started"
    )
    assert proc.collect(second, timeout=30) == (0, "saw-sibling")


def test_a_collect_timeout_kills_the_whole_session_of_a_backgrounded_start(tmp_path):
    """The orphan guarantee survives the split. It is inherited from `run_background`'s
    `start_new_session=True`, not re-derived at the new call site.

    Without it, AC3's `gh` -- which the hardened spec's B4 wanted to run under a future timeout --
    would leave a live socket behind on every deadline miss, once per `borg link`, and nothing in the
    tree reaps it.
    """
    pid_file = tmp_path / "grandchild.pid"
    handle = proc.run_background(
        [
            _script(
                tmp_path,
                "bg-forker",
                b"sleep 30 & printf '%s' \"$!\" > '" + str(pid_file).encode() + b"'; sleep 30",
            )
        ]
    )
    started = time.monotonic()
    assert proc.collect(handle, timeout=0.5) is None
    assert time.monotonic() - started < 3, "the deadline is on the child's exit, not on EOF"

    deadline = time.monotonic() + 3
    while _descendants_alive(pid_file) and time.monotonic() < deadline:
        time.sleep(0.05)
    assert not _descendants_alive(pid_file), "the grandchild outlived the deadline -- only the direct child was killed"


def test_the_post_sigkill_reap_is_bounded_not_unbounded(tmp_path, monkeypatch):
    """The reap after SIGKILL must itself have a ceiling, or a child that does not die promptly
    blocks `collect` -- and therefore `borg link` -- indefinitely. It is the only unbounded wait on
    either of the front door's two network paths, and a hang has no error path at all -- it is a
    command that never returns. (This used to say "every consumer swallows collect's failure with
    `|| true` (cmd_watch, `drone status`, the fzf preview), so a hang here surfaces as a silent
    stall". All three were retired 2026-08-27; a hang is worse than a swallowed error either way,
    which is why the ceiling stays.)

    A real child dies instantly under a real SIGKILL, so there is no way to make one actually
    refuse to report exit for this test. `child.wait` is monkeypatched instead to keep raising
    `TimeoutExpired`, simulating the one shape a real process cannot reliably produce here (D-state,
    a frozen cgroup, deferred signal delivery) -- the real SIGKILL still fires via `_kill_session`.
    """
    handle = proc.run_background([_script(tmp_path, "sleeper", b"sleep 30")])
    real_wait = handle.child.wait
    calls: list[float | None] = []

    def _stubborn_wait(timeout=None):
        calls.append(timeout)
        raise subprocess.TimeoutExpired(cmd="sleeper", timeout=timeout or 0)

    monkeypatch.setattr(handle.child, "wait", _stubborn_wait)

    started = time.monotonic()
    assert proc.collect(handle, timeout=0.1) is None
    elapsed = time.monotonic() - started

    assert elapsed < 1.0, f"the bounded reap took {elapsed:.2f}s -- an unbounded wait() would hang here forever"
    assert calls == [0.1, 2], "the outer wait honours its caller's timeout, the reap-after-kill honours its own ceiling"

    real_wait(timeout=1)  # the real child is already dead from the real SIGKILL; reap it so no zombie leaks


def test_a_zero_timeout_is_an_expired_deadline_and_not_an_absent_one(tmp_path):
    """`timeout=0` must kill, not wait forever, because that is what a monotonic deadline produces.

    link's finish_fetch computes `max(0.0, deadline - monotonic())`, so a fan-out that already
    overran hands exactly 0.0 to this function. If 0 were read as "no timeout" -- the way `None` is
    -- the front door would block on `gh` indefinitely at precisely the moment it is already late.
    """
    handle = proc.run_background([_script(tmp_path, "slow-zero", b"sleep 5")])
    started = time.monotonic()
    assert proc.collect(handle, timeout=0) is None
    assert time.monotonic() - started < 2


@pytest.mark.parametrize(
    "module_name,function_name",
    [
        ("borg_core.registry.shell", "list_tmux_windows"),
        ("borg_core.recon.shell", "run_adapter"),
        ("borg_core.manifest.shell", "_git_origin_url"),
        ("borg_core.link.shell", "sweep"),
    ],
    ids=["registry-tmux", "recon-adapter", "manifest-git", "link-sweep"],
)
def test_no_module_forks_a_subprocess_of_its_own(module_name, function_name):
    """The regression this module exists to prevent: a fourth copy of the same shape.

    `list_tmux_windows`'s docstring records that two byte-identical copies had ALREADY been collapsed
    into it once, and a third appeared anyway (paths.py records the same rule for config paths: two
    copies tolerated, the third not). pylint cannot catch it -- `min-similarity-lines = 8` and the
    argv and sentinel lines differ -- so the check is mechanical here instead.

    `borg_core.link.shell` joined the list with S3's sweep fold, and it is the one that most needed
    to. It runs subprocesses now -- an adapter fan-out, a `git remote get-url`, and AC3's targeted
    `gh` fetch -- but runs NONE of its own: the first two arrive through recon.shell and
    manifest.shell, and the third calls proc.run_background directly.

    THIS IS THE RULING THAT AC3 WAS HELD TO, and it is recorded here in the past tense because it
    was tested. The hardened spec's B4 prescribed a bare `subprocess.Popen` in link/shell.py for the
    targeted fetch, which would have made that module the fourth fork site. B4's hazard is real --
    the two cases above reproduce it -- but it is a property of HOW a subprocess is run, and fixing
    it in proc.py is what makes all four callers inherit `start_new_session=True`, the process-group
    kill and the temp file instead of a pipe. So the start-now/collect-later seam was opened in
    proc.py as a `run_background`/`collect` pair, and `run_capture` became the composition of the
    two. This assertion is what would have noticed the other choice, and it is what will notice the
    fifth copy.
    """
    module = __import__(module_name, fromlist=["_"])
    assert function_name in vars(module), f"{module_name}.{function_name} moved; update this test"
    assert "subprocess" not in vars(module), f"{module_name} forks its own subprocess again"


def test_the_helper_lives_above_every_package_that_uses_it():
    # A neutral top-level home, so no package imports another package to get it.
    assert os.path.basename(os.path.dirname(os.path.abspath(proc.__file__))) == "borg_core"
