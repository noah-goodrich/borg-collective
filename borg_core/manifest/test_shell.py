"""Unit tests for borg_core.manifest.shell (the I/O layer).

Calling convention: in-process only, against real directories under `tmp_path`, real `git`
repositories built by `_git_repository` and real linked worktrees built by `_git_worktree`. Two
things a real `git` cannot be persuaded to produce are driven by a stub `git` on PATH (`_stub_git`):
a URL with trailing whitespace, which git config trims on read, and one that is not valid UTF-8.
Only the timeout case monkeypatches subprocess, because it is the one failure a real `git` cannot be
persuaded to produce quickly.

THE ONE RULE THIS FILE EXISTS TO OBEY: a test that supplies the value production is supposed to
DERIVE proves nothing. `borg recon` shipped completely non-functional because every one of its tests
put BORG_REGISTRY in the environment itself, so the inheritance line production actually ran was the
one line no test ever executed. So `discover_registered` is ALWAYS exercised by building a registry
dict and letting it derive the paths -- never by handing it a path list -- and `repository_slug` is
exercised against a real `git remote`, never against a canned URL string.

WHERE THE SLUG RULE TABLE WENT: the ~20-case URL->slug mapping is PURE and now lives in
core.slug_from_remote, asserted as a parametrize list in test_core.py. What stays here is the wire --
a real `git init` + `git remote add` + `git remote get-url` for the shapes that have to survive the
actual read (including the credentialed URL that leaked a live token in 2026-08) plus every way the
read itself can fail. A rule added to the table is a parametrize row over there; a rule added to the
I/O is a real repository over here.

Every positive case is paired with a negative case proving the condition discriminates.
"""

from __future__ import annotations

import ast
import json
import os
import re
import subprocess
import types

import pytest

from borg_core import proc
from borg_core.manifest import core, shell


def _manifest(rows, apex=None):
    m = {"rows": rows}
    if apex is not None:
        m["apex"] = apex
    return m


def _row(order, ref, lane=None, **extra):
    r = {"order": order, "ref": ref, **extra}
    if lane is not None:
        r["lane"] = lane
    return r


def _write_manifest(root, repository, name, doc):
    """Put one manifest under `<root>/<repository>/.borg/programs/<name>` and return the repo path."""
    directory = root / repository / ".borg" / "programs"
    directory.mkdir(parents=True, exist_ok=True)
    body = doc if isinstance(doc, str) else json.dumps(doc)
    (directory / name).write_text(body, encoding="utf-8")
    return str(root / repository)


def _registry(*paths):
    """A registry dict shaped like ~/.config/borg/registry.json, keyed by project name."""
    return {"projects": {os.path.basename(p) or f"p{i}": {"path": p} for i, p in enumerate(paths)}}


def _git_repository(root, name, remote=None):
    """A real git repository under tmp_path, optionally with an `origin` remote."""
    directory = root / name
    directory.mkdir(parents=True, exist_ok=True)
    subprocess.run(["git", "init", "-q"], cwd=str(directory), check=True, capture_output=True)
    if remote is not None:
        subprocess.run(
            ["git", "remote", "add", "origin", remote],
            cwd=str(directory),
            check=True,
            capture_output=True,
        )
    return str(directory)


def _git_worktree(repository, path, branch):
    """A REAL linked worktree, whose `.git` is a file containing `gitdir: ...`.

    Fabricating that file by hand instead is what made the old worktree test pass for the wrong
    reason: a hand-written `gitdir:` line points at nothing, so `git remote get-url` FAILS and the
    "" came from the subprocess rather than from the guard the test claimed to pin.
    """
    subprocess.run(
        ["git", "commit", "-q", "--allow-empty", "-m", "root"], cwd=repository, check=True, capture_output=True
    )
    subprocess.run(
        ["git", "worktree", "add", "-q", "-b", branch, path], cwd=repository, check=True, capture_output=True
    )
    return path


def _stub_git(bin_dir, body):
    """A fake `git` on PATH whose stdout is exactly `body`. Returns the directory to prepend to PATH.

    The only way to drive _git_origin_url's trimming and decoding from a real subprocess: `git remote
    add` will not store a URL with trailing whitespace (git config trims it on read), and no real
    remote produces invalid UTF-8 on demand.
    """
    bin_dir.mkdir(parents=True, exist_ok=True)
    script = bin_dir / "git"
    script.write_bytes(b"#!/bin/sh\nprintf '%s' " + body + b"\n")
    script.chmod(0o755)
    return str(bin_dir)


