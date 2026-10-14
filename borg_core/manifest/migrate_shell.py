"""The impure half of `borg stack migrate`: gather the facts `migrate.plan_repository` decides on, then execute.

`gather` observes one repository (the filesystem and seven read-only git probes) and hands the answer to the
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
import stat
from typing import Any

from borg_core import proc
from borg_core.manifest import migrate, shell

GIT_TIMEOUT_SECONDS = 30
INDEX_LOCK = "index.lock"


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


def _entry_kind(path: str) -> str:
    """The word `file` for a regular file, else what it is. By `lstat`, so a symlink is never followed."""
    mode = os.lstat(path).st_mode
    if stat.S_ISREG(mode):
        return "file"
    if stat.S_ISLNK(mode):
        return "symlink" if os.path.exists(path) else "dangling symlink"
    return "directory" if stat.S_ISDIR(mode) else "special file"


def _json_entries(directory: str, everything: bool) -> tuple[tuple[str, ...], dict[str, str]]:
    """`(names, odd)` for the `.json` entries of one directory: `names` sorted, `odd` maps name to kind.

    Every entry is classified by `lstat`, never by `isfile`, which follows a link and so called a dangling
    link nothing and a live one a file. `odd` holds the entries that are not regular files. `names` is the
    regular files only (a source directory), or every entry (`everything`: `.stacks/`, where an entry of any
    kind is a destination that is taken). An unreadable directory is an error, not an empty one.
    """
    names: list[str] = []
    odd: dict[str, str] = {}
    for name in sorted(os.listdir(directory)):
        if not name.endswith(".json"):
            continue
        kind = _entry_kind(os.path.join(directory, name))
        if kind != "file":
            odd[name] = kind
        if kind == "file" or everything:
            names.append(name)
    return tuple(names), odd


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
    kinds = {d: _kind(os.path.join(path, d)) for d in (*migrate.SOURCE_DIRS, migrate.STACKS_DIR)}
    try:
        listings, irregular = _scan(path, kinds)
    except OSError as exc:
        return migrate.Facts(path, error=str(exc))
    sources = [n for d in migrate.SOURCE_DIRS for n in listings.get(d, ())]
    fields, error = _probe_git(path, kinds, sources)
    if error:
        return migrate.Facts(path, error=error)
    return migrate.Facts(
        path,
        kinds=kinds,
        listings=listings,
        irregular=irregular,
        unwritable=_unwritable(path, kinds, listings),
        **fields,
    )


def _scan(path: str, kinds: dict[str, str]) -> tuple[dict[str, tuple[str, ...]], dict[str, str]]:
    """`(listings, irregular)` for every plain directory among the three: the `Facts` fields of those names."""
    listings: dict[str, tuple[str, ...]] = {}
    irregular: dict[str, str] = {}
    for directory, kind in kinds.items():
        if kind == migrate.KIND_DIRECTORY:
            names, odd = _json_entries(os.path.join(path, directory), directory == migrate.STACKS_DIR)
            listings[directory] = names
            irregular.update({f"{directory}/{name}": odd_kind for name, odd_kind in odd.items()})
    return listings, irregular


def _probe_git(path: str, kinds: dict[str, str], sources: list[str]) -> tuple[dict[str, Any], str]:
    """`(fields, error)`: the git-derived `Facts` fields, or the reason a probe failed (never an empty answer)."""
    probes = {
        "ls_files": _git(path, "ls-files", "-z", "--", *migrate.SOURCE_DIRS),
        "status": _git(
            path, "status", "--porcelain=v1", "-z", "--ignored", "--untracked-files=normal", "--", *migrate.SOURCE_DIRS
        ),
        "stacks_index": _git(path, "ls-files", "-z", "--", migrate.STACKS_DIR),
        "stacks_status": _git(
            path, "status", "--porcelain=v1", "-z", "--untracked-files=normal", "--", migrate.STACKS_DIR
        ),
    }
    if any(probe is None or probe[0] != 0 for probe in probes.values()):
        return {}, "git ls-files or git status failed"
    fields: dict[str, Any] = {name: probe[1] for name, probe in probes.items() if probe is not None}
    fields["stacks_ignore"] = ""
    # Not probed when `.stacks` is a symlink or a file: git refuses a path beyond a symlink, and the planner
    # refuses that repository by name first, which is the better answer. `-v` names the rule behind each
    # ignored destination, for the refusal to say; the planner drops the negated matches `-v` also reports.
    if sources and kinds[migrate.STACKS_DIR] != migrate.KIND_OTHER:
        probe = _git(path, "check-ignore", "-v", "--", *[migrate.destination(n) for n in sources])
        if probe is None or probe[0] not in (0, 1):
            return {}, "git check-ignore failed"
        fields["stacks_ignore"] = probe[1]
    state = _git_state(path)
    if state is None:
        return {}, "git rev-parse --git-path failed"
    fields["operations"] = tuple(n for n in state if n in migrate.OPERATIONS)
    fields["index_locked"] = INDEX_LOCK in state
    return fields, ""


def _git_state(path: str) -> list[str] | None:
    """The names among `migrate.OPERATIONS` and `INDEX_LOCK` that exist, or None when git could not say.

    `git rev-parse --git-path <name>` is asked rather than `.git/<name>` spelled out, because in a linked
    worktree those files live in the worktree's own git directory and `.git` there is a file, not a directory.
    """
    names = (*migrate.OPERATIONS, INDEX_LOCK)
    argv = ["rev-parse"]
    for name in names:
        argv += ["--git-path", name]
    captured = _git(path, *argv)
    if captured is None or captured[0] != 0 or len(captured[1].splitlines()) != len(names):
        return None
    return [n for n, found in zip(names, captured[1].splitlines()) if os.path.lexists(os.path.join(path, found))]


def _unwritable(path: str, kinds: dict[str, str], listings: dict[str, tuple[str, ...]]) -> tuple[str, ...]:
    """The directories a move would have to write that this process cannot, so a dry run predicts the failure.

    Only the directories that matter: a source directory holding a manifest (the move removes a name from it)
    and `.stacks/`, or the repository directory when `.stacks/` is yet to be created. A repository with
    nothing to move is never reported, so "nothing to migrate" stays true of a read-only tree.
    """
    needed = [d for d in migrate.SOURCE_DIRS if listings.get(d)]
    if not needed:
        return ()
    written = {migrate.KIND_DIRECTORY: [migrate.STACKS_DIR], migrate.KIND_ABSENT: [migrate.REPOSITORY_ROOT]}
    needed += written.get(kinds[migrate.STACKS_DIR], [])
    return tuple(d for d in needed if not os.access(os.path.join(path, d), os.W_OK | os.X_OK))


def _index_holds(path: str, dest: str) -> str:
    """Why `dest` is not free in the git index, or "". `lexists` cannot see an entry the tree lacks."""
    held = _git(path, "ls-files", "-z", "--", dest)
    if held is None or held[0] != 0:
        return f"could not tell whether git holds {dest}"
    return f"{dest} is already in the git index" if held[1].strip("\0") else ""


def _move_one(path: str, move: migrate.Move) -> tuple[str, bool]:
    """Carry out one move; `(problem, landed)`. `problem` is "" on success, else why not.

    `landed` is True when the file is at its destination even though the move failed: an ignored manifest whose
    `git add` failed after the plain move, and which could not be put back, sits in `.stacks/` untracked, and
    the caller must say so. A destination that exists is never overwritten.

    The plain move is `os.rename`, never `shutil.move`: a rename is atomic and fails WITHOUT copying (a
    read-only source directory, a different filesystem), so a failed move leaves the file where it was. A copy
    followed by a failed unlink leaves it in both roots, and the report "nothing was moved" would be false.
    """
    if os.path.lexists(os.path.join(path, move.dest)):
        return f"{move.dest} already exists", False
    held = _index_holds(path, move.dest)
    if held:
        return held, False
    if move.tracked:
        captured = _git(path, "mv", "--", move.source, move.dest)
        return ("", False) if captured is not None and captured[0] == 0 else (f"git mv {move.source} failed", False)
    return _move_and_add(path, move)


def _move_and_add(path: str, move: migrate.Move) -> tuple[str, bool]:
    """The move of a manifest git ignores: rename it, then stage it; `(problem, landed)` as `_move_one`."""
    source, dest = os.path.join(path, move.source), os.path.join(path, move.dest)
    try:
        os.rename(source, dest)
    except OSError as exc:
        return f"could not move {move.source}: {exc}", False
    captured = _git(path, "add", "--", move.dest)
    if captured is not None and captured[0] == 0:
        return "", False
    # The one rollback there is: this file only, by the same atomic rename. Earlier moves stay and are listed.
    try:
        os.rename(dest, source)
    except OSError:
        return f"git add {move.dest} failed", True
    return f"git add {move.dest} failed and {move.source} was put back", False


def execute(plan: migrate.RepositoryPlan) -> migrate.Execution:
    """Carry out a `migrate` plan, stopping at the first failure. The failure says what failed and what moved.

    The plan was decided on facts gathered a moment ago, so a failure here is rare (a permission, a lock taken
    since). It is reported with the moves already made so the person can finish or undo them by hand; the only
    rollback is the one file whose `git add` failed (see `_move_one`). `.stacks/` is removed again (it only
    goes when empty) if this call created it and nothing landed in it, so a failed first move leaves the tree
    as it was. Emptied source directories are NOT removed: that belongs to step (c).
    """
    done: list[str] = []
    stacks = os.path.join(plan.path, migrate.STACKS_DIR)
    created = not os.path.lexists(stacks)
    try:
        os.makedirs(stacks, exist_ok=True)
    except OSError as exc:
        return migrate.Execution(f"could not create {migrate.STACKS_DIR}/: {exc}")
    for move in plan.moves:
        problem, landed = _move_one(plan.path, move)
        if problem:
            moved = len(done) + landed
            if created and not moved:
                _remove_if_empty(stacks)
            return migrate.Execution(_failure_report(problem, move, landed, done), moved)
        done.append(move.source)
    return migrate.Execution("", len(done))


def _remove_if_empty(directory: str) -> None:
    """`os.rmdir` removes an empty directory and nothing else; anything it cannot remove is left alone."""
    try:
        os.rmdir(directory)
    except OSError:
        pass


def _failure_report(problem: str, move: migrate.Move, landed: bool, done: list[str]) -> str:
    """The failure line: the problem, what moved before it, and the failing file itself if it did move."""
    moved = [f"already moved: {', '.join(done)}"] * bool(done)
    unstaged = [f"moved but NOT staged, run git add {move.dest}: {move.source} -> {move.dest}"] * landed
    nothing = ["nothing was moved"] * (not done and not landed)
    return "; ".join([problem, *moved, *unstaged, *nothing])


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


def run(paths: list[str], dry_run: bool) -> list[tuple[migrate.RepositoryPlan, migrate.Execution]]:
    """Plan every path and, unless `dry_run`, execute each `migrate` plan. `[(plan, execution), ...]`."""
    results: list[tuple[migrate.RepositoryPlan, migrate.Execution]] = []
    for path in paths:
        plan = migrate.plan_repository(gather(path))
        execution = execute(plan) if plan.outcome == migrate.OUTCOME_MIGRATE and not dry_run else migrate.Execution()
        results.append((plan, execution))
    return results
