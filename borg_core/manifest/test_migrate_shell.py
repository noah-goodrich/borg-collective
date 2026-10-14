"""`borg stack migrate` over REAL throwaway git repositories.

Nothing here hands the planner a fact: every repository is built with `git init`, `git add` and `git commit`,
and `migrate_shell.gather` derives what the planner decides on. The cases are numbered after the safety
criterion of `docs/plans/directives/2026-10-13-chain-to-stack-rename.md`, section (b), items (1) to (9).
The registry is a throwaway file reached through `BORG_REGISTRY`, never the real one.
"""

from __future__ import annotations

import errno
import json
import os
import shlex
import stat
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
            if os.path.islink(full):
                files[os.path.relpath(full, repo)] = b"-> " + os.readlink(full).encode()
                continue
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
    assert "1 skipped or refused and left untouched" in out
    assert "skipped or refused" not in err
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


def _destination_staged_then_deleted(repo):
    _write(repo, ".stacks/a.json", '{"only": "in the index"}\n')
    _git(repo, "add", ".stacks/a.json")
    os.unlink(os.path.join(repo, ".stacks/a.json"))


def _destination_tracked_then_deleted(repo):
    _write(repo, ".stacks/a.json", '{"committed": true}\n')
    _commit(repo, "track the destination")
    os.unlink(os.path.join(repo, ".stacks/a.json"))


def _destination_deletion_staged(repo):
    _write(repo, ".stacks/a.json", '{"committed": true}\n')
    _commit(repo, "track the destination")
    _git(repo, "rm", "-q", ".stacks/a.json")


@pytest.mark.parametrize(
    "setup",
    [_destination_staged_then_deleted, _destination_tracked_then_deleted, _destination_deletion_staged],
    ids=["staged-only-then-deleted", "tracked-then-deleted", "deletion-staged"],
)
@pytest.mark.parametrize("dry_run", [True, False], ids=["dry-run", "real"])
def test_a_destination_git_holds_but_the_tree_lacks_is_refused_by_name_and_untouched(
    tmp_path, registry, capsys, setup, dry_run
):
    repo = _repo(tmp_path, gitignore=CARVED)
    _write(repo, ".borg/chains/a.json")
    _commit(repo)
    setup(repo)
    registry(repo=repo)
    before = _snapshot(repo)

    code, out, _ = _run(capsys, *(["--dry-run"] if dry_run else []))

    assert code == 1
    assert f"refused: {repo}: " in out
    assert ".borg/chains/a.json and .stacks/a.json" in out
    assert _snapshot(repo) == before


def test_a_destination_that_enters_the_index_after_the_plan_is_never_replaced(tmp_path):
    repo = _repo(tmp_path, gitignore=CARVED)
    _write(repo, ".borg/chains/a.json")
    _commit(repo)
    plan = migrate.plan_repository(migrate_shell.gather(repo))
    _write(repo, ".stacks/a.json", "staged, then deleted\n")
    _git(repo, "add", ".stacks/a.json")
    os.unlink(os.path.join(repo, ".stacks/a.json"))
    before = _snapshot(repo)

    assert migrate_shell.execute(plan).failure == ".stacks/a.json is already in the git index; nothing was moved"
    assert _snapshot(repo) == before


def test_an_index_that_cannot_be_read_stops_the_move_instead_of_assuming_it_is_free(tmp_path, monkeypatch):
    repo = _repo(tmp_path, gitignore=CARVED)
    _write(repo, ".borg/chains/a.json")
    _commit(repo)
    plan = migrate.plan_repository(migrate_shell.gather(repo))
    _git_fails_for(monkeypatch, "ls-files")
    failure = migrate_shell.execute(plan).failure
    assert failure == "could not tell whether git holds .stacks/a.json; nothing was moved"
    assert os.path.exists(os.path.join(repo, ".borg/chains/a.json"))


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
    assert "1 skipped or refused" in out
    assert err == ""
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
    assert (out + err).count("skipped or refused") == 1
    assert err == ""


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


def test_a_json_directory_is_not_a_manifest_and_is_refused_not_silently_ignored(tmp_path, registry, capsys):
    """It was skipped as nothing; since H1 any `*.json` entry that is not a regular file refuses by name."""
    repo = _repo(tmp_path, gitignore=CARVED)
    os.makedirs(os.path.join(repo, ".borg/chains/folder.json"))
    registry(repo=repo)
    before = _snapshot(repo)
    code, out, _ = _run(capsys)
    assert code == 1
    assert f"refused: {repo}: .borg/chains/folder.json is a directory, not a regular file; move it by hand" in out
    assert _snapshot(repo) == before