# ── manifest_dir ─────────────────────────────────────────────────────────────


def test_manifest_dir_is_the_one_location():
    # The `programs` literal is what is on disk and stays; the FUNCTION is not named after it.
    # "Program" is retired, and a new public symbol in a new package is exactly where the retired
    # word must not reappear (PROJECT_PLAN.md Vocabulary; AC7 greps for it).
    assert shell.manifest_dir("/repos/ingle") == "/repos/ingle/.borg/programs"


def test_no_public_name_in_the_package_carries_the_retired_word():
    for module in (core, shell):
        offenders = [name for name in vars(module) if not name.startswith("_") and "program" in name.lower()]
        assert offenders == [], f"{module.__name__}: {offenders}"


# ── discover ─────────────────────────────────────────────────────────────────


def test_discover_loads_a_valid_manifest(tmp_path):
    p = _write_manifest(tmp_path, "repo", "a.json", _manifest([_row("1", "o/r#1")]))
    manifests, warnings = shell.discover([p])
    assert len(manifests) == 1 and warnings == []
    assert manifests[0]["_id"] == "a"


def test_discover_reads_a_declared_id_but_synthesizes_no_program_key(tmp_path):
    # A declared top-level `program` key is read VERBATIM -- that is what is on disk. What discovery
    # must not do is WRITE one: a manifest without the key used to have a `program` key synthesized
    # into it, which puts the retired word into newly-created output rather than merely reading it.
    declared = _write_manifest(
        tmp_path, "a", "filename.json", {**_manifest([_row("1", "o/r#1")]), "program": "declared-id"}
    )
    undeclared = _write_manifest(tmp_path, "b", "from-filename.json", _manifest([_row("1", "o/r#2")]))
    by_path = {m["_path"]: m for m in shell.discover([declared, undeclared])[0]}
    with_key = [m for m in by_path.values() if m["_id"] == "declared-id"][0]
    without_key = [m for m in by_path.values() if m["_id"] == "from-filename"][0]
    assert with_key["program"] == "declared-id", "a declared key is read, never rewritten"
    assert "program" not in without_key, "and never invented"


def test_a_repository_with_no_programs_dir_is_silent(tmp_path):
    # The common case on every repository that has never authored a manifest. Warning here would put
    # noise on every invocation.
    (tmp_path / "empty").mkdir()
    assert shell.discover([str(tmp_path / "empty")]) == ([], [])


def test_a_nonexistent_repository_dir_warns_by_name(tmp_path):
    # The negative pair for the test above: a stale or typo'd registry path must be distinguishable
    # from "this repository has no manifests".
    manifests, warnings = shell.discover([str(tmp_path / "gone")])
    assert manifests == []
    assert len(warnings) == 1 and "does not exist" in warnings[0] and "gone" in warnings[0]


def test_an_unreadable_programs_dir_warns_by_name(tmp_path):
    if os.geteuid() == 0:
        pytest.skip("root ignores mode bits -- chmod 000 cannot deny listdir (devcontainer case)")

    directory = tmp_path / "repo" / ".borg" / "programs"
    directory.mkdir(parents=True)
    os.chmod(directory, 0o000)
    try:
        manifests, warnings = shell.discover([str(tmp_path / "repo")])
    finally:
        os.chmod(directory, 0o755)
    # Zero manifests from a real directory would otherwise look exactly like a correct empty sweep.
    assert manifests == []
    assert len(warnings) == 1 and "unreadable" in warnings[0]


def test_malformed_json_is_skipped_with_a_named_warning(tmp_path):
    # An unnamed skip is indistinguishable from a file that was never there.
    p = _write_manifest(tmp_path, "repo", "bad.json", "{not json")
    manifests, warnings = shell.discover([p])
    assert manifests == []
    assert len(warnings) == 1 and "bad.json" in warnings[0]


def test_unrelated_json_is_skipped_as_not_a_manifest(tmp_path):
    # A stray settings.json living in the directory must not half-parse into edges.
    p = _write_manifest(tmp_path, "repo", "settings.json", {"theme": "dark"})
    manifests, warnings = shell.discover([p])
    assert manifests == []
    assert len(warnings) == 1 and "not a manifest" in warnings[0] and "settings.json" in warnings[0]


def test_an_invalid_manifest_is_skipped_with_its_errors_named(tmp_path):
    p = _write_manifest(tmp_path, "repo", "bad.json", _manifest([_row("1", "")]))
    manifests, warnings = shell.discover([p])
    assert manifests == []
    assert "invalid manifest" in warnings[0] and "missing ref" in warnings[0]


