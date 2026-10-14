"""`borg stack migrate` over REAL throwaway git repositories.

Nothing here hands the planner a fact: every repository is built with `git init`, `git add` and `git commit`,
and `migrate_shell.gather` derives what the planner decides on. The cases are numbered after the safety
criterion of `docs/plans/directives/2026-10-13-chain-to-stack-rename.md`, section (b), items (1) to (9).
The registry is a throwaway file reached through `BORG_REGISTRY`, never the real one.
"""

from __future__ import annotations

import json
import os
import shlex
import subprocess

import pytest

from borg_core import proc
from borg_core.manifest import migrate, migrate_cli, migrate_shell

MANIFEST = '{"program": "%s", "rows": [{"order": "1", "ref": "o/r#%d"}]}\n'


def _git(repo, *args):
    done = subprocess.run(["git", "-C", repo, *args], check=True, capture_output=True, text=True)
    return done.stdout


def _write(repo, rel, body=None):
    path = os.path.join(repo, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    stem = os.path.splitext(os.path.basename(rel))[0]
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(body if body is not None else MANIFEST % (stem, len(stem)))
    return path


def _commit(repo, message="commit"):
    _git(repo, "add", "-A")
    _git(repo, "commit", "-q", "-m", message)


def _repo(tmp_path, name="repo", gitignore=""):
    """A real repository with one empty root commit, optionally with a committed .gitignore."""
    repo = str(tmp_path / name)
    os.makedirs(repo)
    _git(repo, "init", "-q")
    if gitignore:
        _write(repo, ".gitignore", gitignore)
    _git(repo, "commit", "-q", "--allow-empty", "-m", "root")
    if gitignore:
        _commit(repo, "ignore")
    return repo


# `.borg/*` ignores everything but the carve-out, the way this repository's own .gitignore does.
CARVED = ".borg/*\n!.borg/chains/\n!.borg/programs/\n"


def _snapshot(repo):
    """Every byte a migration could change: the tree, the index file, the index as git reads it, and HEAD."""
    files = {}
    for root, directories, names in os.walk(repo):
        if os.path.relpath(root, repo) == ".git":
            directories[:] = []
            names = ["index", "HEAD"]
        for name in names:
            full = os.path.join(root, name)
            with open(full, "rb") as handle:
                files[os.path.relpath(full, repo)] = handle.read()
        files.update({os.path.relpath(os.path.join(root, d), repo) + "/": b"" for d in directories if d != ".git"})
    return files, _git(repo, "ls-files", "-s", "--stage"), _git(repo, "status", "--porcelain", "--ignored")


@pytest.fixture(name="registry")
def _registry(tmp_path, monkeypatch):
    path = tmp_path / "registry.json"
    monkeypatch.setenv("BORG_REGISTRY", str(path))

    def register(**repositories):
        path.write_text(json.dumps({"projects": {k: {"path": v} for k, v in repositories.items()}}), encoding="utf-8")

    return register


def _run(capsys, *argv):
    code = migrate_cli.main(list(argv))
    captured = capsys.readouterr()
    return code, captured.out, captured.err


# ── (1) --dry-run ────────────────────────────────────────────────────────────────────────────────


def test_dry_run_prints_the_plan_and_leaves_the_repository_byte_identical(tmp_path, registry, capsys):
    repo = _repo(tmp_path, gitignore=CARVED + ".borg/chains/hidden.json\n")
    _write(repo, ".borg/chains/tracked.json")
    _commit(repo)
    _write(repo, ".borg/chains/hidden.json")
    registry(repo=repo)
    before = _snapshot(repo)

    code, out, _ = _run(capsys, "--dry-run")

    assert code == 0
    assert "would git mv: .borg/chains/tracked.json -> .stacks/tracked.json" in out
    assert "would move + git add: .borg/chains/hidden.json -> .stacks/hidden.json" in out
    assert "would track: .stacks/hidden.json (was ignored)" in out
    assert "would migrate 2 manifest(s)" in out
    assert _snapshot(repo) == before
    assert not os.path.exists(os.path.join(repo, ".stacks"))


def test_a_dry_run_and_the_real_run_print_the_same_plan(tmp_path, registry, capsys):
    repo = _repo(tmp_path, gitignore=CARVED)
    _write(repo, ".borg/chains/a.json")
    _commit(repo)
    registry(repo=repo)
    _, dry, _ = _run(capsys, "--dry-run")
    _, real, _ = _run(capsys)
    moves = [line for line in real.splitlines() if "git mv:" in line or "git add:" in line]
    assert moves == [line.replace("would ", "") for line in dry.splitlines() if "git mv:" in line or "git add:" in line]
    assert moves


# ── (4) tracked: git mv; ignored: plain move, then staged ───────────────────────────────────────


def test_a_tracked_manifest_moves_with_git_mv_and_an_ignored_one_is_moved_and_staged(tmp_path, registry, capsys):
    repo = _repo(tmp_path, gitignore=CARVED + ".borg/chains/hidden.json\n")
    tracked = _write(repo, ".borg/chains/tracked.json")
    _commit(repo)
    hidden = _write(repo, ".borg/chains/hidden.json")
    want = {name: open(path, "rb").read() for name, path in (("tracked", tracked), ("hidden", hidden))}
    registry(repo=repo)

    code, _, _ = _run(capsys)

    assert code == 0
    staged = _git(repo, "diff", "--cached", "--name-status", "-M").splitlines()
    assert staged == ["A\t.stacks/hidden.json", "R100\t.borg/chains/tracked.json\t.stacks/tracked.json"]
    assert open(os.path.join(repo, ".stacks/tracked.json"), "rb").read() == want["tracked"]
    assert open(os.path.join(repo, ".stacks/hidden.json"), "rb").read() == want["hidden"]
    assert not os.path.exists(tracked)
    assert not os.path.exists(hidden)


def test_the_legacy_programs_directory_moves_too(tmp_path, registry, capsys):
    repo = _repo(tmp_path, gitignore=CARVED)
    _write(repo, ".borg/programs/old.json")
    _commit(repo)
    registry(repo=repo)
    assert _run(capsys)[0] == 0
    assert _git(repo, "diff", "--cached", "--name-status", "-M").splitlines() == [
        "R100\t.borg/programs/old.json\t.stacks/old.json"
    ]


# ── (5) a second run, (6) nothing committed ─────────────────────────────────────────────────────


def test_a_second_run_moves_nothing_and_nothing_is_ever_committed(tmp_path, registry, capsys):
    repo = _repo(tmp_path, gitignore=CARVED)
    _write(repo, ".borg/chains/a.json")
    _commit(repo)
    registry(repo=repo)
    head = _git(repo, "rev-parse", "HEAD")

    assert _run(capsys)[0] == 0
    assert _git(repo, "rev-parse", "HEAD") == head
    after_first = _snapshot(repo)

    code, out, err = _run(capsys)
    assert (code, err) == (0, "")
    assert f"nothing to migrate: {repo}" in out
    assert _snapshot(repo) == after_first
    assert _git(repo, "rev-parse", "HEAD") == head

    _commit(repo, "the user commits")
    assert _run(capsys)[0] == 0


def test_the_printed_commit_command_commits_exactly_the_moves(tmp_path, registry, capsys):
    repo = _repo(tmp_path, gitignore=CARVED + ".borg/chains/hidden.json\n")
    _write(repo, ".borg/chains/tracked.json")
    _commit(repo)
    _write(repo, ".borg/chains/hidden.json")
    _write(repo, "unrelated.txt")
    _git(repo, "add", "unrelated.txt")
    registry(repo=repo)
    _, out, _ = _run(capsys)

    line = next(line for line in out.splitlines() if line.strip().startswith("to commit: "))
    subprocess.run(shlex.split(line.strip()[len("to commit: ") :]), check=True, capture_output=True)

    assert _git(repo, "diff", "--cached", "--name-only").split() == ["unrelated.txt"]
    assert _git(repo, "ls-files", ".stacks").split() == [".stacks/hidden.json", ".stacks/tracked.json"]


# ── (7) a git-ignored .borg/ ends tracked in .stacks/ ───────────────────────────────────────────


def test_a_repository_whose_chains_dir_is_ignored_ends_with_its_manifests_staged_in_stacks(tmp_path, registry, capsys):
    repo = _repo(tmp_path, gitignore=".borg/\n")
    for name in ("alpha.json", "beta.json"):
        _write(repo, f".borg/chains/{name}")
    assert _git(repo, "ls-files", ".borg").strip() == ""
    registry(repo=repo)
    head = _git(repo, "rev-parse", "HEAD")

    code, out, _ = _run(capsys)

    assert code == 0
    assert _git(repo, "diff", "--cached", "--name-only").split() == [".stacks/alpha.json", ".stacks/beta.json"]
    assert "now tracked: .stacks/alpha.json (was ignored)" in out
    assert "now tracked: .stacks/beta.json (was ignored)" in out
    assert out.count("now tracked:") == 2
    assert _git(repo, "rev-parse", "HEAD") == head


# ── (2) and (9): uncommitted manifest changes skip the repository ───────────────────────────────


def _modify(repo):
    _write(repo, ".borg/chains/a.json", '{"rows": [], "edited": true}\n')


def _stage(repo):
    _modify(repo)
    _git(repo, "add", ".borg/chains/a.json")


def _untracked_manifest(repo):
    _write(repo, ".borg/chains/new.json")


def _untracked_note(repo):
    _write(repo, ".borg/chains/NOTES.md", "scratch\n")


def _deleted(repo):
    os.unlink(os.path.join(repo, ".borg/chains/a.json"))


@pytest.mark.parametrize(
    "dirty",
    [_modify, _stage, _untracked_manifest, _untracked_note, _deleted],
    ids=["modified", "staged", "untracked-manifest", "untracked-other-file", "deleted"],
)
def test_a_repository_with_uncommitted_manifest_changes_is_skipped_by_name_and_untouched(
    tmp_path, registry, capsys, dirty
):
    repo = _repo(tmp_path, gitignore=CARVED)
    _write(repo, ".borg/chains/a.json")
    _write(repo, ".borg/chains/b.json")
    _commit(repo)
    dirty(repo)
    registry(repo=repo)
    before = _snapshot(repo)

    code, out, err = _run(capsys)

    assert code == 1
    assert f"skipped: {repo}: uncommitted changes" in out
    assert "were skipped or refused and left untouched" in err
    assert _snapshot(repo) == before


def test_status_show_untracked_files_no_does_not_hide_an_untracked_manifest(tmp_path, registry, capsys):
    repo = _repo(tmp_path, gitignore=CARVED)
    _write(repo, ".borg/chains/a.json")
    _commit(repo)
    _git(repo, "config", "status.showUntrackedFiles", "no")
    _untracked_manifest(repo)
    registry(repo=repo)
    before = _snapshot(repo)
    assert _run(capsys)[0] == 1
    assert _snapshot(repo) == before


# ── (3) a stem in both roots ────────────────────────────────────────────────────────────────────


@pytest.mark.parametrize("other", [".stacks/a.json", ".borg/programs/a.json"], ids=["stacks", "legacy-programs"])
def test_a_stem_in_both_roots_is_refused_by_name_and_untouched(tmp_path, registry, capsys, other):
    repo = _repo(tmp_path, gitignore=CARVED)
    _write(repo, ".borg/chains/a.json")
    _write(repo, ".borg/chains/b.json")
    _write(repo, other, '{"rows": []}\n')
    _commit(repo)
    registry(repo=repo)
    before = _snapshot(repo)

    code, out, _ = _run(capsys)

    assert code == 1
    assert f"refused: {repo}: " in out
    assert f".borg/chains/a.json and {other}" in out
    assert _snapshot(repo) == before


# ── (8) .stacks/ would be ignored ───────────────────────────────────────────────────────────────


@pytest.mark.parametrize(
    "rule",
    [".stacks/\n", ".stacks/*.json\n", "*.json\n!.borg/\n!.borg/chains/\n!.borg/chains/*.json\n"],
    ids=["dir", "files", "glob"],
)
def test_a_repository_whose_ignore_rules_would_ignore_stacks_is_refused_and_untouched(tmp_path, registry, capsys, rule):
    repo = _repo(tmp_path, gitignore=CARVED + rule)
    _write(repo, ".borg/chains/a.json")
    _git(repo, "add", "-f", ".borg/chains/a.json")
    _git(repo, "commit", "-q", "-m", "manifest")
    registry(repo=repo)
    before = _snapshot(repo)

    code, out, _ = _run(capsys)

    assert code == 1
    assert f"refused: {repo}: git ignores .stacks/" in out
    assert _snapshot(repo) == before
    assert not os.path.exists(os.path.join(repo, ".stacks"))


# ── skipped for being unreadable ────────────────────────────────────────────────────────────────


def test_a_directory_that_is_not_a_git_repository_is_skipped_by_name(tmp_path, registry, capsys):
    plain = str(tmp_path / "plain")
    _write(plain, ".borg/chains/a.json")
    registry(plain=plain)
    code, out, err = _run(capsys)
    assert code == 1
    assert f"skipped: {plain}: not a git repository" in out
    assert "skipped or refused" in err
    assert os.path.exists(os.path.join(plain, ".borg/chains/a.json"))


def test_a_subdirectory_of_a_repository_is_not_its_top_level_and_is_skipped(tmp_path, registry, capsys):
    repo = _repo(tmp_path, gitignore=CARVED)
    sub = os.path.join(repo, "packages", "web")
    _write(sub, ".borg/chains/a.json")
    registry(sub=sub)
    code, out, _ = _run(capsys)
    assert code == 1
    assert f"skipped: {sub}: not a git repository (or not the top level of one)" in out
    assert os.path.exists(os.path.join(sub, ".borg/chains/a.json"))


def test_a_registered_directory_that_is_gone_is_skipped_by_name(tmp_path, registry, capsys):
    gone = str(tmp_path / "gone")
    registry(gone=gone)
    code, out, _ = _run(capsys)
    assert code == 1
    assert f"skipped: {gone}: the directory does not exist" in out


def test_one_skipped_repository_does_not_stop_the_others_and_the_exit_says_so(tmp_path, registry, capsys):
    bad = _repo(tmp_path, "bad", gitignore=CARVED)
    _write(bad, ".borg/chains/a.json")
    _commit(bad)
    _untracked_manifest(bad)
    good = _repo(tmp_path, "good", gitignore=CARVED)
    _write(good, ".borg/chains/g.json")
    _commit(good)
    clean = _repo(tmp_path, "clean")
    registry(bad=bad, good=good, clean=clean)

    code, out, err = _run(capsys)

    assert code == 1
    assert f"skipped: {bad}: " in out
    assert f"nothing to migrate: {clean}" in out
    assert _git(good, "diff", "--cached", "--name-status", "-M").split() == [
        "R100",
        ".borg/chains/g.json",
        ".stacks/g.json",
    ]
    assert "migrated 1 manifest(s) in 1 repository(ies); 1 skipped or refused" in out
    assert "1 repository(ies) were skipped or refused" in err


def test_a_worktree_is_migrated_on_its_own_and_the_parents_move_does_not_chase_it(tmp_path, registry, capsys):
    repo = _repo(tmp_path, gitignore=CARVED)
    _write(repo, ".borg/chains/a.json")
    _commit(repo)
    worktree = str(tmp_path / "wt")
    _git(repo, "worktree", "add", "-q", "-b", "feature", worktree)
    registry(repo=repo)

    assert _run(capsys)[0] == 0
    assert os.path.exists(os.path.join(worktree, ".borg/chains/a.json"))
    assert not os.path.exists(os.path.join(worktree, ".stacks"))

    code, out, _ = _run(capsys, worktree)
    assert code == 0
    assert "git mv: .borg/chains/a.json -> .stacks/a.json" in out


# ── refusals for the filesystem's own oddities ──────────────────────────────────────────────────


def test_a_source_directory_that_is_a_symlink_is_refused_untouched(tmp_path, registry, capsys):
    repo = _repo(tmp_path, gitignore=CARVED)
    elsewhere = tmp_path / "elsewhere"
    _write(str(elsewhere), "a.json")
    os.makedirs(os.path.join(repo, ".borg"))
    os.symlink(str(elsewhere), os.path.join(repo, ".borg", "chains"))
    registry(repo=repo)
    code, out, _ = _run(capsys)
    assert code == 1
    assert f"refused: {repo}: .borg/chains is not a plain directory" in out
    assert (elsewhere / "a.json").exists()


@pytest.mark.parametrize("kind", ["file", "symlink"])
def test_a_stacks_that_is_not_a_plain_directory_is_refused_untouched(tmp_path, registry, capsys, kind):
    repo = _repo(tmp_path, gitignore=CARVED)
    _write(repo, ".borg/chains/a.json")
    _commit(repo)
    if kind == "file":
        _write(repo, ".stacks", "not a directory\n")
    else:
        os.symlink(str(tmp_path), os.path.join(repo, ".stacks"))
    registry(repo=repo)
    before = _snapshot(repo)
    code, out, _ = _run(capsys)
    assert code == 1
    assert f"refused: {repo}: .stacks exists and is not a plain directory" in out
    assert _snapshot(repo) == before


def test_a_json_directory_is_not_a_manifest(tmp_path, registry, capsys):
    repo = _repo(tmp_path, gitignore=CARVED)
    os.makedirs(os.path.join(repo, ".borg/chains/folder.json"))
    registry(repo=repo)
    assert _run(capsys)[0] == 0


# ── which repository: a name, a directory, or all ───────────────────────────────────────────────


def test_a_named_repository_alone_is_migrated(tmp_path, registry, capsys):
    one = _repo(tmp_path, "one", gitignore=CARVED)
    two = _repo(tmp_path, "two", gitignore=CARVED)
    for repo in (one, two):
        _write(repo, ".borg/chains/a.json")
        _commit(repo)
    registry(one=one, two=two)

    assert _run(capsys, "two")[0] == 0
    assert os.path.exists(os.path.join(two, ".stacks/a.json"))
    assert os.path.exists(os.path.join(one, ".borg/chains/a.json"))


def test_an_unregistered_directory_can_be_named_by_path(tmp_path, registry, capsys):
    repo = _repo(tmp_path, gitignore=CARVED)
    _write(repo, ".borg/chains/a.json")
    _commit(repo)
    registry()
    assert _run(capsys, repo)[0] == 0
    assert os.path.exists(os.path.join(repo, ".stacks/a.json"))


def test_naming_nothing_that_exists_is_a_usage_error(tmp_path, registry, capsys):
    registry()
    code, _, err = _run(capsys, "nope")
    assert code == 2
    assert "no repository named 'nope'" in err


def test_the_registry_is_read_and_never_created(tmp_path, monkeypatch, capsys):
    absent = tmp_path / "registry.json"
    monkeypatch.setenv("BORG_REGISTRY", str(absent))
    code, _, err = _run(capsys, "--dry-run")
    assert code == 1
    assert "no registry at" in err
    assert not absent.exists()


def test_a_corrupt_registry_is_named_and_not_overwritten(tmp_path, monkeypatch, capsys):
    broken = tmp_path / "registry.json"
    broken.write_text("{not json", encoding="utf-8")
    monkeypatch.setenv("BORG_REGISTRY", str(broken))
    code, _, err = _run(capsys)
    assert code == 1
    assert "unreadable" in err
    assert broken.read_text(encoding="utf-8") == "{not json"


def test_an_empty_registry_says_so(registry, capsys):
    registry()
    code, _, err = _run(capsys)
    assert code == 1
    assert "no repository paths" in err


def test_two_registry_entries_for_one_directory_are_migrated_once(tmp_path, registry, capsys):
    repo = _repo(tmp_path, gitignore=CARVED)
    _write(repo, ".borg/chains/a.json")
    _commit(repo)
    link = str(tmp_path / "link")
    os.symlink(repo, link)
    registry(one=repo, two=link)
    code, out, _ = _run(capsys)
    assert code == 0
    assert out.count("git mv: .borg/chains/a.json") == 1


def test_the_registry_warnings_are_passed_on(tmp_path, registry, capsys):
    repo = _repo(tmp_path)
    (tmp_path / "registry.json").write_text(
        json.dumps({"projects": {"ok": {"path": repo}, "nopath": {}}}), encoding="utf-8"
    )
    assert _run(capsys)[0] == 0


# ── failure paths: a git probe that fails is never read as an empty answer ──────────────────────


def _git_fails_for(monkeypatch, verb):
    real = proc.run_capture

    def fake(argv, timeout=None):
        return None if verb in argv else real(argv, timeout)

    monkeypatch.setattr(proc, "run_capture", fake)


@pytest.mark.parametrize("verb", ["status", "ls-files", "check-ignore"])
def test_a_failed_git_probe_skips_the_repository_instead_of_reading_it_as_clean(tmp_path, monkeypatch, verb):
    repo = _repo(tmp_path, gitignore=CARVED)
    _write(repo, ".borg/chains/a.json")
    _commit(repo)
    _git_fails_for(monkeypatch, verb)
    plan = migrate.plan_repository(migrate_shell.gather(repo))
    assert plan.outcome == migrate.OUTCOME_SKIP
    assert "could not read git state" in plan.reason


def test_a_failing_rev_parse_reads_as_not_a_repository(tmp_path, monkeypatch):
    repo = _repo(tmp_path)
    _git_fails_for(monkeypatch, "rev-parse")
    assert not migrate_shell.gather(repo).in_git


def test_an_unreadable_source_directory_is_an_error_and_not_an_empty_one(tmp_path):
    repo = _repo(tmp_path, gitignore=CARVED)
    _write(repo, ".borg/chains/a.json")
    chains = os.path.join(repo, ".borg/chains")
    os.chmod(chains, 0)
    try:
        plan = migrate.plan_repository(migrate_shell.gather(repo))
    finally:
        os.chmod(chains, 0o755)
    assert plan.outcome == migrate.OUTCOME_SKIP
    assert "could not read git state" in plan.reason


def test_a_destination_that_appears_after_the_plan_is_never_overwritten(tmp_path):
    repo = _repo(tmp_path, gitignore=CARVED)
    _write(repo, ".borg/chains/a.json")
    _write(repo, ".borg/chains/b.json")
    _commit(repo)
    plan = migrate.plan_repository(migrate_shell.gather(repo))
    _write(repo, ".stacks/b.json", "someone else's\n")

    failure = migrate_shell.execute(plan)

    assert failure == ".stacks/b.json already exists; already moved: .borg/chains/a.json"
    assert open(os.path.join(repo, ".stacks/b.json"), encoding="utf-8").read() == "someone else's\n"
    assert os.path.exists(os.path.join(repo, ".borg/chains/b.json"))


def test_a_failed_git_mv_is_reported_with_nothing_moved(tmp_path):
    repo = _repo(tmp_path, gitignore=CARVED)
    plan = migrate.RepositoryPlan(
        repo, migrate.OUTCOME_MIGRATE, "", (migrate.Move(".borg/chains/ghost.json", ".stacks/ghost.json", True),)
    )
    assert migrate_shell.execute(plan) == "git mv .borg/chains/ghost.json failed; nothing was moved"


def test_a_failed_move_or_add_is_reported(tmp_path, monkeypatch):
    repo = _repo(tmp_path)
    missing = migrate.RepositoryPlan(
        repo, migrate.OUTCOME_MIGRATE, "", (migrate.Move(".borg/chains/ghost.json", ".stacks/ghost.json", False),)
    )
    assert migrate_shell.execute(missing).startswith("could not move .borg/chains/ghost.json")

    _write(repo, ".borg/chains/a.json")
    real = proc.run_capture
    monkeypatch.setattr(proc, "run_capture", lambda argv, timeout=None: None if "add" in argv else real(argv, timeout))
    plan = migrate.RepositoryPlan(
        repo, migrate.OUTCOME_MIGRATE, "", (migrate.Move(".borg/chains/a.json", ".stacks/a.json", False),)
    )
    assert (
        migrate_shell.execute(plan) == "moved .borg/chains/a.json but git add .stacks/a.json failed; nothing was moved"
    )


def test_a_stacks_directory_that_cannot_be_created_is_reported(tmp_path):
    repo = _repo(tmp_path)
    _write(repo, ".stacks", "a file\n")
    plan = migrate.RepositoryPlan(repo, migrate.OUTCOME_MIGRATE, "", ())
    assert migrate_shell.execute(plan).startswith("could not create .stacks/")


def test_a_part_way_failure_is_printed_and_exits_non_zero(tmp_path, registry, capsys, monkeypatch):
    repo = _repo(tmp_path, gitignore=CARVED)
    _write(repo, ".borg/chains/a.json")
    _commit(repo)
    registry(repo=repo)
    monkeypatch.setattr(migrate_shell, "execute", lambda plan: "boom; nothing was moved")
    code, out, err = _run(capsys)
    assert code == 1
    assert f"failed: {repo}: boom; nothing was moved" in out
    assert "failed part-way" in err
    assert "migrated 0 manifest(s)" in out
