"""`borg stack migrate`: the PURE planning core. Git facts in as data, a plan out, no I/O.

Step (b1) of `docs/plans/directives/2026-10-13-chain-to-stack-rename.md`. Every manifest under a
repository's `.borg/chains/` (and the legacy `.borg/programs/`) moves to `.stacks/`, and the `.stacks/`
folder is ALWAYS version-controlled (Noah, 2026-10-13). So a tracked manifest moves with `git mv`, and a
manifest git ignores is moved and then staged, which is the one place the move changes what a repository
shares.

`migrate_shell` gathers a `Facts` per repository (the filesystem and the git probes) and executes the
plan; `migrate_cli` is the argv seam. This module decides, and nothing here touches a disk, runs git or
reads the environment. The raw `-z` output of `git status` and `git ls-files` arrives as strings and is
parsed HERE, so the parse that decides "dirty" and "ignored" is covered by tests that need no repository.

THE DECISION LADDER, first match wins, and it is the whole safety argument:

  1. skip   the directory is gone, or is not the top level of a git repository, or git could not be read.
  2. refuse a source directory is not a plain directory (a symlink), so what is in it is not knowable.
  3. nothing no manifest in either source directory. A second run lands here, which is what makes it a no-op.
  4. refuse `.stacks` exists and is not a plain directory.
  5. refuse git would ignore a path inside `.stacks/`: the always-version-controlled rule could not hold.
  6. refuse a file name exists in two of the three directories, since moving would clobber one.
  7. skip   an uncommitted change under a source directory (modified, staged or untracked and not ignored).
  8. migrate: one `Move` per manifest.

REFUSALS COME BEFORE THE DIRTY SKIP because they do not go away when the user commits; the skip does.
A manifest git IGNORES is not an uncommitted change, it is the case rule 8 moves and stages. `--ignored`
on the status call is what makes that visible at all.

Skipping and refusing both leave the repository untouched, and the exit status says some were not done.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Mapping

STACKS_DIR = ".stacks"
# Source order is the order of precedence in a listing only; `manifest_dir` reads one of the two.
SOURCE_DIRS = (".borg/chains", ".borg/programs")

KIND_ABSENT = "absent"
KIND_DIRECTORY = "directory"
KIND_OTHER = "other"

OUTCOME_MIGRATE = "migrate"
OUTCOME_NOTHING = "nothing"
OUTCOME_SKIP = "skip"
OUTCOME_REFUSE = "refuse"

COMMIT_MESSAGE = "chore: move stack manifests to .stacks/"
_IGNORED = "!!"
_UNTRACKED = "??"


@dataclass(frozen=True)
# JUSTIFICATION: nine plain facts gathered by `migrate_shell.gather`; bundling them would only rename the fields.
class Facts:  # pylint: disable=too-many-instance-attributes
    """What the shell observed about one repository directory. Raw where git is the source.

    `kinds` and `listings` are keyed by repository-relative directory (`SOURCE_DIRS` and `STACKS_DIR`):
    `kinds` is `KIND_*`, `listings` the `.json` file names in a plain directory. `ls_files` and `status`
    are git's own NUL-separated output, restricted to `SOURCE_DIRS`. `error` is set when a git probe
    failed: a repository nobody could read is skipped, never treated as clean.
    """

    path: str
    exists: bool = True
    in_git: bool = True
    kinds: Mapping[str, str] = field(default_factory=dict)
    listings: Mapping[str, tuple[str, ...]] = field(default_factory=dict)
    ls_files: str = ""
    status: str = ""
    stacks_ignored: bool = False
    error: str = ""


@dataclass(frozen=True)
class Move:
    """One manifest: repository-relative `source` and `dest`; `tracked` picks `git mv` over move + add."""

    source: str
    dest: str
    tracked: bool


@dataclass(frozen=True)
class RepositoryPlan:
    """The decision for one repository: an outcome, why, and (for `migrate`) the moves in order."""

    path: str
    outcome: str
    reason: str = ""
    moves: tuple[Move, ...] = ()


def destination(name: str) -> str:
    """Where the manifest file `name` lands, repository-relative."""
    return f"{STACKS_DIR}/{name}"


def parse_nul(text: str) -> list[str]:
    """The non-empty tokens of git's `-z` output."""
    return [token for token in text.split("\0") if token]