def test_one_bad_manifest_does_not_suppress_a_good_one(tmp_path):
    # THE failure this guards: a single malformed file blanking the whole grid.
    p = _write_manifest(tmp_path, "repo", "good.json", _manifest([_row("1", "o/r#1")]))
    _write_manifest(tmp_path, "repo", "bad.json", "{nope")
    manifests, warnings = shell.discover([p])
    assert len(manifests) == 1 and len(warnings) == 1


def test_non_json_files_are_ignored_with_no_warning(tmp_path):
    p = _write_manifest(tmp_path, "repo", "a.json", _manifest([_row("1", "o/r#1")]))
    (tmp_path / "repo" / ".borg" / "programs" / "README.md").write_text("notes", encoding="utf-8")
    manifests, warnings = shell.discover([p])
    assert len(manifests) == 1 and warnings == []


def test_manifests_carry_their_source_path(tmp_path):
    # The literal `_path` key name is a cross-module contract.
    p = _write_manifest(tmp_path, "repo", "a.json", _manifest([_row("1", "o/r#1")]))
    assert shell.discover([p])[0][0]["_path"].endswith("a.json")


def test_discovery_reads_only_from_borg_programs(tmp_path):
    # Nothing outside a repository's own .borg/programs is ever opened.
    p = tmp_path / "repo"
    (p / ".borg").mkdir(parents=True)
    (p / ".borg" / "elsewhere.json").write_text(json.dumps(_manifest([_row("1", "o/r#1")])), encoding="utf-8")
    (p / "stack.json").write_text(json.dumps(_manifest([_row("1", "o/r#2")])), encoding="utf-8")
    assert shell.discover([str(p)]) == ([], [])


def test_manifest_load_order_within_a_repository_is_sorted_by_filename(tmp_path):
    p = _write_manifest(tmp_path, "repo", "b.json", _manifest([_row("1", "o/r#2")]))
    _write_manifest(tmp_path, "repo", "a.json", _manifest([_row("1", "o/r#1")]))
    manifests, _ = shell.discover([p])
    assert [m["_id"] for m in manifests] == ["a", "b"]


def test_multiple_repositories_are_all_swept(tmp_path):
    a = _write_manifest(tmp_path, "a", "x.json", _manifest([_row("1", "o/a#1")]))
    b = _write_manifest(tmp_path, "b", "y.json", _manifest([_row("1", "o/b#1")]))
    manifests, _ = shell.discover([a, b])
    assert len(manifests) == 2


def test_discovering_nothing_is_not_an_error(tmp_path):
    # The personal-machine case: nothing configured, nothing present, still succeeds.
    assert shell.discover([]) == ([], [])
    manifests, warnings = shell.discover([str(tmp_path / "never-existed")])
    assert manifests == [] and len(warnings) == 1


# ── discover_registered (B6) ─────────────────────────────────────────────────


def test_a_manifest_declaring_four_repositories_is_found_and_selected_from_every_member(tmp_path):
    """THE B6 regression test, end to end over the real shape.

    `ingle-t1-cutover.json` declares refs across four repositories but lives only under
    `stillpoint`. Repository-scoped discovery run from `ingle` globs `ingle/.borg/programs/`, finds
    nothing, and renders an empty grid -- for three of the four member repositories, which is the
    modal case. This failing is the difference between a working front door and an empty grid.

    Note what is NOT handed in: no path list. The registry is built and `discover_registered` derives
    the paths, because the derivation is the line production actually runs. The host repository sits
    SECOND in registry order on purpose, so that no single-repository scoping -- first, last, or
    in-scope -- can pass this by coincidence.
    """
    rows = [
        _row("–", "stillpoint-labs/stillpoint#37", "cutover"),
        _row("1", "stillpoint-labs/ingle#12", "cutover"),
        _row("2", "stillpoint-labs/reveal#5", "cutover"),
        _row("3", "stillpoint-labs/troth#9", "cutover"),
    ]
    host = _write_manifest(tmp_path, "stillpoint", "ingle-t1-cutover.json", _manifest(rows))
    for member in ("ingle", "reveal", "troth"):
        (tmp_path / member).mkdir(parents=True, exist_ok=True)

    registry = _registry(str(tmp_path / "ingle"), host, str(tmp_path / "reveal"), str(tmp_path / "troth"))
    manifests, warnings = shell.discover_registered(registry)

    assert warnings == []
    assert len(manifests) == 1, "global discovery must find the manifest wherever it lives"
    assert manifests[0]["_path"].startswith(host), "it lives under the host repository, not a member"
    for slug in (
        "stillpoint-labs/stillpoint",
        "stillpoint-labs/ingle",
        "stillpoint-labs/reveal",
        "stillpoint-labs/troth",
    ):
        assert core.select_for_repository(manifests, slug) == manifests, f"{slug} must select it"


