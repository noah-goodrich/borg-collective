"""The impure reads behind `borg checkpoint-prepare`: git, gh, the filesystem, the manifest and extensions code.

Nothing here decides what the document says -- `prepare.py` owns shape and bounds. This module only answers "what is
true on this machine right now", and it answers EVERY question with a value, never an exception: the command runs
inside a skill's load-time injection, where a non-zero exit aborts the whole skill invocation before the model sees
it, so a failed read has to become a field.

THE BUDGET. The Bash tool kills an injected command at two minutes and aborts the skill with it. This module keeps a
total wall-clock budget of `TOTAL_BUDGET_SECONDS`, and every subprocess gets the smaller of its own cap and what is
left. A step that finds the budget spent is skipped with a stated reason. All subprocesses go through
`borg_core.proc`, which kills the whole process group on a timeout (a `gh` that forks a helper would otherwise
outlive its deadline holding the pipe open).

NOTHING IS WRITTEN. `git` runs with `--no-optional-locks`, because a plain `git status` may refresh the index and
rewrite `.git/index` -- a write, in a command whose contract is that it makes none. The manifest is read through the
read-only `resolve` verb, in process, so its stderr (the refusal reason `proc` would discard) is available.
"""

from __future__ import annotations

import contextlib
import io
import json
import os
import re
import shutil
import time
from datetime import datetime

from borg_core import proc
from borg_core.checkpoint import prepare
from borg_core.checkpoint import shell as name_shell
from borg_core.extensions import core as ext_core
from borg_core.extensions import shell as ext_shell
from borg_core.manifest import cli as manifest_cli

TOTAL_BUDGET_SECONDS = 20.0
GIT_TIMEOUT_SECONDS = 5.0
GH_TIMEOUT_SECONDS = 10.0
MIN_SLICE_SECONDS = 0.2
READ_CAP_BYTES = 262144

SKILL_SUBJECT = "borg-link-up"
SKILL_KIND = "skill-extensions"
PLAN_CANDIDATES = ("PROJECT_PLAN.md", os.path.join("docs", "plans", "PROJECT_PLAN.md"))
NOW_OVERRIDE_ENV = "BORG_CHECKPOINT_PREPARE_NOW"

_PR_URL = re.compile(r"^https://[A-Za-z0-9.-]+/([A-Za-z0-9._-]+)/([A-Za-z0-9._-]+)/pull/([0-9]+)\Z")


class Budget:
    """A wall-clock allowance handed out in slices. `slice(cap)` is 0.0 once the allowance is spent."""

    def __init__(self, total: float = TOTAL_BUDGET_SECONDS) -> None:
        self._deadline = time.monotonic() + total

    def remaining(self) -> float:
        """Seconds left, never negative."""
        return max(self._deadline - time.monotonic(), 0.0)

    def slice(self, cap: float) -> float:
        """The smaller of `cap` and what is left, or 0.0 when too little is left to be worth a subprocess."""
        left = self.remaining()
        return min(cap, left) if left >= MIN_SLICE_SECONDS else 0.0


def _run(argv: list[str], budget: Budget, cap: float, cwd: str | None = None) -> tuple[int, str] | None:
    """`(returncode, stdout)`, or None when the budget is spent, the binary is absent, or the deadline passed."""
    allowance = budget.slice(cap)
    if allowance <= 0.0:
        return None
    return proc.run_capture(argv, timeout=allowance, cwd=cwd)


def now() -> datetime:
    """The moment checkpoint names are built from. A valid ISO value in the override variable pins it (tests)."""
    pinned = os.environ.get(NOW_OVERRIDE_ENV, "")
    if pinned:
        try:
            return datetime.fromisoformat(pinned)
        except ValueError:
            pass
    return datetime.now()


def repository_root(cwd: str, budget: Budget) -> str:
    """The git toplevel of `cwd`, else the directory holding PROJECT_PLAN.md, else `cwd` -- the skill's own rule."""
    if shutil.which("git"):
        answer = _run(["git", "-C", cwd, "rev-parse", "--show-toplevel"], budget, GIT_TIMEOUT_SECONDS)
        if answer is not None and answer[0] == 0 and answer[1].strip():
            return answer[1].strip("\n")
    return cwd


def plan_path(root: str) -> str:
    """The first of PROJECT_PLAN.md and docs/plans/PROJECT_PLAN.md that exists under `root`, else ""."""
    for candidate in PLAN_CANDIDATES:
        path = os.path.join(root, candidate)
        if os.path.isfile(path):
            return path
    return ""