# ── H1: a symlinked manifest ────────────────────────────────────────────────────────────────────


def _symlinked_manifest(repo, tmp_path):
    """A relative symlink: `a.json -> ../../real.json`. Moved with its text unchanged it would dangle in `.stacks/`."""
    _write(repo, "real.json")
    os.symlink("../../real.json", os.path.join(repo, ".borg/chains/a.json"))


def _dangling_manifest(repo, tmp_path):
    os.makedirs(os.path.join(repo, ".borg/chains"), exist_ok=True)
    os.symlink("nowhere.json", os.path.join(repo, ".borg/chains/a.json"))


def _symlinked_legacy_manifest(repo, tmp_path):
    os.makedirs(os.path.join(repo, ".borg/programs"), exist_ok=True)
    os.symlink(str(tmp_path / "elsewhere.json"), os.path.join(repo, ".borg/programs/a.json"))
    (tmp_path / "elsewhere.json").write_text("{}\n", encoding="utf-8")


@pytest.mark.parametrize(
    "build,kind,where",
    [
        (_symlinked_manifest, "symlink", ".borg/chains/a.json"),
        (_dangling_manifest, "dangling symlink", ".borg/chains/a.json"),
        (_symlinked_legacy_manifest, "symlink", ".borg/programs/a.json"),
    ],
    ids=["live-relative", "dangling", "legacy-root"],
)
@pytest.mark.parametrize("dry_run", [True, False], ids=["dry-run", "real"])
def test_a_symlinked_manifest_refuses_the_repository_by_name_and_leaves_it_untouched(
    tmp_path, registry, capsys, build, kind, where, dry_run
):
    repo = _repo(tmp_path, gitignore=CARVED)
    _write(repo, ".borg/chains/ok.json")
    _commit(repo)
    build(repo, tmp_path)
    registry(repo=repo)
    before = _snapshot(repo)
    link_text = os.readlink(os.path.join(repo, where))

    code, out, _ = _run(capsys, *(["--dry-run"] if dry_run else []))

    assert code == 1
    assert f"refused: {repo}: {where} is a {kind}, not a regular file; move it by hand" in out
    assert "nothing to migrate" not in out
    assert "git mv" not in out
    assert _snapshot(repo) == before
    assert os.readlink(os.path.join(repo, where)) == link_text
    assert not os.path.exists(os.path.join(repo, ".stacks"))


def test_a_dangling_link_alone_is_not_reported_as_nothing_to_migrate(tmp_path, registry, capsys):
    repo = _repo(tmp_path, gitignore=CARVED)
    _dangling_manifest(repo, tmp_path)
    registry(repo=repo)
    code, out, _ = _run(capsys)
    assert code == 1
    assert "nothing to migrate" not in out
    assert f"refused: {repo}: .borg/chains/a.json is a dangling symlink" in out


# ── H2: a destination that exists but is not a regular file ─────────────────────────────────────


def _dest_directory(repo, tmp_path):
    os.makedirs(os.path.join(repo, ".stacks/a.json"))


def _dest_symlink(repo, tmp_path):
    os.makedirs(os.path.join(repo, ".stacks"))
    (tmp_path / "target.json").write_text("{}\n", encoding="utf-8")
    os.symlink(str(tmp_path / "target.json"), os.path.join(repo, ".stacks/a.json"))


def _dest_dangling(repo, tmp_path):
    os.makedirs(os.path.join(repo, ".stacks"))
    os.symlink(str(tmp_path / "missing.json"), os.path.join(repo, ".stacks/a.json"))