def test_repository_scoped_discovery_is_the_failure_this_guards(tmp_path):
    # The negative pair: discovering from the MEMBER repository alone finds nothing, which is exactly
    # the empty grid B6 describes. If this ever starts passing, the test above has stopped meaning
    # anything.
    rows = [_row("1", "o/host#1", "l"), _row("2", "o/member#2", "l")]
    _write_manifest(tmp_path, "host", "m.json", _manifest(rows))
    (tmp_path / "member").mkdir()
    assert shell.discover([str(tmp_path / "member")]) == ([], [])


def test_discover_registered_derives_the_paths_from_the_registry(tmp_path):
    a = _write_manifest(tmp_path, "a", "x.json", _manifest([_row("1", "o/a#1")]))
    b = _write_manifest(tmp_path, "b", "y.json", _manifest([_row("1", "o/b#1")]))
    manifests, warnings = shell.discover_registered(_registry(a, b))
    assert sorted(m["_id"] for m in manifests) == ["x", "y"]
    assert warnings == []


def test_discover_registered_on_an_empty_registry_finds_nothing_and_warns_nothing():
    assert shell.discover_registered({}) == ([], [])
    assert shell.discover_registered({"projects": {}}) == ([], [])
    assert shell.discover_registered({"projects": None}) == ([], [])
    assert shell.discover_registered({"projects": []}) == ([], [])


@pytest.mark.parametrize(
    "registry",
    [{"projects": ["/a", "/b"]}, {"projects": "nope"}, {"projects": 3}, None, "nope", []],
    ids=["list", "string", "number", "none", "bare-string", "bare-list"],
)
def test_a_registry_of_the_wrong_shape_warns_instead_of_raising(registry):
    # `registry.get("projects") or {}` guarded missing/null/empty but not a wrong TYPE: a non-empty
    # list reached `.values()` and raised AttributeError straight out of discover_registered, taking
    # down the whole invocation from inside the module whose header says nothing here is ever fatal.
    # registry.shell.read_registry validates JSON syntax and nothing else, so a hand-edited registry
    # arrives here intact.
    manifests, warnings = shell.discover_registered(registry)
    assert manifests == []
    assert len(warnings) == 1 and "registry" in warnings[0]


def test_a_registry_entry_with_no_path_is_skipped_and_never_reads_the_cwd(tmp_path, monkeypatch):
    # Passing "" to manifest_dir would yield the RELATIVE path `.borg/programs`, making discovery
    # read whatever directory the process happens to be sitting in.
    _write_manifest(tmp_path, "here", "leak.json", _manifest([_row("1", "o/leak#1")]))
    monkeypatch.chdir(tmp_path / "here")
    registry = {"projects": {"a": {"path": ""}, "b": {"path": None}, "c": {"path": "null"}, "d": {}, "e": None}}
    manifests, warnings = shell.discover_registered(registry)
    assert manifests == [], "and above all not the manifest sitting in the cwd"
    # ZERO MANIFESTS AND ZERO WARNINGS is the silent-blindness shape this repository has been burned
    # by twice (usage-watch, `borg recon`). If the registry schema ever moves under this extractor,
    # the sweep goes quiet and link renders a confidently empty grid; one warning is the tripwire.
    assert len(warnings) == 1 and "none carry a usable path" in warnings[0]


def test_one_pathless_entry_among_good_ones_stays_silent(tmp_path):
    # The negative pair: the tripwire is per-REGISTRY, not per-entry, so a single pathless project
    # cannot make it noisy.
    good = _write_manifest(tmp_path, "good", "a.json", _manifest([_row("1", "o/a#1")]))
    manifests, warnings = shell.discover_registered({"projects": {"good": {"path": good}, "bad": {}}})
    assert len(manifests) == 1 and warnings == []


def test_two_registry_entries_pointing_at_one_directory_load_the_manifest_once(tmp_path):
    p = _write_manifest(tmp_path, "repo", "a.json", _manifest([_row("1", "o/r#1")]))
    registry = {"projects": {"repo": {"path": p}, "repo-feature": {"path": p}}}
    manifests, _ = shell.discover_registered(registry)
    assert len(manifests) == 1


