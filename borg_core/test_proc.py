"""Unit tests for borg_core.proc — the one run/capture/degrade subprocess helper.

Calling convention: real subprocesses against real binaries and real scripts under `tmp_path`. The
whole point of this module is what happens when a process misbehaves, so a mocked `subprocess.run`
would assert the mock rather than the policy. Only the timeout case is driven by a script that
sleeps, and it sleeps for a tenth of a second.
"""

from __future__ import annotations

import os
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
    """
    argv = [_script(tmp_path, "binary", b"printf 'ok-\\xff-end'")]
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
    to. It runs subprocesses now -- an adapter fan-out and a `git remote get-url` -- but runs NONE of
    its own: both arrive through recon.shell and manifest.shell, which already go through
    run_capture. The hardened spec's B4 prescribed a bare `subprocess.Popen` here for AC3's targeted
    fetch, which would make this module the fourth fork site. B4's hazard is real -- the two cases
    above reproduce it -- but it is a property of how the subprocess is run, and it is fixed in
    proc.py where all four callers inherit the fix. If AC3 does need start-now/collect-later, it
    belongs in proc.py as a run_background/collect pair, not as an `import subprocess` here. This
    assertion is what will notice.
    """
    module = __import__(module_name, fromlist=["_"])
    assert function_name in vars(module), f"{module_name}.{function_name} moved; update this test"
    assert "subprocess" not in vars(module), f"{module_name} forks its own subprocess again"


def test_the_helper_lives_above_every_package_that_uses_it():
    # A neutral top-level home, so no package imports another package to get it.
    assert os.path.basename(os.path.dirname(os.path.abspath(proc.__file__))) == "borg_core"