@pytest.mark.parametrize(
    "build,kind",
    [(_dest_directory, "directory"), (_dest_symlink, "symlink"), (_dest_dangling, "dangling symlink")],
)
@pytest.mark.parametrize("dry_run", [True, False], ids=["dry-run", "real"])
def test_a_destination_that_is_not_a_regular_file_is_refused_by_the_dry_run_and_the_real_run_alike(
    tmp_path, registry, capsys, build, kind, dry_run
):
    """H2: the dry run used to say `would migrate` and the real run then failed part-way."""
    repo = _repo(tmp_path, gitignore=CARVED)
    _write(repo, ".borg/chains/a.json")
    _write(repo, ".borg/chains/b.json")
    _commit(repo)
    build(repo, tmp_path)
    registry(repo=repo)
    before = _snapshot(repo)

    code, out, _ = _run(capsys, *(["--dry-run"] if dry_run else []))

    assert code == 1
    assert f"refused: {repo}: " in out
    assert f".borg/chains/a.json and .stacks/a.json (a {kind})" in out
    assert "would git mv" not in out
    assert _snapshot(repo) == before
    assert os.path.exists(os.path.join(repo, ".borg/chains/b.json"))


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

    execution = migrate_shell.execute(plan)

    assert execution == migrate.Execution(".stacks/b.json already exists; already moved: .borg/chains/a.json", 1)
    assert open(os.path.join(repo, ".stacks/b.json"), encoding="utf-8").read() == "someone else's\n"
    assert os.path.exists(os.path.join(repo, ".borg/chains/b.json"))


def test_a_failed_git_mv_is_reported_with_nothing_moved(tmp_path):
    repo = _repo(tmp_path, gitignore=CARVED)
    plan = migrate.RepositoryPlan(
        repo, migrate.OUTCOME_MIGRATE, "", (migrate.Move(".borg/chains/ghost.json", ".stacks/ghost.json", True),)
    )
    assert migrate_shell.execute(plan).failure == "git mv .borg/chains/ghost.json failed; nothing was moved"


def test_a_failed_move_or_add_is_reported(tmp_path, monkeypatch):
    repo = _repo(tmp_path)
    missing = migrate.RepositoryPlan(
        repo, migrate.OUTCOME_MIGRATE, "", (migrate.Move(".borg/chains/ghost.json", ".stacks/ghost.json", False),)
    )
    assert migrate_shell.execute(missing).failure.startswith("could not move .borg/chains/ghost.json")

    _write(repo, ".borg/chains/a.json")
    _git_add_fails(monkeypatch)
    plan = migrate.RepositoryPlan(
        repo, migrate.OUTCOME_MIGRATE, "", (migrate.Move(".borg/chains/a.json", ".stacks/a.json", False),)
    )
    assert migrate_shell.execute(plan) == migrate.Execution(
        "git add .stacks/a.json failed and .borg/chains/a.json was put back; nothing was moved", 0
    )


def _git_add_fails(monkeypatch):
    real = proc.run_capture
    monkeypatch.setattr(proc, "run_capture", lambda argv, timeout=None: None if "add" in argv else real(argv, timeout))


def _rename_back_fails(monkeypatch):
    """`os.rename` works, except for the put-back of a file `git add` refused (destination -> source)."""
    real = os.rename

    def fake(source, dest, *args, **kwargs):
        if source.endswith(".stacks/0hidden.json") and dest.endswith(".borg/chains/0hidden.json"):
            raise PermissionError(13, "Permission denied")
        return real(source, dest, *args, **kwargs)

    monkeypatch.setattr(os, "rename", fake)


def test_a_failed_git_add_puts_the_one_ignored_manifest_back_and_reports_it_not_moved(tmp_path):
    """H5: the file used to stay untracked in `.stacks/`; the one rollback there is, is the rename back."""
    repo = _repo(tmp_path, gitignore=CARVED + ".borg/chains/0hidden.json\n")
    hidden = _write(repo, ".borg/chains/0hidden.json")
    _write(repo, ".borg/chains/a.json")
    _commit(repo)
    plan = migrate.plan_repository(migrate_shell.gather(repo))
    assert [m.source for m in plan.moves] == [".borg/chains/0hidden.json", ".borg/chains/a.json"]
    lock = os.path.join(repo, ".git", "index.lock")
    _write(repo, ".git/index.lock", "held\n")
    try:
        execution = migrate_shell.execute(plan)
    finally:
        os.remove(lock)

    assert os.path.exists(hidden)
    assert not os.path.exists(os.path.join(repo, ".stacks/0hidden.json"))
    assert execution == migrate.Execution(
        "git add .stacks/0hidden.json failed and .borg/chains/0hidden.json was put back; nothing was moved", 0
    )
    assert not os.path.exists(os.path.join(repo, ".stacks"))