def test_two_registry_paths_differing_only_by_a_trailing_slash_load_the_manifest_once(tmp_path):
    # The literal-string dedup this used to do could not see these: `/x/repo` and `/x/repo/` are two
    # different strings, but `os.path.join` normalizes the trailing slash away, so both produced a
    # manifest with a BYTE-IDENTICAL `_path` -- two indistinguishable copies of one file in the grid.
    p = _write_manifest(tmp_path, "repo", "a.json", _manifest([_row("1", "o/r#1")]))
    registry = {"projects": {"a": {"path": p}, "b": {"path": p + "/"}}}
    manifests, _ = shell.discover_registered(registry)
    assert len(manifests) == 1


def test_a_symlinked_registry_path_loads_the_manifest_once(tmp_path):
    p = _write_manifest(tmp_path, "repo", "a.json", _manifest([_row("1", "o/r#1")]))
    link = tmp_path / "linked"
    link.symlink_to(p)
    manifests, _ = shell.discover_registered({"projects": {"a": {"path": p}, "b": {"path": str(link)}}})
    assert len(manifests) == 1


@pytest.mark.parametrize("second", ["same", "trailing-slash", "symlink"], ids=["same", "trailing-slash", "symlink"])
def test_one_directory_reached_twice_warns_once(tmp_path, second):
    """What the DIRECTORY dedup uniquely controls, and the only thing that discriminates it.

    A duplicate that LOADS is caught downstream by the content dedup, so the two rules overlap on
    every happy path. A duplicate that WARNS is not: sweeping one directory twice reports the same
    malformed file twice, and a warning list is user-visible output. Without the realpath collapse
    the trailing-slash and symlink pairs each produce two identical warnings naming one file.
    """
    p = _write_manifest(tmp_path, "repo", "bad.json", "{nope")
    alias = {"same": p, "trailing-slash": p + "/", "symlink": str(tmp_path / "linked")}[second]
    if second == "symlink":
        (tmp_path / "linked").symlink_to(p)

    manifests, warnings = shell.discover_registered({"projects": {"a": {"path": p}, "b": {"path": alias}}})
    assert manifests == []
    assert len(warnings) == 1, warnings


def test_a_worktree_registered_beside_its_parent_loads_each_manifest_once(tmp_path):
    """THE duplicate no path-level rule can catch, and the one the live registry actually produces.

    `.borg/programs/` is git-tracked, so `drone feature` creates a worktree containing a real second
    copy of every manifest at a real second path, and `borg add` registers it alongside its parent.
    Both copies load, both declare the same rows, and the grid renders every node, every gate and
    every declared ref twice under one header.
    """
    repository = _git_repository(tmp_path, "repo", "git@github.com:owner/repo.git")
    _write_manifest(tmp_path, "repo", "a.json", _manifest([_row("1", "owner/repo#1"), _row("2", "owner/repo#2")]))
    subprocess.run(["git", "add", "-A"], cwd=repository, check=True, capture_output=True)
    subprocess.run(["git", "commit", "-q", "-m", "manifest"], cwd=repository, check=True, capture_output=True)
    worktree = _git_worktree(repository, str(tmp_path / "repo-pm6"), "pm6")

    registry = {"projects": {"repo": {"path": repository}, "repo-pm6": {"path": worktree}}}
    manifests, warnings = shell.discover_registered(registry)
    assert warnings == []
    assert os.path.exists(os.path.join(worktree, ".borg", "programs", "a.json")), "the copy is really there"
    assert len(manifests) == 1
    selected = core.select_for_repository(manifests, shell.repository_slug(worktree))
    assert len(selected) == 1
    assert core.declared_refs(selected[0]) == ["owner/repo#1", "owner/repo#2"], "each ref exactly once"


def test_two_genuinely_different_manifests_are_both_kept(tmp_path):
    # The negative pair for every dedup above: collapsing on content identity must not collapse
    # manifests that merely live in different repositories.
    a = _write_manifest(tmp_path, "a", "x.json", _manifest([_row("1", "o/a#1")]))
    b = _write_manifest(tmp_path, "b", "y.json", _manifest([_row("1", "o/b#1")]))
    manifests, _ = shell.discover_registered(_registry(a, b))
    assert len(manifests) == 2


def test_discover_registered_propagates_warnings_by_name(tmp_path):
    good = _write_manifest(tmp_path, "good", "a.json", _manifest([_row("1", "o/a#1")]))
    bad = _write_manifest(tmp_path, "bad", "b.json", "{nope")
    manifests, warnings = shell.discover_registered(_registry(good, bad))
    assert len(manifests) == 1
    assert len(warnings) == 1 and "b.json" in warnings[0]


