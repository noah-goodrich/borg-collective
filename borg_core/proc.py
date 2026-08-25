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
"""

from __future__ import annotations

import subprocess


def run_capture(argv: list[str], timeout: float | None = None) -> tuple[int, str] | None:
    """Run `argv` and return `(returncode, stdout)`, or None when it could not be run at all.

    None means the process never produced an answer: a missing binary (FileNotFoundError, an
    OSError), a timeout (TimeoutExpired, a SubprocessError), or any other spawn failure. A process
    that RAN and exited non-zero returns `(code, stdout)` -- that is an answer, and reading it is
    load-bearing: the hardened spec's B5 measured `gh` exiting non-zero with fully usable `data`, so
    a caller that treats a non-zero exit as total failure discards a good sweep. Each caller decides
    which of the two it treats as failure.

    `errors="replace"` IS NOT DEFENSIVE PADDING. Under strict decoding a subprocess whose output is
    not valid UTF-8 raises UnicodeDecodeError, which is a ValueError and therefore caught by NEITHER
    `OSError` nor `subprocess.SubprocessError`. One `.git/config` carrying a stray byte would then
    take down a whole `borg link` invocation from inside a layer whose entire contract is that
    nothing is ever fatal. The mangled byte becomes U+FFFD and is rejected by whatever validates the
    value downstream, which is the correct outcome rather than a crash.

    stdout comes back RAW -- no strip. The three callers want `splitlines()`, `rstrip("\\n")` and a
    JSON parse respectively; normalizing here would silently change all three at once.

    `timeout=None` means no timeout, matching `subprocess.run`.
    """
    try:
        result = subprocess.run(
            argv,
            capture_output=True,
            text=True,
            errors="replace",
            check=False,
            timeout=timeout,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    # JUSTIFICATION: reading a CompletedProcess this function just produced, not a foreign object.
    return (result.returncode, result.stdout)  # pylint: disable=clean-arch-demeter