def test_when_the_put_back_fails_too_the_report_stays_accurate_about_an_unstaged_file(tmp_path, monkeypatch):
    repo = _repo(tmp_path, gitignore=CARVED + ".borg/chains/0hidden.json\n")
    _write(repo, ".borg/chains/0hidden.json")
    _write(repo, ".borg/chains/a.json")
    _commit(repo)
    plan = migrate.plan_repository(migrate_shell.gather(repo))
    _git_add_fails(monkeypatch)
    _rename_back_fails(monkeypatch)

    execution = migrate_shell.execute(plan)

    assert os.path.exists(os.path.join(repo, ".stacks/0hidden.json"))
    assert execution == migrate.Execution(
        "git add .stacks/0hidden.json failed; moved but NOT staged, run git add .stacks/0hidden.json: "
        ".borg/chains/0hidden.json -> .stacks/0hidden.json",
        1,
    )


def test_a_failed_git_add_after_an_earlier_move_keeps_the_earlier_move_and_puts_back_only_the_failed_one(
    tmp_path, monkeypatch
):
    repo = _repo(tmp_path, gitignore=CARVED + ".borg/chains/z-hidden.json\n")
    _write(repo, ".borg/chains/a.json")
    _write(repo, ".borg/chains/z-hidden.json")
    _commit(repo)
    plan = migrate.plan_repository(migrate_shell.gather(repo))
    assert [m.source for m in plan.moves] == [".borg/chains/a.json", ".borg/chains/z-hidden.json"]
    _git_add_fails(monkeypatch)

    execution = migrate_shell.execute(plan)

    assert execution == migrate.Execution(
        "git add .stacks/z-hidden.json failed and .borg/chains/z-hidden.json was put back; "
        "already moved: .borg/chains/a.json",
        1,
    )
    assert os.path.exists(os.path.join(repo, ".stacks/a.json"))
    assert os.path.exists(os.path.join(repo, ".borg/chains/z-hidden.json"))
    assert not os.path.exists(os.path.join(repo, ".stacks/z-hidden.json"))


def test_a_stacks_directory_that_cannot_be_created_is_reported(tmp_path):
    repo = _repo(tmp_path)
    _write(repo, ".stacks", "a file\n")
    plan = migrate.RepositoryPlan(repo, migrate.OUTCOME_MIGRATE, "", ())
    assert migrate_shell.execute(plan).failure.startswith("could not create .stacks/")


def test_a_part_way_failure_is_printed_and_exits_non_zero(tmp_path, registry, capsys, monkeypatch):
    repo = _repo(tmp_path, gitignore=CARVED)
    _write(repo, ".borg/chains/a.json")
    _commit(repo)
    registry(repo=repo)
    monkeypatch.setattr(migrate_shell, "execute", lambda plan: migrate.Execution("boom; nothing was moved"))
    code, out, err = _run(capsys)
    assert code == 1
    assert f"failed: {repo}: boom; nothing was moved" in out
    assert "failed part-way" in err
    assert "migrated 0 manifest(s)" in out


def test_the_summary_after_a_part_way_failure_counts_the_moves_that_landed(tmp_path, registry, capsys, monkeypatch):
    """N1, end to end: a real failure after one move said `migrated 0 manifest(s)` although a.json had moved."""
    repo = _repo(tmp_path, gitignore=CARVED + ".borg/chains/z-hidden.json\n")
    _write(repo, ".borg/chains/a.json")
    _write(repo, ".borg/chains/z-hidden.json")
    _commit(repo)
    registry(repo=repo)
    real = migrate_shell._move_one  # pylint: disable=protected-access
    calls = []

    def second_move_fails(path, move):
        calls.append(move.source)
        return ("simulated failure", False) if len(calls) == 2 else real(path, move)

    monkeypatch.setattr(migrate_shell, "_move_one", second_move_fails)
    code, out, err = _run(capsys)

    assert code == 1
    assert os.path.exists(os.path.join(repo, ".stacks/a.json"))
    assert "migrated 1 manifest(s) in 1 repository(ies)" in out
    assert "migrated 0 manifest(s)" not in out
    assert "failed part-way" in err


def test_a_stacks_directory_this_run_created_is_removed_when_nothing_landed_in_it(tmp_path, monkeypatch):
    """N3: a failed first move must leave the tree as it was."""
    repo = _repo(tmp_path, gitignore=CARVED)
    _write(repo, ".borg/chains/a.json")
    _commit(repo)
    plan = migrate.plan_repository(migrate_shell.gather(repo))
    monkeypatch.setattr(migrate_shell, "_move_one", lambda path, move: ("simulated failure", False))
    before = _snapshot(repo)

    assert migrate_shell.execute(plan) == migrate.Execution("simulated failure; nothing was moved", 0)
    assert _snapshot(repo) == before
    assert not os.path.exists(os.path.join(repo, ".stacks"))


