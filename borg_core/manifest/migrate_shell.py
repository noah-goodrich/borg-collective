"""The impure half of `borg stack migrate`: gather the facts `migrate.plan_repository` decides on, then execute.

`gather` observes one repository (the filesystem and six read-only git probes) and hands the answer to the
pure planner as data. `execute` carries out a `migrate` plan with `git mv`, or a move and a `git add`, and
never commits. Every subprocess goes through `borg_core.proc`, the one place borg_core forks.

READ-ONLY MEANS READ-ONLY: `git --no-optional-locks status` is used because a plain `git status` may refresh
and rewrite `.git/index` as a side effect, and a `--dry-run` that changes the index is not a dry run.
`--untracked-files=normal` is passed explicitly because `status.showUntrackedFiles=no` in a user's config
would otherwise hide exactly the untracked manifests the dirty check exists to find.

A git probe that fails is recorded in `Facts.error`, never read as an empty answer: an unreadable repository
is skipped by name, not mistaken for a clean one.
"""

from __future__ import annotations

import os
import shutil
import stat
from typing import Any

from borg_core import proc
from borg_core.manifest import migrate, shell

GIT_TIMEOUT_SECONDS = 30


def _git(path: str, *args: str) -> tuple[int, str] | None:
    return proc.run_capture(["git", "--no-optional-locks", "-C", path, *args], timeout=GIT_TIMEOUT_SECONDS)


def _kind(path: str) -> str:
    """`migrate.KIND_*` of one path, by `lstat`, so a symlink is "other" and never followed."""
    try:
        mode = os.lstat(path).st_mode
    except FileNotFoundError:
        return migrate.KIND_ABSENT
    except OSError:
        return migrate.KIND_OTHER
    return migrate.KIND_DIRECTORY if stat.S_ISDIR(mode) else migrate.KIND_OTHER


def _json_names(directory: str) -> tuple[str, ...]:
    """The `.json` regular files in one directory, sorted. An unreadable directory is an error, not empty."""
    return tuple(
        sorted(n for n in os.listdir(directory) if n.endswith(".json") and os.path.isfile(os.path.join(directory, n)))
    )


def _top_level(path: str) -> bool:
    """True when `path` is the top level of a git working tree (an empty `--show-prefix`)."""
    captured = _git(path, "rev-parse", "--show-prefix")
    return captured is not None and captured[0] == 0 and captured[1].strip() == ""


def gather(path: str) -> migrate.Facts:
    """Everything the planner needs about one repository directory. Writes nothing."""
    if not os.path.isdir(path):
        return migrate.Facts(path, exists=False)
    if not _top_level(path):
        return migrate.Facts(path, in_git=False)
    directories = (*migrate.SOURCE_DIRS, migrate.STACKS_DIR)
    kinds = {d: _kind(os.path.join(path, d)) for d in directories}
    try:
        listings = {d: _json_names(os.path.join(path, d)) for d in directories if kinds[d] == migrate.KIND_DIRECTORY}
    except OSError as exc:
        return migrate.Facts(path, error=str(exc))
    sources = [n for d in migrate.SOURCE_DIRS for n in listings.get(d, ())]
    ls_files = _git(path, "ls-files", "-z", "--", *migrate.SOURCE_DIRS)
    status = _git(
        path, "status", "--porcelain=v1", "-z", "--ignored", "--untracked-files=normal", "--", *migrate.SOURCE_DIRS
    )
    stacks_index = _git(path, "ls-files", "-z", "--", migrate.STACKS_DIR)
    stacks_status = _git(path, "status", "--porcelain=v1", "-z", "--untracked-files=normal", "--", migrate.STACKS_DIR)
    if (
        ls_files is None
        or status is None
        or stacks_index is None
        or stacks_status is None
        or any(probe[0] != 0 for probe in (ls_files, status, stacks_index, stacks_status))
    ):
        return migrate.Facts(path, error="git ls-files or git status failed")
    ignored = False
    # Not probed when `.stacks` is a symlink or a file: git refuses a path beyond a symlink, and the planner
    # refuses that repository by name first, which is the better answer.
    if sources and kinds[migrate.STACKS_DIR] != migrate.KIND_OTHER:
        probe = _git(path, "check-ignore", "--", *[migrate.destination(n) for n in sources])
        if probe is None or probe[0] not in (0, 1):
            return migrate.Facts(path, error="git check-ignore failed")
        ignored = probe[0] == 0
    return migrate.Facts(
        path, True, True, kinds, listings, ls_files[1], status[1], ignored, "", stacks_index[1], stacks_status[1]
    )


def _index_holds(path: str, dest: str) -> str:
    """Why `dest` is not free in the git index, or "". `lexists` cannot see an entry the tree lacks."""
    held = _git(path, "ls-files", "-z", "--", dest)
    if held is None or held[0] != 0:
        return f"could not tell whether git holds {dest}"
    return f"{dest} is already in the git index" if held[1].strip("\0") else ""


def _move_one(path: str, move: migrate.Move) -> str:
    """Carry out one move; "" on success, else why not. A destination that exists is never overwritten."""
    source, dest = os.path.join(path, move.source), os.path.join(path, move.dest)
    if os.path.lexists(dest):
        return f"{move.dest} already exists"
    held = _index_holds(path, move.dest)
    if held:
        return held
    if move.tracked:
        captured = _git(path, "mv", "--", move.source, move.dest)
        return "" if captured is not None and captured[0] == 0 else f"git mv {move.source} failed"
    try:
        shutil.move(source, dest)
    except OSError as exc:
        return f"could not move {move.source}: {exc}"
    captured = _git(path, "add", "--", move.dest)
    if captured is None or captured[0] != 0:
        return f"moved {move.source} but git add {move.dest} failed"
    return ""


def execute(plan: migrate.RepositoryPlan) -> str:
    """Carry out a `migrate` plan, stopping at the first failure. "" on success, else what failed and what moved.

    The plan was decided on facts gathered a moment ago, so a failure here is rare (a locked index, a
    permission). It is reported with the moves already made so the person can finish or undo them by hand;
    there is no rollback to get wrong.
    """
    done: list[str] = []
    try:
        os.makedirs(os.path.join(plan.path, migrate.STACKS_DIR), exist_ok=True)
    except OSError as exc:
        return f"could not create {migrate.STACKS_DIR}/: {exc}"
    for move in plan.moves:
        problem = _move_one(plan.path, move)
        if problem:
            moved = f"; already moved: {', '.join(done)}" if done else "; nothing was moved"
            return f"{problem}{moved}"
        done.append(move.source)
    return ""


def registered_directories(registry: Any) -> tuple[list[str], list[str]]:
    """`(paths, warnings)` of every registered repository, deduplicated on `realpath`, registry order."""
    paths, warnings = shell.registered_paths(registry)
    seen: set[str] = set()
    unique: list[str] = []
    for path in paths:
        real = os.path.realpath(path)
        if real not in seen:
            seen.add(real)
            unique.append(path)
    return unique, warnings


def run(paths: list[str], dry_run: bool) -> list[tuple[migrate.RepositoryPlan, str]]:
    """Plan every path and, unless `dry_run`, execute each `migrate` plan. `[(plan, failure), ...]`."""
    results: list[tuple[migrate.RepositoryPlan, str]] = []
    for path in paths:
        plan = migrate.plan_repository(gather(path))
        failure = execute(plan) if plan.outcome == migrate.OUTCOME_MIGRATE and not dry_run else ""
        results.append((plan, failure))
    return results