def test_discover_registered_sweeps_in_registry_order(tmp_path):
    a = _write_manifest(tmp_path, "a", "one.json", _manifest([_row("1", "o/a#1")]))
    b = _write_manifest(tmp_path, "b", "two.json", _manifest([_row("1", "o/b#1")]))
    registry = {"projects": {"b": {"path": b}, "a": {"path": a}}}
    manifests, _ = shell.discover_registered(registry)
    assert [m["_id"] for m in manifests] == ["two", "one"]


# ── repository_slug ──────────────────────────────────────────────────────────


@pytest.mark.parametrize(
    "remote,expected",
    [
        ("git@github.com:owner/repo.git", "owner/repo"),
        ("https://github.com/owner/repo", "owner/repo"),
        ("https://x-access-token:gho_LIVE_TOKEN@github.com/owner/repo.git", "owner/repo"),
        ("git@github.com:Owner/Repo.git", "Owner/Repo"),
        ("git@gitlab.com:owner/repo.git", ""),
        ("https://github.com/owner/re po.git", ""),
    ],
    ids=["ssh-scp", "https-plain", "credentialed", "case-preserved", "non-github", "space-in-name"],
)
def test_repository_slug_survives_a_real_git_remote(tmp_path, remote, expected):
    """The WIRE, not the rule table. Real `git remote add` + `git remote get-url`.

    core.slug_from_remote holds the ~20-case mapping and test_core.py asserts it purely; these six
    are the shapes that have to survive the actual read -- most of all the credentialed URL, which
    is what leaked a live `gho_` token out of the adapter in 2026-08 and must never come back
    through a different path than the one the pure table sees.
    """
    repository = _git_repository(tmp_path, "r", remote)
    assert shell.repository_slug(repository) == expected


def test_repository_slug_is_empty_when_there_is_no_origin(tmp_path):
    assert shell.repository_slug(_git_repository(tmp_path, "no-remote")) == ""


def test_repository_slug_is_empty_for_a_directory_that_is_not_a_repository(tmp_path):
    plain = tmp_path / "plain"
    plain.mkdir()
    assert shell.repository_slug(str(plain)) == ""
    assert shell.repository_slug(str(tmp_path / "does-not-exist")) == ""


def test_repository_slug_resolves_a_real_linked_worktree(tmp_path):
    """A linked worktree's `.git` is a FILE, and `git remote get-url origin` answers inside it.

    The old `isdir` guard made every worktree yield "" and therefore select NO manifests -- the empty
    grid B6 exists to remove -- and `/Users/noah/dev/reveal-data-consistency` is one in the live
    registry today (`drone feature` creates them, `borg add` registers them).

    The worktree is REAL, built by `git worktree add`. The previous version of this test fabricated
    a `.git` file pointing at a nonexistent gitdir, so `git remote get-url` failed and the "" came
    from the subprocess rather than from the guard the test claimed to pin -- deleting the guard left
    it green.
    """
    repository = _git_repository(tmp_path, "main", "git@github.com:owner/repo.git")
    worktree = _git_worktree(repository, str(tmp_path / "wt"), "feat")
    assert os.path.isfile(os.path.join(worktree, ".git")), "a worktree's .git is a file, not a directory"
    assert shell.repository_slug(worktree) == "owner/repo"


def test_repository_slug_is_empty_for_a_plain_subdirectory_of_a_repository(tmp_path):
    """The negative pair, and why the check is `exists` rather than nothing at all.

    `git remote get-url origin` run in a plain SUBDIRECTORY succeeds and returns the PARENT's remote,
    so with no `.git` test at all a subdirectory registered by `borg add` would inherit its parent's
    slug and select the parent's manifests under a header naming the subdirectory.
    """
    repository = _git_repository(tmp_path, "main", "git@github.com:owner/repo.git")
    nested = os.path.join(repository, "packages", "web")
    os.makedirs(nested)
    # pylint: disable=protected-access
    assert shell._git_origin_url(nested) == "git@github.com:owner/repo.git", "git answers here"
    assert shell.repository_slug(nested) == "", "but the directory is not the repository"


def test_repository_slug_is_empty_when_git_is_missing(tmp_path, monkeypatch):
    # A missing binary raises FileNotFoundError out of subprocess; it must degrade, not explode.
    repository = _git_repository(tmp_path, "r", "git@github.com:owner/repo.git")
    monkeypatch.setenv("PATH", str(tmp_path / "nonexistent-bin-dir"))
    assert shell.repository_slug(repository) == ""