def test_a_stacks_directory_that_already_existed_is_never_removed(tmp_path, monkeypatch):
    repo = _repo(tmp_path, gitignore=CARVED)
    _write(repo, ".borg/chains/a.json")
    _commit(repo)
    os.makedirs(os.path.join(repo, ".stacks"))
    plan = migrate.plan_repository(migrate_shell.gather(repo))
    monkeypatch.setattr(migrate_shell, "_move_one", lambda path, move: ("simulated failure", False))
    migrate_shell.execute(plan)
    assert os.path.isdir(os.path.join(repo, ".stacks"))


def test_a_stacks_directory_holding_an_earlier_move_is_kept_after_a_later_failure(tmp_path, monkeypatch):
    repo = _repo(tmp_path, gitignore=CARVED)
    _write(repo, ".borg/chains/a.json")
    _write(repo, ".borg/chains/b.json")
    _commit(repo)
    plan = migrate.plan_repository(migrate_shell.gather(repo))
    real = migrate_shell._move_one  # pylint: disable=protected-access
    monkeypatch.setattr(
        migrate_shell,
        "_move_one",
        lambda path, move: ("simulated failure", False) if move.source.endswith("b.json") else real(path, move),
    )
    assert migrate_shell.execute(plan).moved == 1
    assert os.path.exists(os.path.join(repo, ".stacks/a.json"))


def test_an_emptied_source_directory_is_not_removed_after_a_successful_run(tmp_path, registry, capsys):
    """N3's other half: removing `.borg/chains/` is step (c)'s, not this command's."""
    repo = _repo(tmp_path, gitignore=CARVED)
    _write(repo, ".borg/chains/a.json")
    _commit(repo)
    registry(repo=repo)
    assert _run(capsys)[0] == 0
    assert os.path.isdir(os.path.join(repo, ".borg/chains"))
    assert os.listdir(os.path.join(repo, ".borg/chains")) == []


# ── H3: an atomic plain move, and a preflight that predicts a directory that is not writable ────

needs_non_root = pytest.mark.skipif(os.geteuid() == 0, reason="root ignores directory permissions")


@pytest.fixture(name="readonly")
def _readonly():
    """`lock(path)` makes a directory read-only; every mode is restored at teardown so pytest can clean up."""
    changed = []

    def lock(path):
        changed.append((path, stat.S_IMODE(os.stat(path).st_mode)))
        os.chmod(path, 0o555)

    yield lock
    for path, mode in reversed(changed):
        os.chmod(path, mode)


def _ignored_manifest_repo(tmp_path):
    repo = _repo(tmp_path, gitignore=CARVED + ".borg/chains/hidden.json\n")
    _write(repo, ".borg/chains/hidden.json")
    return repo


@needs_non_root
def test_a_plain_move_out_of_a_read_only_directory_fails_without_leaving_a_copy_behind(tmp_path, readonly):
    """H3: `shutil.move` copied, failed to unlink, and said `nothing was moved` with the file in both roots."""
    repo = _ignored_manifest_repo(tmp_path)
    plan = migrate.plan_repository(migrate_shell.gather(repo))
    assert [m.tracked for m in plan.moves] == [False]
    readonly(os.path.join(repo, ".borg/chains"))

    execution = migrate_shell.execute(plan)

    assert execution.moved == 0
    assert execution.failure.startswith("could not move .borg/chains/hidden.json: ")
    assert "nothing was moved" in execution.failure
    assert os.path.exists(os.path.join(repo, ".borg/chains/hidden.json"))
    assert not os.path.lexists(os.path.join(repo, ".stacks/hidden.json"))
    assert not os.path.exists(os.path.join(repo, ".stacks"))


def test_a_plain_move_across_filesystems_fails_without_copying(tmp_path, monkeypatch):
    repo = _ignored_manifest_repo(tmp_path)
    plan = migrate.plan_repository(migrate_shell.gather(repo))

    def exdev(source, dest, *args, **kwargs):
        raise OSError(errno.EXDEV, "Invalid cross-device link")

    monkeypatch.setattr(os, "rename", exdev)
    execution = migrate_shell.execute(plan)

    assert execution.failure.startswith("could not move .borg/chains/hidden.json: ")
    assert os.path.exists(os.path.join(repo, ".borg/chains/hidden.json"))
    assert not os.path.lexists(os.path.join(repo, ".stacks/hidden.json"))


