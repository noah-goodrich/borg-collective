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
  3. refuse a `*.json` entry of a source directory is not a regular file (a symlink, live or dangling, a
            directory, a special file): moving it would strand its link text or lose it, so the person moves it.
  4. nothing no manifest in either source directory. A second run lands here, which is what makes it a no-op.
  5. refuse `.stacks` exists and is not a plain directory.
  6. refuse git would ignore a path inside `.stacks/`: the always-version-controlled rule could not hold.
            The reason names each ignored destination and the rule that ignores it.
  7. refuse a file name exists in two of the three directories, ANY kind of entry counting as present in
            `.stacks/`, since moving would clobber one.
  8. skip   a state the person can clear: a merge, rebase, cherry-pick or revert in progress, a locked index,
            a directory that is not writable, or an uncommitted change under a source directory.
  9. migrate: one `Move` per manifest.

REFUSALS COME BEFORE THE SKIPS because they do not go away when the user commits; the skips do. The dry
run predicts every one of them, because every one is a fact `migrate_shell.gather` observes, not a failure
the real run discovers part-way. A manifest git IGNORES is not an uncommitted change, it is the case rule 9
moves and stages. `--ignored` on the status call is what makes that visible at all.

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
# What each git state file means, by the name `git rev-parse --git-path` resolves. Two names, one rebase.
OPERATIONS = {
    "MERGE_HEAD": "a merge",
    "CHERRY_PICK_HEAD": "a cherry-pick",
    "REVERT_HEAD": "a revert",
    "rebase-merge": "a rebase",
    "rebase-apply": "a rebase",
}
# The repository directory itself stands in `Facts.unwritable` for "`.stacks/` would have to be created here".
REPOSITORY_ROOT = "."


@dataclass(frozen=True)
# JUSTIFICATION: fifteen plain facts gathered by `migrate_shell.gather`; bundling them would only rename them.
class Facts:  # pylint: disable=too-many-instance-attributes
    """What the shell observed about one repository directory. Raw where git is the source.

    `kinds` and `listings` are keyed by repository-relative directory (`SOURCE_DIRS` and `STACKS_DIR`):
    `kinds` is `KIND_*`, `listings` the `.json` file names in a plain directory. A SOURCE listing holds
    regular files only; the `.stacks` listing holds EVERY `.json` entry whatever it is, because any entry
    there is a destination that is not free. `irregular` maps the repository-relative path of each
    `.json` entry that is not a regular file (in a source directory or in `.stacks`) to its kind: "symlink",
    "dangling symlink", "directory" or "special file". `ls_files` and `status` are git's own NUL-separated
    output, restricted to `SOURCE_DIRS`. `error` is set when a git probe failed: a repository nobody could
    read is skipped, never treated as clean. `stacks_index` is `git ls-files -z` and `stacks_status` is
    `git status --porcelain=v1 -z`, both restricted to `.stacks`: they name destinations git still holds
    (in the index, or staged for deletion) that the working tree does not show, which a directory listing
    cannot see. `stacks_ignore` is `git check-ignore -v` over the destinations: raw, so the rule behind
    each ignored one is named. `operations` are the `OPERATIONS` state names that exist, `index_locked` is
    an `index.lock`, and `unwritable` the directories the move must write that this process cannot
    (`REPOSITORY_ROOT` standing for the parent of a `.stacks` that does not exist yet).
    """

    path: str
    exists: bool = True
    in_git: bool = True
    kinds: Mapping[str, str] = field(default_factory=dict)
    listings: Mapping[str, tuple[str, ...]] = field(default_factory=dict)
    ls_files: str = ""
    status: str = ""
    stacks_ignore: str = ""
    error: str = ""
    stacks_index: str = ""
    stacks_status: str = ""
    irregular: Mapping[str, str] = field(default_factory=dict)
    operations: tuple[str, ...] = ()
    index_locked: bool = False
    unwritable: tuple[str, ...] = ()


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


@dataclass(frozen=True)
class Execution:
    """What carrying out a `migrate` plan did: `failure` is "" on success, `moved` counts the files that landed.

    `moved` is true of a part-way failure too (the moves before the failing one, and the failing file itself
    when it sits in `.stacks/` unstaged), so the closing summary can say what actually happened.
    """

    failure: str = ""
    moved: int = 0


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


def parse_ignore_rules(text: str) -> list[tuple[str, str]]:
    """`[(path, "source:line:pattern"), ...]` of the paths git IGNORES, from `git check-ignore -v`.

    A line is `source:line:pattern`, a tab, then the path (git quotes an unusual path as it would for any
    status output; it is named as git printed it). `-z` is not an option here, since git only accepts it with
    `--stdin`. `-v` also reports a path that matched a NEGATED pattern (`!keep`), and that path is not
    ignored, so those are dropped here: the exit status of the probe cannot tell the two apart per path, and
    the refusal must name only real ignores. A line that does not parse is dropped, never guessed at.
    """
    rules: list[tuple[str, str]] = []
    for line in text.splitlines():
        rule, tab, path = line.partition("\t")
        pattern = _rule_pattern(rule) if tab else ""
        if pattern and not pattern.startswith("!"):
            rules.append((path, rule))
    return rules


def _rule_pattern(rule: str) -> str:
    """The pattern of a `source:line:pattern` rule, or "" when it does not have that shape.

    The line number is the first all-digit field after the source, so a pattern that itself holds a colon
    survives whole.
    """
    pieces = rule.split(":")
    for index in range(1, len(pieces) - 1):
        if pieces[index].isdigit():
            return ":".join(pieces[index + 1 :])
    return ""


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