def parse_status(text: str) -> list[tuple[str, str]]:
    """`[(XY, path), ...]` from `git status --porcelain=v1 -z`. A rename's origin token is consumed.

    With `-z` an entry is `XY path` and, when X or Y is a rename or a copy, the origin path follows as a
    token of its own. It carries no state of its own, so it is dropped here rather than misread as an
    entry that begins with two arbitrary characters.
    """
    tokens = parse_nul(text)
    entries: list[tuple[str, str]] = []
    index = 0
    while index < len(tokens):
        token = tokens[index]
        index += 1
        code, path = token[:2], token[3:]
        entries.append((code, path))
        if code[0] in "RC" or code[1] in "RC":
            index += 1
    return entries


def _is_ignored(path: str, ignored: list[str]) -> bool:
    """True when a `!!` entry names `path` itself or a directory holding it (git collapses those)."""
    return any(entry == path or (entry.endswith("/") and path.startswith(entry)) for entry in ignored)


def _describe(code: str) -> str:
    if code == _UNTRACKED:
        return "untracked"
    return "staged" if code[0] not in " ?" else "modified"


def _manifests(facts: Facts) -> list[tuple[str, str]]:
    """`[(directory, name), ...]` for every `.json` in a source directory, sources in order, names sorted."""
    return [(d, n) for d in SOURCE_DIRS for n in sorted(facts.listings.get(d, ()))]


def _clashes(facts: Facts) -> list[str]:
    """One phrase per file name present in more than one of the three directories (case-insensitively)."""
    homes: dict[str, list[str]] = {}
    for directory in (*SOURCE_DIRS, STACKS_DIR):
        for name in facts.listings.get(directory, ()):
            homes.setdefault(name.casefold(), []).append(f"{directory}/{name}")
    return [" and ".join(paths) for paths in homes.values() if len(paths) > 1]


def _dirty(facts: Facts) -> list[str]:
    return [f"{path} ({_describe(code)})" for code, path in parse_status(facts.status) if code != _IGNORED]


def _structural_refusal(facts: Facts) -> str:
    """The reason this repository cannot be migrated however clean it is, or "". Rules 4 to 6."""
    if facts.kinds.get(STACKS_DIR, KIND_ABSENT) == KIND_OTHER:
        return f"{STACKS_DIR} exists and is not a plain directory (a file or a symlink)"
    if facts.stacks_ignored:
        return (
            f"git ignores {STACKS_DIR}/, and it is always version-controlled, so the manifests cannot be "
            "moved there. Remove the ignore rule, then run this again"
        )
    clashes = _clashes(facts)
    if clashes:
        return f"the same file is in two roots, so moving would clobber one: {'; '.join(clashes)}"
    return ""


def _unreadable(facts: Facts) -> RepositoryPlan | None:
    """Rule 1: a skip when the directory cannot be reasoned about at all, else None."""
    reason = ""
    if not facts.exists:
        reason = "the directory does not exist"
    elif not facts.in_git:
        reason = "not a git repository (or not the top level of one)"
    elif facts.error:
        reason = f"could not read git state: {facts.error}"
    return RepositoryPlan(facts.path, OUTCOME_SKIP, reason) if reason else None