def _lock_source(repo, readonly):
    readonly(os.path.join(repo, ".borg/chains"))


def _lock_stacks(repo, readonly):
    """An existing, empty `.stacks/` (git does not see an empty directory), read-only."""
    os.makedirs(os.path.join(repo, ".stacks"))
    readonly(os.path.join(repo, ".stacks"))


def _lock_repository(repo, readonly):
    readonly(repo)


@needs_non_root
@pytest.mark.parametrize(
    "lock,words",
    [
        (_lock_source, "not writable, so manifests cannot be moved: .borg/chains"),
        (_lock_stacks, "not writable, so manifests cannot be moved: .stacks"),
        (_lock_repository, "the repository directory (.stacks/ would be created there)"),
    ],
    ids=["source-directory", "stacks-directory", "parent-of-a-stacks-to-create"],
)
@pytest.mark.parametrize("dry_run", [True, False], ids=["dry-run", "real"])
def test_a_directory_that_is_not_writable_skips_the_repository_by_name_and_predicts_it_in_a_dry_run(
    tmp_path, registry, capsys, readonly, lock, words, dry_run
):
    repo = _repo(tmp_path, gitignore=CARVED)
    _write(repo, ".borg/chains/a.json")
    _commit(repo)
    registry(repo=repo)
    lock(repo, readonly)
    before = _snapshot(repo)

    code, out, _ = _run(capsys, *(["--dry-run"] if dry_run else []))

    assert code == 1
    assert f"skipped: {repo}: " in out
    assert words in out
    assert "would git mv" not in out
    assert _snapshot(repo) == before


@needs_non_root
def test_a_read_only_tree_with_nothing_to_move_still_says_nothing_to_migrate(tmp_path, registry, capsys, readonly):
    repo = _repo(tmp_path)
    readonly(repo)
    registry(repo=repo)
    code, out, _ = _run(capsys)
    assert code == 0
    assert f"nothing to migrate: {repo}" in out


# ── H4: an operation in progress, or a locked index ─────────────────────────────────────────────


def _git_try(repo, *args):
    """A git command that is EXPECTED to stop (a conflict): the exit status is not the point."""
    subprocess.run(["git", "-C", repo, *args], check=False, capture_output=True, text=True)


def _diverge(repo):
    """Two branches that rewrite `conflict.txt` from one base, so a merge of either way conflicts.

    The manifest is committed on its own first, so what `conflict.txt` does never touches `.borg/chains/`.
    Leaves `repo` on its original branch, with `other` beside it and `a.json` committed and clean.
    """
    _write(repo, ".borg/chains/a.json")
    _commit(repo, "manifest")
    _write(repo, "conflict.txt", "base\n")
    _commit(repo, "base")
    original = _git(repo, "rev-parse", "--abbrev-ref", "HEAD").strip()
    _git(repo, "checkout", "-q", "-b", "other")
    _write(repo, "conflict.txt", "other\n")
    _commit(repo, "other")
    _git(repo, "checkout", "-q", original)
    _write(repo, "conflict.txt", "main\n")
    _commit(repo, "main")
    return original


def _begin_merge(repo):
    _git_try(repo, "merge", "-q", "--no-edit", "other")


def _begin_cherry_pick(repo):
    _git_try(repo, "cherry-pick", "other")


def _begin_revert(repo):
    _git_try(repo, "revert", "--no-edit", "HEAD~1")


def _begin_rebase(repo):
    _git_try(repo, "rebase", "other")


def _begin_rebase_apply(repo):
    _git_try(repo, "rebase", "--apply", "other")


OPERATION_CASES = [
    (_begin_merge, "a merge is in progress (MERGE_HEAD exists)", "merge"),
    (_begin_cherry_pick, "a cherry-pick is in progress (CHERRY_PICK_HEAD exists)", "cherry-pick"),
    (_begin_revert, "a revert is in progress (REVERT_HEAD exists)", "revert"),
    (_begin_rebase, "a rebase is in progress (rebase-merge exists)", "rebase"),
    (_begin_rebase_apply, "a rebase is in progress (rebase-apply exists)", "rebase"),
]
OPERATION_IDS = ["merge", "cherry-pick", "revert", "rebase-merge", "rebase-apply"]