def source_dir() -> str:
    """The directory holding the `borg_core` package this command runs from: what the skill puts on PYTHONPATH."""
    return os.path.realpath(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))


def git_status(root: str, budget: Budget) -> tuple[str | None, str]:
    """`(output, "")` for `git status --short --branch`, or `(None, reason)`."""
    if not shutil.which("git"):
        return None, "git not installed"
    answer = _run(
        ["git", "--no-optional-locks", "-C", root, "status", "--short", "--branch"], budget, GIT_TIMEOUT_SECONDS
    )
    if answer is None:
        return None, "git status did not answer in time"
    if answer[0] != 0:
        return None, f"git status exited {answer[0]} (not a repository?)"
    return answer[1], ""


def manifest_resolve(root: str) -> tuple[str, str]:
    """`(stem, "")` when `manifest resolve` exits 0, else `("", first line of its stderr)`. Read-only, in process."""
    out, err = io.StringIO(), io.StringIO()
    code: int | str | None
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
        try:
            code = manifest_cli.main(["resolve", "--repository", root])
        except SystemExit as exc:
            code = exc.code if exc.code is not None else 2
    stem = (out.getvalue().strip().splitlines() or [""])[0]
    if code == 0 and stem:
        return stem, ""
    reason = (err.getvalue().strip().splitlines() or ["resolve refused without a reason"])[0]
    return "", reason


def pull_request(root: str, budget: Budget) -> tuple[str, str, str]:
    """`(owner/repo#N, url, "")` for the current branch's PR, or `("", "", reason)`."""
    if not shutil.which("gh"):
        return "", "", "gh not installed"
    if shutil.which("git"):
        head = _run(["git", "-C", root, "symbolic-ref", "--short", "-q", "HEAD"], budget, GIT_TIMEOUT_SECONDS)
        if head is not None and head[0] == 1:
            return "", "", "detached HEAD"
    answer = _run(["gh", "pr", "view", "--json", "number,url"], budget, GH_TIMEOUT_SECONDS, cwd=root)
    if answer is None:
        return "", "", "gh did not answer in time (or could not start)"
    if answer[0] != 0:
        return "", "", f"gh pr view exited {answer[0]} (no pull request for this branch, or gh is not authenticated)"
    return _pr_from_json(answer[1])


def _pr_from_json(raw: str) -> tuple[str, str, str]:
    """`(owner/repo#N, url, "")` from `gh pr view --json number,url` output, or `("", "", reason)`.

    The reference is built from the VALIDATED url, never from free text: the url must be an https pull-request url
    whose number agrees with the `number` field, and owner and repository are matched against a narrow class.
    """
    try:
        doc = json.loads(raw)
        number, url = int(doc["number"]), str(doc["url"])
    except (ValueError, KeyError, TypeError):
        return "", "", "gh answered with an unexpected shape"
    match = _PR_URL.match(url)
    if not match:
        return "", "", "gh answered with a URL that is not a pull request URL"
    # JUSTIFICATION: stdlib `re.Match` accessor on a value this function just produced, not a cross-layer reach.
    owner, repo, digits = match.groups()  # pylint: disable=clean-arch-demeter
    if int(digits) != number:
        return "", "", "gh answered with a URL that is not a pull request URL"
    return f"{owner}/{repo}#{number}", url, ""


def _read_layer(path: str) -> prepare.ExtensionLayer | None:
    """The extension file at `path`, bounded, or None when it is absent or unreadable (the loader's contract)."""
    try:
        with open(path, "rb") as handle:
            raw = handle.read(READ_CAP_BYTES + 1)
            size = os.fstat(handle.fileno()).st_size
    except OSError:
        return None
    body = raw[:READ_CAP_BYTES].decode("utf-8", errors="replace")
    return prepare.ExtensionLayer(path=path, body=body, total_bytes=size if len(raw) > READ_CAP_BYTES else 0)


def _precedence(layers: dict) -> str:
    present = [name for name in ext_core.LAYERS if layers.get(name)]
    if not present:
        return prepare.NO_EXTENSION
    if len(present) == 1:
        return f"only the {present[0]} layer is present"
    note = "both layers present; "
    if ext_core.winner(layers) == ext_core.MACHINE:
        note += "the machine layer wins because a Prefer-tool is declared"
    else:
        note += "the repository layer wins for prose (the machine file is read first, the repository file extends it)"
    return note + ("; both assert the same key" if ext_core.conflicted(layers) else "")