def test_repository_slug_is_empty_when_git_times_out(tmp_path, monkeypatch):
    repository = _git_repository(tmp_path, "r", "git@github.com:owner/repo.git")

    def _timeout(*_args, **_kwargs):
        raise subprocess.TimeoutExpired(cmd="git", timeout=shell.GIT_TIMEOUT_SECONDS)

    monkeypatch.setattr(proc.subprocess, "run", _timeout)
    assert shell.repository_slug(repository) == ""


def test_repository_slug_is_empty_when_git_exits_non_zero(tmp_path, monkeypatch):
    repository = _git_repository(tmp_path, "r", "git@github.com:owner/repo.git")
    monkeypatch.setenv("PATH", _stub_git(tmp_path / "bin", b"'nope'") + os.pathsep + os.environ["PATH"])
    # The stub prints a perfectly good-looking URL; only the exit status makes this "".
    assert shell.repository_slug(repository) == ""


def test_git_origin_url_strips_only_trailing_newlines(tmp_path, monkeypatch):
    """`rstrip("\n")`, NOT `.strip()`, and the difference is observable.

    `$(...)` strips trailing newlines and nothing else, so a remote carrying trailing whitespace
    reaches the adapter's `case` glob with that whitespace attached and is REJECTED there. Under
    `.strip()` this side would accept it and report a slug for a repository recon emits no items for
    -- a one-sided divergence. Driven through a stub `git` because `git remote add` will not store a
    URL with trailing whitespace: git config trims it on read.
    """
    monkeypatch.setenv("PATH", _stub_git(tmp_path / "bin", b"'https://github.com/owner/repo  \n'"))
    # pylint: disable=protected-access
    assert shell._git_origin_url(str(tmp_path)) == "https://github.com/owner/repo  "
    assert core.slug_from_remote(shell._git_origin_url(str(tmp_path))) == ""


def test_a_remote_that_is_not_valid_utf8_degrades_instead_of_raising(tmp_path, monkeypatch):
    """One malformed `.git/config` must not take down the whole invocation.

    Strict decoding raises UnicodeDecodeError, which is a ValueError and therefore caught by NEITHER
    `OSError` nor `subprocess.SubprocessError` -- so it escaped `_git_origin_url` entirely and killed
    a command whose module header promises nothing here is ever fatal. `errors="replace"` in
    borg_core.proc turns the byte into U+FFFD, which the character-class test then rejects.
    """
    monkeypatch.setenv("PATH", _stub_git(tmp_path / "bin", b"'https://github.com/owner/re\xffpo.git'"))
    repository = tmp_path / "repo"
    (repository / ".git").mkdir(parents=True)
    assert shell.repository_slug(str(repository)) == ""


@pytest.mark.parametrize(
    "url",
    ["owner/repo\nowner2/repo2", "https://github.com/owner/repo\n", "https://github.com/owner/repo\r"],
    ids=["embedded-newline", "trailing-newline", "trailing-carriage-return"],
)
def test_repository_slug_rejects_a_remote_carrying_a_line_break(tmp_path, monkeypatch, url):
    # A remote configured with several URLs, and the two forms _git_origin_url's rstrip is currently
    # what removes. The trailing-newline case is what pins `\Z` over `$` in core._SLUG_CHARS_RE: `$`
    # also matches before a trailing newline, so it would let one ride into every ref built from the
    # slug the moment that rstrip moved. The shell's `case` glob rejects all three, because a line
    # break is outside GitHub's character class wherever it sits.
    repository = _git_repository(tmp_path, "r", "git@github.com:owner/repo.git")
    # pylint: disable=protected-access
    monkeypatch.setattr(shell, "_git_origin_url", lambda _d: url)
    assert shell.repository_slug(repository) == ""


def test_repository_slug_feeds_select_for_repository_end_to_end(tmp_path):
    # The wire S3 will use: derive the in-scope repository's slug from git, discover globally, select
    # by slug. Neither half is useful without the other.
    host = _write_manifest(
        tmp_path,
        "host",
        "m.json",
        _manifest([_row("1", "owner/host#1", "l"), _row("2", "owner/member#2", "l")]),
    )
    member = _git_repository(tmp_path, "member", "git@github.com:owner/member.git")
    manifests, _ = shell.discover_registered(_registry(host, member))
    # BOTH HALVES ASSERTED BEFORE THE SELECTION. `== manifests` passes vacuously when discovery
    # returns nothing ([] == []), so a test of "the wire" would report it working while both ends
    # were dead. Stub discover_registered to return ([], []) and this now fails, as it must.
    assert len(manifests) == 1
    assert shell.repository_slug(member) == "owner/member"
    assert core.select_for_repository(manifests, shell.repository_slug(member)) == manifests