@pytest.mark.parametrize("begin,words,abort", OPERATION_CASES, ids=OPERATION_IDS)
@pytest.mark.parametrize("dry_run", [True, False], ids=["dry-run", "real"])
def test_a_repository_in_the_middle_of_an_operation_is_skipped_by_name_and_untouched(
    tmp_path, registry, capsys, begin, words, abort, dry_run
):
    """H4: the printed pathspec commit is refused by git mid-merge, so the move must wait for the operation."""
    repo = _repo(tmp_path, gitignore=CARVED)
    _diverge(repo)
    begin(repo)
    registry(repo=repo)
    before = _snapshot(repo)

    code, out, _ = _run(capsys, *(["--dry-run"] if dry_run else []))

    assert code == 1
    assert f"skipped: {repo}: {words}" in out
    assert "git mv" not in out
    assert _snapshot(repo) == before
    assert not os.path.exists(os.path.join(repo, ".stacks"))


@pytest.mark.parametrize("begin,words,abort", OPERATION_CASES, ids=OPERATION_IDS)
def test_once_the_operation_is_aborted_the_repository_migrates(tmp_path, registry, capsys, begin, words, abort):
    repo = _repo(tmp_path, gitignore=CARVED)
    _diverge(repo)
    begin(repo)
    registry(repo=repo)
    assert _run(capsys)[0] == 1
    _git(repo, abort, "--abort")

    code, out, _ = _run(capsys)

    assert code == 0
    assert "git mv: .borg/chains/a.json -> .stacks/a.json" in out


def test_a_linked_worktree_in_the_middle_of_a_merge_is_skipped_through_its_own_git_dir(tmp_path, registry, capsys):
    """In a linked worktree `.git` is a FILE, so MERGE_HEAD only resolves through `git rev-parse --git-path`."""
    repo = _repo(tmp_path, gitignore=CARVED)
    original = _diverge(repo)
    worktree = str(tmp_path / "wt")
    _git(repo, "worktree", "add", "-q", "-b", "feature", worktree, original)
    _begin_merge(worktree)
    assert os.path.isfile(os.path.join(worktree, ".git"))
    registry(repo=repo, wt=worktree)
    before = _snapshot(worktree)

    code, out, _ = _run(capsys, "--dry-run")

    assert code == 1
    assert f"skipped: {worktree}: a merge is in progress (MERGE_HEAD exists)" in out
    assert "would git mv: .borg/chains/a.json -> .stacks/a.json" in out
    assert _snapshot(worktree) == before


def _hold_the_index(repo):
    return _write(repo, ".git/index.lock", "held by another git process\n")


@pytest.mark.parametrize("dry_run", [True, False], ids=["dry-run", "real"])
def test_a_locked_index_skips_the_repository_by_name_and_a_dry_run_predicts_it(tmp_path, registry, capsys, dry_run):
    """H4: the real run used to fail part-way on `git mv`/`git add`; the dry run said it would migrate."""
    repo = _ignored_manifest_repo(tmp_path)
    _write(repo, ".borg/chains/tracked.json")
    _commit(repo)
    registry(repo=repo)
    lock = _hold_the_index(repo)
    before = _snapshot(repo)
    try:
        code, out, _ = _run(capsys, *(["--dry-run"] if dry_run else []))
        assert code == 1
        assert f"skipped: {repo}: the git index is locked (index.lock exists)" in out
        assert "git mv" not in out
        assert _snapshot(repo) == before
    finally:
        os.remove(lock)
    assert _run(capsys)[0] == 0


def test_a_locked_index_in_a_linked_worktree_is_found_through_git_path(tmp_path, registry, capsys):
    repo = _repo(tmp_path, gitignore=CARVED)
    _write(repo, ".borg/chains/a.json")
    _commit(repo)
    worktree = str(tmp_path / "wt")
    _git(repo, "worktree", "add", "-q", "-b", "feature", worktree)
    lock = os.path.join(worktree, _git(worktree, "rev-parse", "--git-path", "index.lock").strip())
    with open(lock, "w", encoding="utf-8") as handle:
        handle.write("held\n")
    try:
        registry(wt=worktree)
        code, out, _ = _run(capsys, "--dry-run")
    finally:
        os.remove(lock)
    assert code == 1
    assert f"skipped: {worktree}: the git index is locked" in out


def test_an_unreadable_git_state_skips_the_repository_instead_of_reading_it_as_idle(tmp_path, monkeypatch):
    repo = _repo(tmp_path, gitignore=CARVED)
    _write(repo, ".borg/chains/a.json")
    _commit(repo)
    real = proc.run_capture
    monkeypatch.setattr(
        proc, "run_capture", lambda argv, timeout=None: None if "--git-path" in argv else real(argv, timeout)
    )
    plan = migrate.plan_repository(migrate_shell.gather(repo))
    assert plan.outcome == migrate.OUTCOME_SKIP
    assert "could not read git state" in plan.reason