def extensions(root: str) -> tuple[tuple[prepare.Extension, ...], tuple[prepare.PreferRow, ...]]:
    """Every borg-link-up hook's two layers with the precedence note, and the resolved prefer-tool rows."""
    found: list[prepare.Extension] = []
    rows: list[prepare.PreferRow] = []
    for hook in ext_core.PROSE_HOOKS:
        paths = ext_shell.layer_paths(SKILL_KIND, SKILL_SUBJECT, hook, root)
        read = {layer: _read_layer(path) for layer, path in paths.items()}
        parsed = {}
        for layer, item in read.items():
            if item is not None:
                parsed[layer] = ext_core.parse(item.body)
                parsed[layer]["path"] = item.path
        found.append(
            prepare.Extension(
                hook=hook,
                machine=read[ext_core.MACHINE],
                repository=read[ext_core.REPOSITORY],
                precedence=_precedence(parsed),
            )
        )
        winner = parsed.get(ext_core.winner(parsed), {})
        if winner.get("type") == ext_core.TYPE_PREFER_TOOL:
            rows.append(
                prepare.PreferRow(
                    hook=hook,
                    layer=ext_core.winner(parsed),
                    status=ext_core.status(winner, ext_shell.probe(winner)),
                    prefer=winner.get("prefer", ""),
                    instead_of=winner.get("instead_of", ""),
                )
            )
    return tuple(found), tuple(rows)


class Reader:
    """Runs the read steps under one budget, turning any failure into a recorded problem.

    Nothing escapes `step`: a step is a field of the document, not a crash. The problems it collects become the
    STATUS line.
    """

    def __init__(self) -> None:
        self.budget = Budget()
        self.problems: list[str] = []

    def note(self, problem: str) -> None:
        """Record a problem found outside a step (an unusable cwd)."""
        if problem:
            self.problems.append(problem)

    def step(self, name: str, default, call):
        """`call()`, or `default` with the failure recorded as a problem."""
        try:
            return call()
        # JUSTIFICATION: the exit-0-always contract; a failed read must become a field, never a crash.
        except Exception as exc:  # pylint: disable=broad-exception-caught
            self.problems.append(f"{name} failed: {type(exc).__name__}: {exc}")
            return default


def _cwd_problem(here: str) -> str:
    """Why `here` cannot be prepared for, or "" when it can."""
    if not os.path.isdir(here):
        return f"cwd is not a directory: {here}"
    if not os.access(here, os.R_OK | os.X_OK):
        return f"cwd is not readable: {here}"
    return ""


def gather(cwd: str = "", session: str = "") -> prepare.Facts:
    """Read every input once and return the facts `prepare.render` turns into the document."""
    return _read_all(Reader(), os.path.abspath(cwd or os.getcwd()), session)


def _read_all(reader: Reader, here: str, session: str) -> prepare.Facts:
    reader.note(_cwd_problem(here))
    budget = reader.budget
    root = reader.step("repository root", here, lambda: repository_root(here, budget))
    path = reader.step(
        "checkpoint path",
        "unknown",
        lambda: prepare.first_free_path(root, name_shell.checkpoint_stem(session, now()), os.path.exists),
    )
    plan = reader.step("plan lookup", "", lambda: plan_path(root))
    source = reader.step("source dir", "unknown", source_dir)
    git = reader.step("git status", (None, "git status failed"), lambda: git_status(root, budget))
    manifest = reader.step(
        "manifest resolve",
        ("", "manifest resolve failed"),
        lambda: manifest_resolve(root),
    )
    pr = reader.step(
        "pull request lookup",
        ("", "", "lookup failed"),
        lambda: pull_request(root, budget),
    )
    found, rows = reader.step("extension read", ((), ()), lambda: extensions(root))
    return prepare.Facts(
        root=root,
        checkpoint_path=path,
        plan=plan,
        source_dir=source,
        git_status=git[0],
        git_reason=git[1],
        manifest_stem=manifest[0],
        manifest_refusal=manifest[1],
        pr_ref=pr[0],
        pr_url=pr[1],
        pr_reason=pr[2],
        prefer=rows,
        extensions=found,
        problems=tuple(reader.problems),
    )