def plan_repository(facts: Facts) -> RepositoryPlan:
    """Decide what to do with one repository. See the module docstring for the ladder."""
    path = facts.path
    unreadable = _unreadable(facts)
    if unreadable:
        return unreadable
    odd = [d for d in SOURCE_DIRS if facts.kinds.get(d, KIND_ABSENT) == KIND_OTHER]
    if odd:
        return RepositoryPlan(path, OUTCOME_REFUSE, f"{', '.join(odd)} is not a plain directory (a symlink?)")
    manifests = _manifests(facts)
    if not manifests:
        return RepositoryPlan(path, OUTCOME_NOTHING, "no manifests under .borg/chains or .borg/programs")
    refusal = _structural_refusal(facts)
    if refusal:
        return RepositoryPlan(path, OUTCOME_REFUSE, refusal)
    dirty = _dirty(facts)
    if dirty:
        return RepositoryPlan(path, OUTCOME_SKIP, f"uncommitted changes under the source directory: {', '.join(dirty)}")
    return _moves(facts, manifests)


def _moves(facts: Facts, manifests: list[tuple[str, str]]) -> RepositoryPlan:
    """Rule 8: classify each manifest as tracked or ignored, or skip when git's answer is neither."""
    tracked = set(parse_nul(facts.ls_files))
    ignored = [path for code, path in parse_status(facts.status) if code == _IGNORED]
    moves: list[Move] = []
    for directory, name in manifests:
        source = f"{directory}/{name}"
        is_tracked = source in tracked
        if not is_tracked and not _is_ignored(source, ignored):
            return RepositoryPlan(facts.path, OUTCOME_SKIP, f"cannot tell whether {source} is tracked or ignored")
        moves.append(Move(source, destination(name), is_tracked))
    return RepositoryPlan(facts.path, OUTCOME_MIGRATE, "", tuple(moves))


def _quote(text: str) -> str:
    """POSIX shell quoting, written out because `shlex` is I/O-adjacent to the Domain linter: bare when safe."""
    if text and all(c.isalnum() or c in "/._-+=:@," for c in text):
        return text
    return "'" + text.replace("'", "'\\''") + "'"


def _commit_command(plan: RepositoryPlan) -> str:
    """A copy-pasteable commit of exactly these moves, scoped by pathspec so nothing else staged rides along."""
    paths = [m.source for m in plan.moves if m.tracked] + [m.dest for m in plan.moves]
    words = ["git", "-C", plan.path, "commit", "-m", COMMIT_MESSAGE, "--", *paths]
    return " ".join(_quote(word) for word in words)


def render(plan: RepositoryPlan, dry_run: bool) -> list[str]:
    """The lines to print for one repository. A dry run prints the same plan with `would` verbs."""
    if plan.outcome == OUTCOME_SKIP:
        return [f"skipped: {plan.path}: {plan.reason}"]
    if plan.outcome == OUTCOME_REFUSE:
        return [f"refused: {plan.path}: {plan.reason}"]
    if plan.outcome == OUTCOME_NOTHING:
        return [f"nothing to migrate: {plan.path}"]
    would = "would " if dry_run else ""
    lines = [plan.path]
    for move in plan.moves:
        verb = "git mv" if move.tracked else "move + git add"
        lines.append(f"  {would}{verb}: {move.source} -> {move.dest}")
        if not move.tracked:
            lines.append(f"  {'would track' if dry_run else 'now tracked'}: {move.dest} (was ignored)")
    lines.append(f"  {'after the real run, commit' if dry_run else 'to commit'}: {_commit_command(plan)}")
    return lines


def incomplete(plans: list[RepositoryPlan]) -> list[RepositoryPlan]:
    """The repositories that were skipped or refused: the ones that make the exit status non-zero."""
    return [p for p in plans if p.outcome in (OUTCOME_SKIP, OUTCOME_REFUSE)]


def summary(plans: list[RepositoryPlan], dry_run: bool) -> str:
    """One closing line: how many repositories and manifests moved (or would), and how many were not done."""
    migrating = [p for p in plans if p.outcome == OUTCOME_MIGRATE]
    manifests = sum(len(p.moves) for p in migrating)
    verb = "would migrate" if dry_run else "migrated"
    text = f"stack migrate: {verb} {manifests} manifest(s) in {len(migrating)} repository(ies)"
    left = incomplete(plans)
    if left:
        text += f"; {len(left)} skipped or refused and left untouched"
    return text
