"""I/O layer for `borg_core.planstate`: every filesystem, subprocess and environment read.

Mirrors `borg_core/link/shell.py`'s split -- logic lives in `core.py` and is never reimplemented
here. This module answers three impure questions and nothing else: does a path exist, what did a
runner exit with, and what state does GitHub hold for a batch of refs.

THE PR RESOLVER IS NOT WRITTEN HERE. `resolve_prs` calls `borg_core.link.shell.start_fetch` /
`finish_fetch` -- the SAME path `borg link` already uses for PR state, including its injection gate
(`grid._fetchable` -> `manifest.core.parse_ref`), its `gh api graphql` batching, its monotonic
deadline, and its three-valued `ok`/`degraded`/`failed` degrade policy. A second `gh` shell-out in
this package would be a fourth copy of a run/capture/degrade shape `borg_core/proc.py`'s header
already forbids, and -- worse -- a second resolver that could disagree with the board about whether
a PR is merged. AC7 pins that the verdict comes from that resolver by mutation.

NOTHING HERE IS EVER FATAL, extending the policy `borg_core/link/shell.py` states. A missing runner,
an unreadable plan, an offline host and a rate-limited `gh` all degrade to `None` or to an empty
answer, which `core.py` turns into `unknown` -- never into `fail`.
"""

from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

from borg_core import proc
from borg_core.link import shell as link_shell

# The runner argv is built HERE, FROM THE KIND, and the annotation's value is appended as a single
# already-validated argv element (AC9). Nothing in this package ever enables subprocess's `shell`
# keyword -- test_security.py greps every non-test module for it, which is why the literal spelling
# is deliberately absent from this comment. There is no string anywhere for a shell to parse.
# `sys.executable -m pytest` rather than a bare `pytest`, so the
# interpreter running the derive is the one running the suite -- a bare name would resolve against
# whatever PATH the calling hook happened to export.
_RUNNERS = {
    "pytest": [sys.executable, "-m", "pytest", "-q", "-p", "no:cacheprovider"],
    "bats": ["bats"],
}

DEFAULT_SUITE_TIMEOUT_SECONDS = 300.0


def suite_timeout() -> float:
    """BORG_PLANSTATE_SUITE_TIMEOUT in seconds, defaulting to DEFAULT_SUITE_TIMEOUT_SECONDS.

    THE SAME THREE-WAY GUARD `link/shell.py::fetch_timeout` uses -- unset OR EMPTY OR non-numeric
    takes the default -- because `_borg_py` passes its whole config surface through by name and an
    unset variable arrives as the EMPTY STRING. `float("")` raising out of a module whose header
    promises nothing is fatal is the exact `int("")` bug CLAUDE.md's "Learned" records.
    """
    raw = os.environ.get("BORG_PLANSTATE_SUITE_TIMEOUT")
    if not raw:
        return DEFAULT_SUITE_TIMEOUT_SECONDS
    try:
        return float(raw)
    except ValueError:
        return DEFAULT_SUITE_TIMEOUT_SECONDS


def read_text(path: Path) -> str | None:
    """The file's contents, or None when it cannot be read. Never raises."""
    try:
        return path.read_text(encoding="utf-8")
    except OSError:
        return None


def exists(root: Path, value: str) -> bool:
    """Whether a validated repo-relative annotation path exists under `root`.

    `root / value` IS SAFE ONLY BECAUSE `core.validate_annotation` RAN FIRST: it rejects an absolute
    path and any `..` segment, and pathlib's `/` would silently discard `root` for the former. The
    dependency is stated rather than re-checked, so there is one gate, not two that can drift.
    """
    return (root / value).exists()


def run_suite(root: Path, kind: str, value: str) -> tuple[int, str] | None:
    """`(returncode, stdout)` for the `kind` runner over `value`, or None when it could not be run.

    ARGV LIST, NEVER A SHELL STRING. The runner comes from `_RUNNERS[kind]` -- a closed dict keyed by
    a kind `core.validate_annotation` has already closed on -- and the annotation contributes exactly
    one element, which has already been matched against an anchored `[A-Za-z0-9._/-]` class. There is
    no interpolation anywhere on this path.

    `proc.run_capture` RETURNS None for a runner that is not installed and for one that outran its
    timeout, and `core.verdict_for_suite` maps None to `unknown` -- so a machine without `bats` reads
    as "not checked", never as "the suite failed".

    THE PATH IS RESOLVED TO AN ABSOLUTE ONE RATHER THAN `chdir`-ING TO `root`. `os.chdir` is
    process-global: it would change the working directory out from under the caller for the duration
    of a suite that may run for minutes, and `/borg-link-up` calls this from a session that is doing
    other things. Both runners accept an absolute target, and pytest derives its rootdir from the
    target's ancestors, so nothing is lost.
    """
    base = _RUNNERS.get(kind)
    if base is None:
        return None
    return proc.run_capture(base + [str(root / value)], timeout=suite_timeout())


def resolve_prs(refs: list[str]) -> dict:
    """The `borg link` fetch result for `refs`: `{attempted, status, requested, items, warnings}`.

    ONE BATCHED ROUND TRIP for every `pr:` annotation in the document, because that is what
    `start_fetch` is -- a single `gh api graphql` query with one aliased node per ref. Calling it
    per-criterion would be N round trips and N deadlines.

    NO REFS MEANS NO SUBPROCESS. `start_fetch` already guarantees that, and the early return here
    makes it true without entering the module at all -- which is what keeps a plan with no `pr:`
    annotation (every fixture in this package's AC9 suite among them) fork-free.
    """
    if not refs:
        # Annotated rather than returned inline: indexing a `dict` yields `Any`, and mypy's
        # `no-any-return` is right to object -- the callers treat this as a fetch result.
        skipped: dict = link_shell.start_fetch([])["done"]
        return skipped
    return link_shell.finish_fetch(link_shell.start_fetch(sorted(set(refs))))


def write_atomic(path: Path, text: str) -> None:
    """Replace `path`'s contents with `text` atomically: write a sibling tmp file, then `os.replace`.

    THE HOUSE RULE, APPLIED TO A DOCUMENT A HUMAN IS EDITING. The tmp file is a SIBLING, not one in
    `/tmp`, because `os.replace` is only atomic within a filesystem and a cross-device rename falls
    back to a copy -- which is the crash window this exists to close. A failure after the tmp write
    and before the replace leaves the original plan byte-identical.
    """
    directory = path.parent
    handle, tmp = tempfile.mkstemp(dir=str(directory), prefix=".planstate-", suffix=".tmp")
    try:
        with os.fdopen(handle, "w", encoding="utf-8") as stream:
            stream.write(text)
        os.replace(tmp, path)
    except OSError:
        # A FAILED WRITE MUST NOT LEAVE THE TMP FILE BESIDE THE PLAN. The original is untouched by
        # construction, so cleaning up and re-raising is the whole of the recovery.
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise
