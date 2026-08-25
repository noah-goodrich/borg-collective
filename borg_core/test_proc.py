"""Unit tests for borg_core.proc — the one run/capture/degrade subprocess helper.

Calling convention: real subprocesses against real binaries and real scripts under `tmp_path`. The
whole point of this module is what happens when a process misbehaves, so a mocked `subprocess.run`
would assert the mock rather than the policy. Only the timeout case is driven by a script that
sleeps, and it sleeps for a tenth of a second.
"""

from __future__ import annotations

import os

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


def test_stderr_is_captured_and_never_reaches_the_terminal(tmp_path, capfd):
    argv = [_script(tmp_path, "noisy", b"printf 'out'; printf 'err' >&2")]
    assert proc.run_capture(argv) == (0, "out")
    captured = capfd.readouterr()
    assert captured.out == "" and captured.err == ""


@pytest.mark.parametrize(
    "module_name,function_name",
    [
        ("borg_core.registry.shell", "list_tmux_windows"),
        ("borg_core.recon.shell", "run_adapter"),
        ("borg_core.manifest.shell", "_git_origin_url"),
    ],
    ids=["registry-tmux", "recon-adapter", "manifest-git"],
)
def test_no_module_forks_a_subprocess_of_its_own(module_name, function_name):
    """The regression this module exists to prevent: a fourth copy of the same shape.

    `list_tmux_windows`'s docstring records that two byte-identical copies had ALREADY been collapsed
    into it once, and a third appeared anyway (paths.py records the same rule for config paths: two
    copies tolerated, the third not). pylint cannot catch it -- `min-similarity-lines = 8` and the
    argv and sentinel lines differ -- so the check is mechanical here instead.
    """
    module = __import__(module_name, fromlist=["_"])
    assert function_name in vars(module), f"{module_name}.{function_name} moved; update this test"
    assert "subprocess" not in vars(module), f"{module_name} forks its own subprocess again"


def test_the_helper_lives_above_every_package_that_uses_it():
    # A neutral top-level home, so no package imports another package to get it.
    assert os.path.basename(os.path.dirname(os.path.abspath(proc.__file__))) == "borg_core"