# ── structural ───────────────────────────────────────────────────────────────


def _module_level_dotted_names(module_name):
    """Every `a.b` attribute chain appearing OUTSIDE a function or class body in one module."""
    here = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.join(here, module_name), encoding="utf-8") as handle:
        tree = ast.parse(handle.read())
    found = []
    for node in tree.body:
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            continue
        for sub in ast.walk(node):
            if isinstance(sub, ast.Attribute) and isinstance(sub.value, ast.Name):
                found.append(f"{sub.value.id}.{sub.attr}")
    return found


def test_module_reads_no_environment_or_clock_at_import_time():
    """Asserted on the SOURCE, not on the namespace, because the namespace check tested a naming
    convention rather than the thing it is named for.

    A module-level constant frozen from the first import would ignore every later change, while the
    zsh original re-reads on every call. The old assertion -- no module-level name starts with
    `BORG_` -- was satisfied by `GIT_TIMEOUT_SECONDS = int(os.environ.get("BORG_GIT_TIMEOUT", "5"))`,
    which is the exact bug it describes and one line away, since `os` is already imported at module
    scope. Parsing the source catches the read wherever the value is bound.
    """
    forbidden = ("os.environ", "os.getenv", "time.time", "time.monotonic", "datetime.now")
    for module_name in ("shell.py", "core.py"):
        offenders = [n for n in _module_level_dotted_names(module_name) if n in forbidden]
        assert offenders == [], f"{module_name} reads {offenders} at import time"
    # core.py's only module-scope calls are `re.compile`, which read nothing outside the process.
    assert set(_module_level_dotted_names("core.py")) == {"re.compile"}
    assert not [name for name in vars(shell) if name.startswith("BORG_")]
    assert "time" not in vars(shell)


def test_the_domain_layer_imports_no_io_modules():
    """core.py's purity is enforced by review and by this test, NOT by the linter: the clean-arch
    plugin's allow-list includes pathlib and json, so `Path(x).read_text()` inside core.py would keep
    `make lint` green.

    A WHITELIST OVER OBJECT IDENTITY, not a blacklist of binding names. The previous version listed
    forbidden NAMES, so `from pathlib import Path as P` or `from json import loads` bound `P` and
    `loads`, neither of which was in the list -- including the exact `Path(x).read_text()` case its
    own comment said it existed to catch. What is checked here is where each bound object CAME FROM,
    which an alias cannot change.
    """
    allowed_roots = {"borg_core", "builtins", "typing", "re", "__future__"}
    offenders = []
    for name, value in vars(core).items():
        if name.startswith("__"):
            continue
        if isinstance(value, types.ModuleType):
            origin = value.__name__
        else:
            origin = getattr(value, "__module__", "builtins") or "builtins"
        if origin.split(".")[0] not in allowed_roots:
            offenders.append(f"{name} -> {origin}")
    assert offenders == [], f"core.py must not import I/O: {offenders}"


def test_no_module_references_an_external_plugin_or_a_sibling_checkout():
    """Mechanical, not review-enforced, because the constraint was already violated once by drift.

    borg must work identically on a machine that has never heard of another plugin, and no module may
    bake in a path into a sibling checkout. Only STRING LITERALS count for the path check -- a
    docstring may legitimately show an example path.
    """
    here = os.path.dirname(os.path.abspath(__file__))
    forbidden = ("ai-data-engineer", "stacked-pr-program", "stamp_stack")
    offenders = []
    for name in ("core.py", "shell.py", "__init__.py"):
        with open(os.path.join(here, name), encoding="utf-8") as handle:
            body = handle.read()
        offenders += [f"{name}: {token}" for token in forbidden if token in body]
        for lineno, line in enumerate(body.splitlines(), 1):
            for literal in re.findall(r"""["']([^"']*)["']""", line):
                # `/dev/null` is the device node every quoted shell command redirects to, not a
                # checkout under the workspace root. What must never appear is a path into a
                # sibling repository.
                if "/dev/" in literal.replace("/dev/null", ""):
                    offenders.append(f"{name}:{lineno} -> {literal}")
    assert offenders == [], f"independence violations: {offenders}"