def test_a_git_state_answer_of_the_wrong_length_is_not_trusted(tmp_path, monkeypatch):
    repo = _repo(tmp_path, gitignore=CARVED)
    _write(repo, ".borg/chains/a.json")
    _commit(repo)
    real = proc.run_capture
    monkeypatch.setattr(
        proc,
        "run_capture",
        lambda argv, timeout=None: (0, ".git/MERGE_HEAD\n") if "--git-path" in argv else real(argv, timeout),
    )
    assert migrate.plan_repository(migrate_shell.gather(repo)).outcome == migrate.OUTCOME_SKIP


# ── H6: the ignore refusal names the destinations and the rules, not a whole directory ──────────


def _force_track(repo, *names):
    for name in names:
        _write(repo, f".borg/chains/{name}")
        _git(repo, "add", "-f", f".borg/chains/{name}")
    _git(repo, "commit", "-q", "-m", "manifests")


@pytest.mark.parametrize("dry_run", [True, False], ids=["dry-run", "real"])
def test_a_narrow_ignore_rule_refuses_naming_only_the_ignored_destination_and_its_rule(
    tmp_path, registry, capsys, dry_run
):
    repo = _repo(tmp_path, gitignore=CARVED + "*.local.json\n")
    _force_track(repo, "a.json", "b.local.json")
    registry(repo=repo)
    before = _snapshot(repo)

    code, out, _ = _run(capsys, *(["--dry-run"] if dry_run else []))

    assert code == 1
    assert f"refused: {repo}: git ignores .stacks/b.local.json (.gitignore:4:*.local.json); " in out
    assert ".stacks/a.json" not in out
    assert "git ignores .stacks/," not in out
    assert "always version-controlled" in out
    assert _snapshot(repo) == before
    assert not os.path.exists(os.path.join(repo, ".stacks"))


def test_each_ignored_destination_is_named_with_the_rule_that_ignores_it(tmp_path, registry, capsys):
    repo = _repo(tmp_path, gitignore=CARVED + "a.json\n")
    with open(os.path.join(repo, ".git/info/exclude"), "a", encoding="utf-8") as handle:
        handle.write("b.json\n")
    _force_track(repo, "a.json", "b.json", "c.json")
    registry(repo=repo)

    code, out, _ = _run(capsys, "--dry-run")

    assert code == 1
    assert ".stacks/a.json (.gitignore:4:a.json)" in out
    assert ".stacks/b.json (.git/info/exclude:" in out
    assert ".stacks/c.json" not in out


def test_a_destination_a_later_rule_un_ignores_is_not_named_and_does_not_refuse(tmp_path, registry, capsys):
    """`check-ignore -v` also prints a path that matched `!rule`; that path is NOT ignored."""
    repo = _repo(tmp_path, gitignore=CARVED + ".stacks/*.json\n!.stacks/a.json\n")
    _force_track(repo, "a.json")
    registry(repo=repo)
    code, out, _ = _run(capsys)
    assert code == 0
    assert "git mv: .borg/chains/a.json -> .stacks/a.json" in out
    assert _git(repo, "diff", "--cached", "--name-status", "-M").splitlines() == [
        "R100\t.borg/chains/a.json\t.stacks/a.json"
    ]


def test_a_negated_rule_beside_an_ignored_destination_names_only_the_ignored_one(tmp_path, registry, capsys):
    repo = _repo(tmp_path, gitignore=CARVED + ".stacks/*.json\n!.stacks/a.json\n")
    _force_track(repo, "a.json", "b.json")
    registry(repo=repo)
    code, out, _ = _run(capsys, "--dry-run")
    assert code == 1
    assert ".stacks/b.json (.gitignore:4:.stacks/*.json)" in out
    assert "git ignores .stacks/a.json" not in out


def test_remove_if_empty_leaves_a_directory_that_has_something_in_it(tmp_path):
    """`os.rmdir` refuses a non-empty directory, and the helper must swallow that, never escalate to a recursive delete."""
    folder = tmp_path / "held"
    folder.mkdir()
    (folder / "keep.txt").write_text("x\n", encoding="utf-8")
    migrate_shell._remove_if_empty(str(folder))  # pylint: disable=protected-access
    assert (folder / "keep.txt").exists()