def _held_in_stacks(facts: Facts) -> list[str]:
    """Manifest names git holds under `.stacks/` that a directory listing may not show.

    An index entry (tracked, or staged and then deleted from the tree) and a path staged for deletion both
    mean the destination is not free: `git mv` over it would replace what git, not the disk, remembers.
    """
    prefix = f"{STACKS_DIR}/"
    paths = parse_nul(facts.stacks_index) + [p for code, p in parse_status(facts.stacks_status) if "D" in code]
    names = [p[len(prefix) :] for p in paths if p.startswith(prefix)]
    return sorted({n for n in names if "/" not in n and n.endswith(".json")})


def _clashes(facts: Facts) -> list[str]:
    """One phrase per file name present in more than one of the three directories (case-insensitively).

    The `.stacks` side is the union of its listing (every kind of entry) and what git holds there, each name
    once; a destination that is not a regular file is named with its kind.
    """
    homes: dict[str, list[str]] = {}
    for directory in (*SOURCE_DIRS, STACKS_DIR):
        names = set(facts.listings.get(directory, ()))
        if directory == STACKS_DIR:
            names |= set(_held_in_stacks(facts))
        for name in sorted(names):
            homes.setdefault(name.casefold(), []).append(_labelled(facts, f"{directory}/{name}"))
    return [" and ".join(paths) for paths in homes.values() if len(paths) > 1]


def _labelled(facts: Facts, path: str) -> str:
    """`path`, followed by its kind in parentheses when it is an entry that is not a regular file."""
    kind = facts.irregular.get(path)
    return f"{path} (a {kind})" if kind else path


def _dirty(facts: Facts) -> list[str]:
    return [f"{path} ({_describe(code)})" for code, path in parse_status(facts.status) if code != _IGNORED]


def _irregular_sources(facts: Facts) -> list[str]:
    """One phrase per `.json` entry of a source directory that is not a regular file, in path order."""
    prefix = f"{STACKS_DIR}/"
    return [
        f"{path} is a {kind}, not a regular file; move it by hand"
        for path, kind in sorted(facts.irregular.items())
        if not path.startswith(prefix)
    ]


def _source_refusal(facts: Facts) -> str:
    """Rules 2 and 3: the reason a source directory or a `.json` entry in one cannot be reasoned about, or ""."""
    odd = [d for d in SOURCE_DIRS if facts.kinds.get(d, KIND_ABSENT) == KIND_OTHER]
    if odd:
        return f"{', '.join(odd)} is not a plain directory (a symlink?)"
    irregular = _irregular_sources(facts)
    return "; ".join(irregular) + ", then run this again" if irregular else ""


def _structural_refusal(facts: Facts) -> str:
    """The reason this repository cannot be migrated however clean it is, or "". Rules 5 to 7."""
    if facts.kinds.get(STACKS_DIR, KIND_ABSENT) == KIND_OTHER:
        return f"{STACKS_DIR} exists and is not a plain directory (a file or a symlink)"
    ignored = parse_ignore_rules(facts.stacks_ignore)
    if ignored:
        named = ", ".join(f"{path} ({rule})" for path, rule in ignored)
        return (
            f"git ignores {named}; {STACKS_DIR}/ is always version-controlled, so the manifests cannot be "
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
    source_refusal = _source_refusal(facts)
    if source_refusal:
        return RepositoryPlan(path, OUTCOME_REFUSE, source_refusal)
    manifests = _manifests(facts)
    if not manifests:
        return RepositoryPlan(path, OUTCOME_NOTHING, "no manifests under .borg/chains or .borg/programs")
    refusal = _structural_refusal(facts)
    if refusal:
        return RepositoryPlan(path, OUTCOME_REFUSE, refusal)
    cleared_by_the_person = _skip_reason(facts)
    if cleared_by_the_person:
        return RepositoryPlan(path, OUTCOME_SKIP, cleared_by_the_person)
    return _moves(facts, manifests)


def _skip_reason(facts: Facts) -> str:
    """Rule 8: why this repository is skipped for now, or "". Each is something the person can clear."""
    if facts.operations:
        what = ", ".join(sorted({OPERATIONS.get(name, name) for name in facts.operations}))
        return (
            f"{what} is in progress ({', '.join(facts.operations)} exists), and a commit of the moves would be "
            "refused: finish or abort it, then run this again"
        )
    if facts.index_locked:
        return "the git index is locked (index.lock exists): wait for the other git process, or remove a stale lock"
    if facts.unwritable:
        named = ", ".join(_unwritable_name(directory) for directory in facts.unwritable)
        return f"not writable, so manifests cannot be moved: {named}"
    dirty = _dirty(facts)
    if dirty:
        return f"uncommitted changes under the source directory: {', '.join(dirty)}"
    return ""


def _unwritable_name(directory: str) -> str:
    if directory == REPOSITORY_ROOT:
        return f"the repository directory ({STACKS_DIR}/ would be created there)"
    return directory


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


def summary(plans: list[RepositoryPlan], dry_run: bool, partial: Mapping[str, int] | None = None) -> str:
    """One closing line: how many repositories and manifests moved (or would), and how many were not done.

    `plans` are the repositories whose run did not fail; `partial` maps a repository that failed part-way to
    the number of its manifests that landed anyway, so the count says what is on disk. This line is the ONE
    place the skipped-or-refused count is printed (the exit status carries it to a script).
    """
    migrating = [p for p in plans if p.outcome == OUTCOME_MIGRATE]
    landed = {path: count for path, count in (partial or {}).items() if count}
    manifests = sum(len(p.moves) for p in migrating) + sum(landed.values())
    verb = "would migrate" if dry_run else "migrated"
    text = f"stack migrate: {verb} {manifests} manifest(s) in {len(migrating) + len(landed)} repository(ies)"
    left = incomplete(plans)
    if left:
        text += f"; {len(left)} skipped or refused and left untouched"
    return text
