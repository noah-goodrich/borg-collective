"""Unit tests for borg_core.manifest.shell (the I/O layer).

Calling convention: in-process only, against real directories under `tmp_path`, real `git`
repositories built by `_git_repository` and real linked worktrees built by `_git_worktree`. Two
things a real `git` cannot be persuaded to produce are driven by a stub `git` on PATH (`_stub_git`):
a URL with trailing whitespace, which git config trims on read, and one that is not valid UTF-8.
NOTHING here monkeypatches subprocess any more: the timeout case used to, and that coupled it to
borg_core/proc.py's internals rather than its contract, so it broke the moment run_capture moved to
Popen + a new session + a temp-file sink. It now stands up a `git` that hangs and shortens
GIT_TIMEOUT_SECONDS, which runs the real path -- including the kill -- in 200ms.

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

from borg_core.manifest import across, core, errors, refs, shell


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
    """Put one manifest in the directory `shell.manifest_dir` NAMES for `<root>/<repository>`.

    DERIVED, never spelled `.borg/programs` here, because a fixture holding its own copy of that
    literal survives a rename by writing to the OLD directory while `shell.discover` reads the new
    one -- and `shell.discover` is silent by documented design when a repository exists but its
    manifest directory is simply absent, so the sweep comes back `([], [])`. Clean, empty, and green
    through every "for every declared ref ..." loop in this file. `shell.manifest_dir`'s own docstring
    says the `programs` literal "stays until a rename directive moves it", and AC7 has that rename
    filed, so this is a dated time bomb rather than a hypothetical one.

    Deriving the path is half of that; `_e2a_swept`'s exact count assertion is the other half, and
    neither alone is enough -- a rename would still be caught by the count, but as a mystery rather
    than as a rename.

    `doc` is a dict OR an already-serialised string: the malformed-JSON cases have to put bytes on
    disk that `json.dumps` could never produce.
    """
    directory = shell.manifest_dir(str(root / repository))
    os.makedirs(directory, exist_ok=True)
    body = doc if isinstance(doc, str) else json.dumps(doc)
    with open(os.path.join(directory, name), "w", encoding="utf-8") as handle:
        handle.write(body)
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
    for module in (core, errors, refs, shell):
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
    # WARNINGS ARE ASSERTED HERE, not discarded. A clean multi-repository sweep is the whole of what
    # evals/s4-k3/run.sh's E1 checked before it was deleted 2026-09-02, and E1 asserted the
    # conjunction -- both manifests AND `warnings == []`. This case had the count but threw the
    # warnings away as `manifests, _`, so the eval was not in fact redundant until the conjunct
    # landed here. Two temp directories, no git and no network, which is why this is the right home
    # for it and a second real repository on disk never was.
    a = _write_manifest(tmp_path, "a", "x.json", _manifest([_row("1", "o/a#1")]))
    b = _write_manifest(tmp_path, "b", "y.json", _manifest([_row("1", "o/b#1")]))
    manifests, warnings = shell.discover([a, b])
    assert len(manifests) == 2
    assert warnings == []


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
    """A REAL `git` that hangs, against a REAL (shortened) deadline.

    This used to raise TimeoutExpired out of a monkeypatched `proc.subprocess.run`, which asserted
    proc.py's INTERNALS rather than its contract and broke when run_capture moved to Popen + a new
    session + a temp-file sink. Standing up a hanging stub and shortening GIT_TIMEOUT_SECONDS runs
    the whole real path -- including the kill -- for 200ms.
    """
    repository = _git_repository(tmp_path, "r", "git@github.com:owner/repo.git")
    hang_bin = tmp_path / "hang-bin"
    hang_bin.mkdir(parents=True, exist_ok=True)
    (hang_bin / "git").write_text("#!/bin/sh\nsleep 30\n", encoding="utf-8")
    (hang_bin / "git").chmod(0o755)
    monkeypatch.setenv("PATH", str(hang_bin) + os.pathsep + os.environ["PATH"])
    monkeypatch.setattr(shell, "GIT_TIMEOUT_SECONDS", 0.2)
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


def _package_module_names():
    """Every non-test module in this package, sorted -- the list both structural tests below iterate.

    ENUMERATED RATHER THAN SPELLED OUT, because a hardcoded tuple is a list that gets forgotten. Two
    of them used to stand here, and `across.py` was added to the package and to NEITHER, so the
    newest module in the package was the one module with no import-time purity check and no
    independence check on it at all -- silently, since both tests were still green over the five
    files they did name. That is the same silent-omission class this change argues about for the
    clean-arch Domain map in `pyproject.toml`; caught there, missed here. A glob cannot be forgotten.

    THE TWO ASSERTIONS ARE THE DERIVATION'S OWN ORACLE, and they live here rather than being restated
    in both callers for the same reason `_e2a_swept`'s precondition does: a check that enumerates
    nothing is green. Non-empty catches a glob that matches nothing at all -- a moved file, a renamed
    package, a `__file__` that no longer resolves. Naming `across.py` catches the narrower failure
    the non-empty check cannot see: a glob that happens to match only the modules the old tuples
    already covered, which is exactly the state being fixed.

    Only `test_*.py` is excluded. Everything else in the directory ships, `__init__.py` included, and
    both constraints below are true of every shipped file rather than of an interesting subset.
    """
    here = os.path.dirname(os.path.abspath(__file__))
    names = sorted(name for name in os.listdir(here) if name.endswith(".py") and not name.startswith("test_"))
    assert names, f"the module glob enumerated nothing under {here}"
    assert "across.py" in names, f"the module the old hardcoded tuples forgot must be derived: {names}"
    return names


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

    Over EVERY module in the package, derived by `_package_module_names` -- see its docstring for why
    the four-name tuple that used to sit on the loop below was itself the bug.
    """
    forbidden = ("os.environ", "os.getenv", "time.time", "time.monotonic", "datetime.now")
    for module_name in _package_module_names():
        offenders = [n for n in _module_level_dotted_names(module_name) if n in forbidden]
        assert offenders == [], f"{module_name} reads {offenders} at import time"
    # core.py's module-scope dotted names are `re.compile` for the one regex that did NOT move
    # (`_ORDER_DIGITS`, about ordering rather than refs) and nothing else. The ref re-exports use an
    # `import ... as ...` form precisely so they do not land here: an `x = _refs.x` assignment is an
    # attribute read, and this assertion was growing a list of re-export names in a test about
    # clocks. If a name appears below, it is a real new module-scope read and wants looking at.
    assert set(_module_level_dotted_names("core.py")) == {"re.compile"}
    assert set(_module_level_dotted_names("refs.py")) == {"re.compile"}
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

    Over EVERY module in the package, derived by `_package_module_names` -- see its docstring for why
    the five-name tuple that used to sit on the loop below was itself the bug.
    """
    here = os.path.dirname(os.path.abspath(__file__))
    forbidden = ("ai-data-engineer", "stacked-pr-program", "stamp_stack")
    offenders = []
    for name in _package_module_names():
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


# ── row-level degradation: a bad row must not cost the file ───────────────────────────────────────
#
# Before this, ANY validation error dropped the whole manifest. Measured on the AC2 fixtures at the
# time: one mistyped `gate.kind` took the orchestrator grid from 12 declared refs to 5 — seven rows
# vanished from `▸ CHAINS` because of one word in one field, and the page kept its confident frame.
# See docs/plans/directives/2026-08-27-degrade-the-row-not-the-manifest.md.
#
# THE DEFECT THESE CASES USE IS NO LONGER A MISTYPED `kind`, and the swap is the point of the follow-
# up change: an unrecognized kind is now a ROUTER concern, so the row loads and routes to `unsure`
# instead of being dropped. A gate that names no settlement has no such renderer-side answer, so it
# is the defect that still costs its row — and it exercises the identical partition/drop path.

_BAD_GATE = {"kind": "decision", "blocked_by": "someone"}


def test_one_invalid_row_costs_the_row_and_not_the_file(tmp_path):
    """MUTATION: restore `if errors: return None, ...` in `_load_manifest`.

    The survivors load, rank and render; the warning names the count so a reader can tell "3 rows"
    from "4 rows and I am showing you 3".
    """
    doc = _manifest(
        [
            _row("1", "o/r#1"),
            _row("2", "o/r#2", gate=_BAD_GATE),
            _row("3", "o/r#3"),
            _row("4", "o/r#4"),
        ]
    )
    p = _write_manifest(tmp_path, "repo", "a.json", doc)
    manifests, warnings = shell.discover([p])

    assert len(manifests) == 1, "the file survives"
    refs = [r["ref"] for r in manifests[0]["rows"]]
    assert refs == ["o/r#1", "o/r#3", "o/r#4"], "only the offending row is gone"

    assert len(warnings) == 1
    assert "1 of 4 rows dropped" in warnings[0]
    assert "gate.resolved_by is required" in warnings[0], "the validator's own message is carried verbatim"
    assert "a.json" in warnings[0], "and the file is named"


def test_a_warning_survives_alongside_a_loaded_manifest(tmp_path):
    """The caller used to append the warning only when the manifest was None.

    MUTATION: restore `if manifest is None: warnings.append(warning)`. The rows still drop, the
    picture still goes short, and the one message explaining why is swallowed — a silent version of
    the bug this whole directive exists to remove.
    """
    p = _write_manifest(tmp_path, "repo", "a.json", _manifest([_row("1", "o/r#1"), _row("2", "o/r#2", gate=_BAD_GATE)]))
    manifests, warnings = shell.discover([p])
    assert manifests and warnings, "BOTH, not one or the other"


def test_a_manifest_whose_every_row_fails_is_still_dropped_whole(tmp_path):
    """MUTATION: drop the `if not kept` guard — an empty manifest loads and renders a headed blank.

    There is no page to render and nothing is gained by pretending. The message stays the original
    `invalid manifest` one, not the row-drop one.
    """
    p = _write_manifest(
        tmp_path, "repo", "a.json", _manifest([_row("1", "o/r#1", gate=_BAD_GATE), _row("2", "o/r#2", gate=_BAD_GATE)])
    )
    manifests, warnings = shell.discover([p])
    assert manifests == []
    assert "invalid manifest" in warnings[0]
    assert "rows dropped" not in warnings[0]


def test_a_structural_failure_still_drops_the_file(tmp_path):
    """MUTATION: treat every error as row-scoped.

    `apex: ...` describes a SIBLING KEY, not a row, so there is no subset of rows you could keep and
    still be describing what the author wrote. This is the case a naive fix slips through: every row
    here is FINE, so a row-index partition finds nothing to drop — and must not conclude from that
    that the file is clean.

    THE OTHER STRUCTURAL ERROR IS UNREACHABLE FROM HERE, which a first draft of this case got wrong
    by parametrizing over it. `validate`'s `rows: missing or not a list` cannot fire through
    `_load_manifest`, because `core.looks_like_manifest` already rejected the document one branch
    earlier with `not a manifest (no rows list) -- skipped`. The branch is still right to exist —
    `validate` is public and callable directly — it simply is not this function's problem, and
    asserting it here would have pinned a path production never takes.
    """
    doc = {"rows": [{"order": "1", "ref": "o/r#1"}], "apex": {"ref": "nope"}}
    p = _write_manifest(tmp_path, "repo", "a.json", doc)
    manifests, warnings = shell.discover([p])
    assert manifests == []
    assert "apex:" in warnings[0]
    assert "rows dropped" not in warnings[0]


def test_a_non_manifest_is_rejected_before_validation_ever_runs(tmp_path):
    """The branch the case above names as unreachable, pinned at its real altitude.

    MUTATION: delete the `looks_like_manifest` guard. A stray `settings.json` in `.borg/programs/`
    then reaches `validate` and reports `rows: missing or not a list` — a validation verdict on a
    file that was never a manifest.
    """
    p = _write_manifest(tmp_path, "repo", "settings.json", {"theme": "dark"})
    manifests, warnings = shell.discover([p])
    assert manifests == []
    assert "not a manifest (no rows list)" in warnings[0]


def test_survivors_are_revalidated_so_a_loaded_manifest_is_always_valid(tmp_path):
    """MUTATION: return `doc` without re-running `core.validate`.

    Duplicate detection is CROSS-ROW — `_validate_row` flags the SECOND occurrence and leaves the
    first alone — so dropping a row can clear an error on a row that was kept, and can also leave
    one. Re-validating is how "a loaded manifest is a valid manifest" survives; every downstream
    consumer assumes it and none of them re-check.

    Here rows 1 and 2 duplicate `o/r#1`, so row 1 is flagged. Dropping it leaves rows 0 and 2, which
    validate — and the surviving manifest must contain no duplicate.
    """
    p = _write_manifest(
        tmp_path,
        "repo",
        "a.json",
        _manifest([_row("1", "o/r#1"), _row("2", "o/r#1"), _row("3", "o/r#2")]),
    )
    manifests, warnings = shell.discover([p])
    assert len(manifests) == 1
    refs = [r["ref"] for r in manifests[0]["rows"]]
    assert refs == ["o/r#1", "o/r#2"]
    assert len(refs) == len(set(refs)), "no duplicate survives"
    assert core.validate(manifests[0]) == [], "the loaded manifest validates"
    assert "1 of 3 rows dropped" in warnings[0]


def test_partition_errors_splits_row_scoped_from_structural():
    """The format contract, asserted where the format lives.

    MUTATION: match `rows[` without the index group, or anchor without `^`. Both break the
    `rows[N].after[M]` form, which `_validate_after` produces and which carries no colon after the
    bracket.
    """
    bad_rows, structural = core.partition_errors(
        [
            "rows[0]: missing order",
            "rows[0]: gate.resolved_by is required",
            "rows[3].after[1] must be a full ref (owner/repo#num), got nope",
            "apex: ref must be a full ref (owner/repo#num), got nope",
            "rows: missing or not a list",
        ]
    )
    assert bad_rows == {0, 3}, "two errors on row 0 collapse to one row to drop"
    assert structural == [
        "apex: ref must be a full ref (owner/repo#num), got nope",
        "rows: missing or not a list",
    ]


# ── write_manifest ───────────────────────────────────────────────────────────
#
# The writer is the ONE fatal path in shell.py. These cases pin the asymmetry the module docstring
# argues for: a read degrades and names what it dropped, a write refuses whole and hands back why.


def test_a_written_manifest_round_trips_through_the_reader(tmp_path):
    # The asymmetry core.py's docstring named -- "a manifest the writer accepts can be silently
    # unreadable by the reader" -- is what the port exists to end. Anything written loads back with
    # no warning and no dropped row.
    repository = _git_repository(tmp_path, "repo", remote="https://github.com/o/r.git")
    doc = _manifest([_row("1", "o/r#1"), _row("2", "o/r#2", lane="viz")])
    path = shell.write_manifest(repository, doc, "chain")

    assert path == os.path.join(repository, ".borg", "programs", "chain.json")
    manifests, warnings = shell.discover([repository])
    assert warnings == []
    assert len(manifests) == 1
    assert [r["ref"] for r in manifests[0]["rows"]] == ["o/r#1", "o/r#2"]


def test_the_writer_persists_no_derived_key(tmp_path):
    # The old writer stripped exactly `_path`, so every synced file gained a permanent `_id` that
    # nothing reads and nothing rejects. Feed the writer a document straight off the READER, which
    # stamps both, and assert neither survives.
    repository = _git_repository(tmp_path, "repo", remote="https://github.com/o/r.git")
    shell.write_manifest(repository, _manifest([_row("1", "o/r#1")]), "chain")
    loaded, _ = shell.discover([repository])
    assert "_path" in loaded[0] and "_id" in loaded[0], "precondition: the reader stamps both"

    rewritten = shell.write_manifest(repository, loaded[0], "chain")
    on_disk = json.loads(open(rewritten, encoding="utf-8").read())
    assert [k for k in on_disk if k.startswith("_")] == []


def test_the_writer_never_injects_the_retired_word(tmp_path):
    # AC7. The writer this replaces did `to_write.setdefault("program", program)`, three files from
    # a loader that refuses to synthesize it. The commit that retires the word must not ship a
    # writer that keeps writing it.
    repository = _git_repository(tmp_path, "repo", remote="https://github.com/o/r.git")
    path = shell.write_manifest(repository, _manifest([_row("1", "o/r#1")]), "named-chain")
    assert "program" not in json.loads(open(path, encoding="utf-8").read())


def test_a_declared_program_key_is_preserved_not_invented(tmp_path):
    # The complement of the case above, and the reason it is `declared_body` rather than a blocklist:
    # a file that ALREADY carries the word on disk keeps it. Reading a retired word is unavoidable;
    # synthesizing one is not, and silently deleting the author's key would be a third wrong answer.
    repository = _git_repository(tmp_path, "repo", remote="https://github.com/o/r.git")
    doc = {**_manifest([_row("1", "o/r#1")]), "program": "declared-id"}
    path = shell.write_manifest(repository, doc, "chain")
    assert json.loads(open(path, encoding="utf-8").read())["program"] == "declared-id"


def test_an_invalid_manifest_is_refused_whole_and_writes_nothing(tmp_path):
    # Validate-all-then-fail. A partial write is worse than a refusal: it is wrong on disk forever.
    repository = _git_repository(tmp_path, "repo", remote="https://github.com/o/r.git")
    doc = _manifest([_row("1", "o/r#1"), _row("2", "shorthand#2")])

    with pytest.raises(shell.InvalidManifest) as caught:
        shell.write_manifest(repository, doc, "chain")

    assert "rows[1]" in str(caught.value)
    assert not os.path.exists(os.path.join(repository, ".borg", "programs", "chain.json"))


def test_a_refused_write_leaves_no_temp_file(tmp_path):
    # A fixed `<path>.tmp` name races and can orphan litter inside a git-tracked directory.
    repository = _git_repository(tmp_path, "repo", remote="https://github.com/o/r.git")
    shell.write_manifest(repository, _manifest([_row("1", "o/r#1")]), "ok")
    with pytest.raises(shell.InvalidManifest):
        shell.write_manifest(repository, _manifest([_row("1", "bad#1")]), "nope")

    directory = os.path.join(repository, ".borg", "programs")
    assert sorted(os.listdir(directory)) == ["ok.json"]


def test_a_shorthand_ref_naming_this_repository_is_suggested_not_repaired(tmp_path):
    # The common defect: a model writing `repo#12` for a PR in the repository it is standing in. The
    # message carries the exact token to substitute; the DOCUMENT is never rewritten, because a
    # repaired-but-wrong slug resolves against nothing and vanishes from the graph silently.
    repository = _git_repository(tmp_path, "repo", remote="https://github.com/noah-goodrich/repo.git")
    with pytest.raises(shell.InvalidManifest) as caught:
        shell.write_manifest(repository, _manifest([_row("1", "repo#12")]), "chain")

    assert "did you mean noah-goodrich/repo#12?" in str(caught.value)
    assert not os.path.exists(os.path.join(repository, ".borg", "programs", "chain.json"))


def test_a_shorthand_ref_naming_another_repository_gets_no_guess(tmp_path):
    # A manifest's whole purpose is naming PRs in OTHER repositories, so "the containing repository"
    # is the least reliable guess available. Offered only when the author already named the repo.
    repository = _git_repository(tmp_path, "repo", remote="https://github.com/noah-goodrich/repo.git")
    with pytest.raises(shell.InvalidManifest) as caught:
        shell.write_manifest(repository, _manifest([_row("1", "stillpoint#4")]), "chain")

    assert "did you mean" not in str(caught.value)


def test_the_refusal_carries_one_reason_per_error(tmp_path):
    # `errors` is the unjoined list because the CLI seam prints one reason per line. Re-splitting a
    # joined string is how a message format becomes an undeclared contract.
    repository = _git_repository(tmp_path, "repo", remote="https://github.com/o/r.git")
    doc = _manifest([_row("1", "bad#1"), {"ref": "o/r#2"}])
    with pytest.raises(shell.InvalidManifest) as caught:
        shell.write_manifest(repository, doc, "chain")

    assert len(caught.value.errors) == 2
    assert isinstance(caught.value, ValueError), "callers already catching ValueError keep working"


def test_the_name_is_basenamed_so_a_slash_cannot_escape_the_directory(tmp_path):
    # Path discipline lives in the writer, not at every call site: the old writer took the caller's
    # filename verbatim, and a caller passing a manifest's declared id (which may contain a slash)
    # could write outside the directory.
    repository = _git_repository(tmp_path, "repo", remote="https://github.com/o/r.git")
    path = shell.write_manifest(repository, _manifest([_row("1", "o/r#1")]), "../../escape")
    assert path == os.path.join(repository, ".borg", "programs", "escape.json")


def test_a_name_that_already_ends_in_json_is_not_doubled(tmp_path):
    # `add-row` passes a stem; a rewrite passes an existing basename. Both land on one path.
    repository = _git_repository(tmp_path, "repo", remote="https://github.com/o/r.git")
    stem = shell.write_manifest(repository, _manifest([_row("1", "o/r#1")]), "chain")
    full = shell.write_manifest(repository, _manifest([_row("1", "o/r#1")]), "chain.json")
    assert stem == full


def test_a_non_ascii_order_survives_the_round_trip_unescaped(tmp_path):
    # `core.PREREQ_ORDERS` treats U+2013 as a declared order and the live corpus contains it.
    # Escaping it to – rewrites bytes in a tracked file on a sync that changed nothing.
    repository = _git_repository(tmp_path, "repo", remote="https://github.com/o/r.git")
    path = shell.write_manifest(repository, _manifest([_row("–", "o/r#1")]), "chain")
    assert "–" in open(path, encoding="utf-8").read()
    assert "\\u2013" not in open(path, encoding="utf-8").read()


def test_write_creates_the_manifest_directory_when_absent(tmp_path):
    repository = _git_repository(tmp_path, "fresh", remote="https://github.com/o/r.git")
    assert not os.path.isdir(os.path.join(repository, ".borg", "programs"))
    shell.write_manifest(repository, _manifest([_row("1", "o/r#1")]), "chain")
    assert os.path.isdir(os.path.join(repository, ".borg", "programs"))


def test_declared_body_is_the_one_definition_of_derived(tmp_path):
    # Reader and writer must agree on which keys are derived. Two hand-written copies of this strip
    # is how the old writer came to remove `_path` and persist `_id`.
    body = core.declared_body({"rows": [], "_path": "/x", "_id": "y", "desc": "kept"})
    assert body == {"rows": [], "desc": "kept"}


# ── refused_manifest_paths ───────────────────────────────────────────────────


def test_refused_paths_names_both_whole_file_refusals(tmp_path):
    # The two shapes that mean "a file here looks like a manifest and could not be used".
    repository = _write_manifest(tmp_path, "repo", "broken.json", {"rows": [{"order": "1"}]})
    (tmp_path / "repo" / ".borg" / "programs" / "garbage.json").write_text("{not json", encoding="utf-8")
    _, warnings = shell.discover([repository])

    refused = shell.refused_manifest_paths(warnings)
    assert sorted(os.path.basename(p) for p in refused) == ["broken.json", "garbage.json"]


def test_a_stray_non_manifest_is_not_a_refusal(tmp_path):
    # `not a manifest (no rows list)` describes a stray settings.json sitting in the directory, not a
    # manifest that failed. Counting it would make CHAINS claim a broken manifest that does not exist.
    directory = tmp_path / "repo" / ".borg" / "programs"
    directory.mkdir(parents=True)
    (directory / "settings.json").write_text('{"theme": "dark"}', encoding="utf-8")
    _, warnings = shell.discover([str(tmp_path / "repo")])

    assert warnings, "precondition: the stray file is still warned about"
    assert shell.refused_manifest_paths(warnings) == []


def test_refused_paths_narrows_to_one_repository(tmp_path):
    # Warnings are registry-WIDE. A manifest refused in another repository must not change what this
    # repository's page says about itself.
    mine = _write_manifest(tmp_path, "mine", "broken.json", {"rows": [{"order": "1"}]})
    _write_manifest(tmp_path, "theirs", "broken.json", {"rows": [{"order": "1"}]})
    _, warnings = shell.discover([mine, str(tmp_path / "theirs")])

    assert len(shell.refused_manifest_paths(warnings)) == 2
    narrowed = shell.refused_manifest_paths(warnings, mine)
    assert len(narrowed) == 1 and narrowed[0].startswith(mine)


def test_narrowing_does_not_match_a_sibling_by_prefix(tmp_path):
    # `<root>/repo` must not swallow `<root>/repo-two`. The separator is why `under` is joined with
    # os.path.join(under, "") rather than tested with a bare startswith.
    _write_manifest(tmp_path, "repo", "ok.json", _manifest([_row("1", "o/r#1")]))
    two = _write_manifest(tmp_path, "repo-two", "broken.json", {"rows": [{"order": "1"}]})
    _, warnings = shell.discover([str(tmp_path / "repo"), two])

    assert shell.refused_manifest_paths(warnings, str(tmp_path / "repo")) == []
    assert len(shell.refused_manifest_paths(warnings, two)) == 1


def test_a_partially_dropped_manifest_is_not_a_refusal(tmp_path):
    # It DID load. Counting it would make CHAINS print "could not be read" above a rendered chain.
    doc = _manifest([_row("1", "o/r#1"), _row("2", "shorthand#2")])
    repository = _write_manifest(tmp_path, "repo", "partial.json", doc)
    manifests, warnings = shell.discover([repository])

    assert len(manifests) == 1, "precondition: the file loaded with its good row"
    assert "rows dropped" in warnings[0]
    assert shell.refused_manifest_paths(warnings) == []


# ── E2a: the eight structural ref properties, offline, over a two-repository tree ─────────────────
#
# WHAT THIS SECTION IS. `evals/s4-k3/run.sh`'s case E2 asks "does every declared ref resolve on
# GitHub". Its own comment records that exactly ONE bit of that needs the network -- "does
# owner/repo#N exist, and can this token see it" -- and that "every OTHER property E2 appears to
# check ... is already enforced offline by borg_core.manifest's validator, and belongs in pytest
# rather than here". Last session measured that remainder at EIGHT properties and wrote the count
# into a checkpoint without ever writing the eight down, so the number has been a claim in prose ever
# since. This section is that claim turned into an artifact that can go red.
#
# THE EIGHT, each named for the function that already enforces it. Nothing here is a new rule and
# every one has a unit home in test_core.py. What is new is asserting them TOGETHER over a
# DISCOVERED two-repository set -- the composition no existing case covers, and the one E2 was
# standing in for:
#
#   1. SHAPE -- every row ref matches a recognized vocabulary, and `core.validate` rejects one that
#      matches none (`_row_ref_error`).
#   2. KIND -- `refs.ref_kind` classifies each ref as exactly one of github / jira / link, and the
#      three are mutually exclusive.
#   3. TRACKED vs REFERENCE -- the two kind sets are ENUMERATED, not complementary, and
#      `refs.is_reference` decides whether a row participates in ordering at all.
#   4. UNIQUENESS -- a duplicate `rows[].ref` inside one manifest is rejected, naming the earlier
#      index.
#   5. ADDRESSABILITY -- `refs.expects_github` plus `refs.parse_ref` yield the (owner, repo, number)
#      triple AC3's targeted fetch addresses; a ref that will not parse can never be fetched.
#   6. SLUG ATTRIBUTION -- `refs.ref_slug` gives the `owner/repo` that `core.select_for_repository`
#      scopes on, parsed and never prefix-matched.
#   7. COERCION EXACTNESS -- `refs.text` is the ONLY normalization applied, so the string reaching an
#      edge endpoint is byte-identical to the one reaching `core.declared_refs`.
#   8. POINTER CLOSURE -- every non-row ref pointer (each `after` entry, each `gate.blocked_by_ref`,
#      and `apex.ref` when present) is itself a full ref and never the row's own ref.
#
# NO GIT AND NO NETWORK, which is what makes this the right home rather than the harness:
# `shell.discover` is `os.listdir` plus `open`, so a git repository is not needed at all, and every
# ref property above is pure. The tree is deliberately CROSS-REPOSITORY IN BOTH DIRECTIONS --
# `auth-scopes` declares a warehouse row and `keypair-rotation`'s gate points back at a platform
# row -- because a tree whose every ref is repository-local passes property 6 vacuously. It also
# names a THIRD slug that no directory in the tree corresponds to: `keypair-rotation` declares a row
# in `acme/plat`, which is a STRICT PREFIX of `acme/platform`. That is what gives property 6 a
# falsifiable selection rather than a restated one, and it doubles as the discovery-is-global /
# selection-is-scoped shape -- the file sits under the `warehouse` directory and is selected by
# neither of the slugs that directory suggests.
#
# THE `e2a` TOKEN IN EVERY TEST NAME IS LOAD-BEARING. `python3 -m pytest borg_core/manifest/
# test_shell.py -k e2a` is being wired into the eval harness as its one always-runnable case, and a
# rename that drops the token does not fail there -- it SELECTS NOTHING, and a gate that selected
# zero cases is green. Rename these and the harness invocation in the same commit.
#
# EVERY NUMBER HERE IS AUTHORED, NOT READ OFF THE OUTPUT. The edge count carries its derivation in
# the case that asserts it, and three negatives move it (+1, -1) or move the contested count
# (0 -> 1). A test whose expected value came from the implementation it checks is not an oracle, so
# if the code ever disagrees with the derivation the number stays and the disagreement is the finding.

_E2A_APEX = {"ref": "acme/platform#900", "label": "auth scopes tracker"}

# The row inventory, per manifest, in declared order. Written here rather than derived from the
# fixture builders so the expectation and the fixture are two artifacts rather than one -- which is
# also why `acme/plat#12` is spelled out twice (here and in the builder) instead of being hoisted
# into a shared constant: one constant read by both sides is one artifact again.
_E2A_ROW_REFS = {
    "auth-scopes": ["acme/platform#400", "acme/platform#420", "acme/warehouse#87"],
    "keypair-rotation": [
        "acme/warehouse#61",
        "acme/warehouse#64",
        "acme/warehouse#70",
        "acme/plat#12",
    ],
}


def _e2a_platform_doc(declared_id=True):
    """`platform`'s manifest: an apex, an intra-lane fork, and one row in the OTHER repository.

    Both non-head rows declare `after`, which is what suppresses the lane's own adjacencies -- see
    the edge-count case for the arithmetic that depends on it.
    """
    doc = _manifest(
        [
            _row("1", "acme/platform#400"),
            _row("2", "acme/platform#420", after=["acme/platform#400"]),
            _row("3", "acme/warehouse#87", after=["acme/platform#400"]),
        ],
        apex=dict(_E2A_APEX),
    )
    return {**doc, "program": "auth-scopes"} if declared_id else doc


def _e2a_warehouse_doc(declared_id=True):
    """`warehouse`'s manifest: a three-row lane whose tail is gated on a PLATFORM row, plus a
    one-row second lane in `acme/plat` -- a real slug that is a STRICT PREFIX of `acme/platform`.

    The gate carries all four fields on purpose. `blocked_by`/`resolved_by` are prose and required;
    `blocked_by_ref` is the optional machine-readable companion and the only channel that becomes a
    `blocks` edge, which is the second half of the cross-repository shape this tree exists to make.

    THE FOURTH ROW IS PROPERTY 6'S ORACLE AND COSTS THE ARITHMETIC NOTHING, which is the whole reason
    it is HERE rather than in the platform manifest. `acme/plat#12` sits alone in a second lane, and
    `_stacked_edges` zips consecutive rows WITHIN a lane, so a lane of one has no adjacency to emit;
    this manifest also carries no apex, so there is no per-row `apex` edge to pick up. In
    `auth-scopes` the same row would have cost +1, because `_apex_edges` emits one edge per row
    unconditionally, and the authored 8 would have had to move for a reason that has nothing to do
    with edges. It stays out of every `ready_set` answer below for a second, independent reason: no
    case puts it in `states`, and an unknown state is not open.
    """
    doc = _manifest(
        [
            _row("1", "acme/warehouse#61"),
            _row("2", "acme/warehouse#64"),
            _row(
                "3",
                "acme/warehouse#70",
                gate={
                    "kind": "verification",
                    "blocked_by": "the platform scope migration must land before any rotation",
                    "blocked_by_ref": "acme/platform#400",
                    "resolved_by": "run the rotation drill against staging and attach the output",
                },
            ),
            _row("1", "acme/plat#12", lane="prefix"),
        ]
    )
    return {**doc, "program": "keypair-rotation"} if declared_id else doc


def _e2a_intruder_doc(declared_id=True):
    """A THIRD manifest, living in `warehouse`, that claims a row `auth-scopes` already declares.

    Its second row is its own. A report that named every ref of a colliding manifest rather than the
    shared one would therefore come back with two lines, which is what makes the arity assertion in
    the contested case discriminating rather than decorative.
    """
    doc = _manifest([_row("1", "acme/platform#400"), _row("2", "acme/warehouse#99")])
    return {**doc, "program": "platform-audit"} if declared_id else doc


def _e2a_tree(tmp_path, *, warehouse=None, intruder=False, declared_ids=True):
    """Write the two-repository tree and return the repository paths in sweep order.

    Called twice against one `tmp_path` it REWRITES the same files, which is exactly what the
    retired-key tripwire needs: rediscovering a tree whose `program` keys were just removed must
    still report the collision that was there before they went.

    ONLY `warehouse` IS OVERRIDABLE, and the asymmetry is arranged rather than an oversight. The two
    count cases below move the total by exactly one LANE ADJACENCY, and only this manifest admits
    that: it declares no apex, so a row appended to or dropped from its default lane moves one
    adjacency and nothing else. `auth-scopes` carries an apex and `_apex_edges` emits one edge per row
    unconditionally, so a row appended there costs two (its adjacency AND its apex edge) and a row
    dropped there costs its apex edge on top of every `after` edge that names it -- see the
    edge-count case for the arithmetic. A matching `platform=` parameter did sit here, and its
    `platform or <default>` guard could never take its left operand because no caller passed one:
    dead code in a section whose entire subject is non-vacuity. Add it back WITH the case that needs
    it, not before.
    """
    paths = [
        _write_manifest(tmp_path, "platform", "auth-scopes.json", _e2a_platform_doc(declared_ids)),
        _write_manifest(tmp_path, "warehouse", "keypair-rotation.json", warehouse or _e2a_warehouse_doc(declared_ids)),
    ]
    if intruder:
        _write_manifest(tmp_path, "warehouse", "platform-audit.json", _e2a_intruder_doc(declared_ids))
    return paths


def _e2a_swept(tmp_path, **kwargs):
    """The tree, discovered. ASSERTS THE SWEEP IS CLEAN **AND** COMPLETE before handing it back.

    The precondition lives here rather than being restated in fifteen cases because it is the one
    that makes every other assertion in the section non-vacuous: a warning means the validator
    refused a fixture, a refused fixture is absent from `manifests`, and "for every declared ref ..."
    over an empty list passes. That is the shape this whole section exists to make impossible, so it
    is enforced on every entry rather than remembered.

    BOTH HALVES, because zero warnings is ALSO what a sweep that found nothing at all reports, and
    for a while only the first half was here. `shell.discover` warns about a repository DIRECTORY it
    cannot find and stays deliberately silent about a repository whose manifest directory is simply
    absent -- the common case, and the one a fixture writing to the wrong path produces. So the empty
    sweep is indistinguishable from the clean sweep on warnings alone, and four cases in this section
    -- including one whose name is a claim about a tree -- would have gone green over nothing. The
    count is the discriminator, and it is exact rather than a floor: a floor cannot tell a lost
    manifest from a tree that was never written.
    """
    expected = 3 if kwargs.get("intruder") else 2
    manifests, warnings = shell.discover(_e2a_tree(tmp_path, **kwargs))
    assert warnings == [], f"the fixture must be valid before anything is asserted about it: {warnings}"
    # 0 here means the fixture wrote somewhere `shell.discover` does not read; anything else in
    # between means a manifest was dropped without a warning to say so.
    assert len(manifests) == expected, f"empty or partial sweep: {len(manifests)} of {expected} manifests discovered"
    return manifests


def _e2a_by_id(manifests):
    """The swept manifests keyed by the id the loader stamped, so a case can name one by hand."""
    return {m["_id"]: m for m in manifests}


def _e2a_triples(edges):
    """`(kind, parent, child)` for each edge -- the identity a hand derivation can be written in.

    `source` is deliberately projected away: it is `declared` on every edge these fixtures can
    produce, so carrying it would make the expected set wider without making it stricter.
    """
    return {(e["kind"], e["parent"], e["child"]) for e in edges}


def test_e2a_the_two_repository_tree_is_discovered_whole_and_clean(tmp_path):
    """The premise every other e2a case rests on, asserted WITHOUT the helper that asserts it.

    Two repositories, two manifests, zero warnings, and the ids the loader stamped. A warning here
    would mean a fixture the validator rejects, which drops it from the sweep and makes every
    "for every declared ref ..." assertion below true of nothing.
    """
    manifests, warnings = shell.discover(_e2a_tree(tmp_path))
    assert len(manifests) == 2
    assert warnings == []
    assert sorted(m["_id"] for m in manifests) == ["auth-scopes", "keypair-rotation"]


def test_e2a_property_1_shape_every_row_ref_matches_a_recognized_vocabulary(tmp_path):
    """1/8 SHAPE. Every row in the tree names something `refs.ref_kind` recognizes, in declared order.

    NEGATIVE: `platform#400` -- the shorthand a model writes for a PR in the repository it is
    standing in -- matches no vocabulary, so `_row_ref_error` reports it and the row never loads.
    That is the single most common authoring mistake and the reason "" is a kind rather than a
    fallback: accepting anything non-empty is what let it resolve against nothing, silently.
    """
    by_id = _e2a_by_id(_e2a_swept(tmp_path))
    for chain_id, expected in _E2A_ROW_REFS.items():
        assert core.validate(by_id[chain_id]) == []
        assert [row["ref"] for row in by_id[chain_id]["rows"]] == expected
        for ref in expected:
            assert refs.ref_kind(ref) == refs.GITHUB

    problems = core.validate(_manifest([_row("1", "platform#400")]))
    assert len(problems) == 1
    assert "must be a GitHub ref" in problems[0]
    assert errors.offending_value(problems[0]) == "platform#400", "the message hands back the token to fix"


def test_e2a_property_2_kind_classifies_each_ref_as_exactly_one_vocabulary(tmp_path):
    """2/8 KIND. Every ref in the tree is `github`, and the three vocabularies do not overlap.

    Exclusivity is asserted here as INJECTIVITY over one document -- three rows, three distinct
    kinds -- because that is the property a manifest author can observe. The pattern-level proof that
    no two of the three regexes can match one string lives in test_core.py's
    `test_the_three_kinds_are_mutually_exclusive`, which reaches into the private patterns to get it;
    a second copy of that reach does not belong in the I/O suite.

    NEGATIVE: a string that is ALMOST a GitHub ref, and one that is almost a Jira key, both classify
    as "" -- no kind at all. Classification never degrades into a silent fourth bucket, which is what
    makes `ref_kind`'s ladder order irrelevant instead of load-bearing.
    """
    for manifest in _e2a_swept(tmp_path):
        for ref in core.declared_refs(manifest):
            assert refs.ref_kind(ref) == refs.GITHUB

    mixed = [("acme/platform#400", refs.GITHUB), ("OPS-11", refs.JIRA), ("https://notion.so/scopes", refs.LINK)]
    assert core.validate(_manifest([_row(str(i), ref) for i, (ref, _) in enumerate(mixed, 1)])) == []
    assert [refs.ref_kind(ref) for ref, _ in mixed] == [kind for _, kind in mixed]
    assert len({refs.ref_kind(ref) for ref, _ in mixed}) == 3, "three vocabularies, three kinds"
    assert set(refs.TRACKED_REF_KINDS) & set(refs.REFERENCE_REF_KINDS) == set()
    assert refs.ref_kind("platform#400") == "" and refs.ref_kind("ops-11") == ""


def test_e2a_property_3_tracked_and_reference_kinds_are_enumerated_not_complementary(tmp_path):
    """3/8. Every row here is TRACKED, so every row participates in ordering; and because the two kind
    sets are ENUMERATED rather than complementary, a ref of no known kind is in neither and keeps
    blocking.

    Asserted THROUGH `core.ready_set` rather than on the predicates, because the predicates are where
    a test proves nothing: `is_tracked` once had no production caller at all while a link row still
    blocked its lane. Ordering PARTICIPATION is the observable -- flip the lane head from open to
    merged and the row behind it becomes ready.

    NEGATIVES, one per direction of the split. A `link` head does NOT block: it can never merge, so a
    chain that puts its own spec document in a lane would otherwise report nothing ready for as long
    as the document exists. A defect head (`#149`, no vocabulary) DOES keep blocking, and is refused
    by the validator on the way in. Two complementary sets cannot express both answers at once, which
    is why `REFERENCE_REF_KINDS` is a list and not a negation.

    THE FOURTH ROW (`acme/plat#12`, the strict-prefix slug property 6 selects on) is tracked like the
    other three but is deliberately absent from every `states` dict here, so it never appears in a
    ready answer. That is not an omission to tidy up: it is the row-side reading of the same "unknown
    is not merged" rule the last assertion pins from the parent side.
    """
    warehouse = _e2a_by_id(_e2a_swept(tmp_path))["keypair-rotation"]
    head, middle, tail, other_lane = _E2A_ROW_REFS["keypair-rotation"]
    for ref in (head, middle, tail, other_lane):
        assert refs.is_tracked(ref) and not refs.is_reference(ref)

    open_all = {head: "open", middle: "open", tail: "open"}
    assert core.ready_set(warehouse, open_all) == [head], "a tracked head blocks the row behind it"
    assert core.ready_set(warehouse, {**open_all, head: "merged"}) == [middle]

    referenced = _e2a_warehouse_doc()
    referenced["rows"][0]["ref"] = "https://notion.so/rotation-spec"
    assert core.validate(referenced) == [], "a link row is a legal row"
    assert core.ready_set(referenced, {middle: "open", tail: "open"}) == [middle], "a reference never blocks"

    defective = _e2a_warehouse_doc()
    defective["rows"][0]["ref"] = "#149"
    assert core.validate(defective) != [], "and a defect is not a document"
    assert core.ready_set(defective, {middle: "open", tail: "open"}) == [], "unknown is not merged"


def test_e2a_property_4_uniqueness_a_duplicate_row_ref_names_the_earlier_index(tmp_path):
    """4/8 UNIQUENESS, WITHIN one manifest. Two rows for one ref would give that item two chain
    positions and make the derived edge set depend on iteration order.

    NEGATIVE: a fourth row duplicating `acme/platform#400`, which rows[0] already declares. The
    message names the EARLIER index, which is what lets an author find the PAIR rather than only the
    copy -- and the pinned string is why: `_validate_row` flags the second occurrence and leaves the
    first alone, so a message naming only "here" would send the reader to the row that is fine.

    Uniqueness ACROSS manifests is a different question with a different answer: two chains claiming
    one ref is reported by `across.contested_refs`, never refused, and the two contested cases below
    are where that lives.
    """
    for manifest in _e2a_swept(tmp_path):
        row_ref_list = [row["ref"] for row in manifest["rows"]]
        assert len(row_ref_list) == len(set(row_ref_list))

    doubled = _e2a_platform_doc()
    doubled["rows"].append(_row("4", "acme/platform#400"))
    assert core.validate(doubled) == ["rows[3]: duplicate ref acme/platform#400 (already at rows[0])"]


def test_e2a_property_5_addressability_every_declared_ref_parses_into_the_fetch_triple(tmp_path):
    """5/8 ADDRESSABILITY. `refs.parse_ref` yields `(owner, repo, number)` for every declared ref in
    the tree, and the parts reconstruct the ref BYTE FOR BYTE -- `f"{owner}/{name}#{number}"` is the
    address AC3's targeted fetch sends, so a lossy parse fetches a different PR than the one declared.

    NEGATIVE, and it is the PAIR that matters rather than either half: a shorthand ref does not parse
    (`None`, never a half-filled tuple) while `refs.expects_github` still answers True for it. That
    combination is deliberate -- an unfetchable ref of no known kind must be REPORTED by the fetch,
    not skipped the way a jira key or a link is, because it is a defect that should never have
    validated and must not be swallowed a second time.
    """
    for manifest in _e2a_swept(tmp_path):
        for ref in core.declared_refs(manifest):
            assert refs.expects_github(ref) is True
            parts = refs.parse_ref(ref)
            assert parts is not None and len(parts) == 3
            owner, name, number = parts
            assert f"{owner}/{name}#{number}" == ref
            assert number.isdigit()

    assert refs.parse_ref("platform#400") is None
    assert refs.expects_github("platform#400") is True, "unfetchable AND worth reporting"
    assert refs.expects_github("OPS-11") is False, "tracked, but none of a GitHub query's business"
    assert refs.expects_github("https://notion.so/scopes") is False


def test_e2a_property_6_slug_attribution_scopes_by_parse_and_never_by_prefix(tmp_path):
    """6/8 SLUG ATTRIBUTION, and the reason this tree crosses repositories in BOTH directions.

    `acme/platform` selects `auth-scopes` alone. `acme/warehouse` selects BOTH, because `auth-scopes`
    declares a warehouse ROW -- the case a manifest exists for, and the case a repository-local
    fixture cannot produce at all. `keypair-rotation`'s platform pointer is a `gate.blocked_by_ref`
    and not a row, so it does NOT drag that whole chain under the platform header: selection scopes
    on `row_refs`, and hosting another chain's blocker is not owning its work.

    THE PREFIX PAIR IS THE POINT, AND IT IS ASSERTED WHERE PREFIX LOGIC COULD ACTUALLY LIVE -- inside
    `core.select_for_repository`, not on `refs.ref_slug`, which is `parse_ref` plus a join and so
    cannot be caught out by a test that recomputes it the same way. `keypair-rotation` declares a row
    in `acme/plat`, a real slug that is a STRICT PREFIX of `acme/platform`, and that one row falsifies
    both directions of the confusion at once:

      - selecting `acme/plat` returns `keypair-rotation` ALONE. A matcher written
        `ref_slug(ref).startswith(slug)` would drag `auth-scopes` in with it, because every one of its
        platform rows begins `acme/plat`.
      - selecting `acme/platform` returns `auth-scopes` ALONE. A matcher written
        `slug.startswith(ref_slug(ref))` would drag `keypair-rotation` in, because `acme/platform`
        begins `acme/plat`. That assertion was already here and, until this row existed, no fixture in
        the tree could tell the two implementations apart -- it constrained nothing.

    NEGATIVES. `acme/pla` is a prefix of both real slugs and must select nothing; `acme/platform-web`
    has a real slug as ITS prefix and must select nothing; so must the empty slug, which is what
    `shell.repository_slug` returns for a repository with no GitHub origin -- it renders an empty grid
    rather than every manifest borg knows about. `ref_slug` itself is then pinned on HAND-WRITTEN
    values, including `acme/plat` carrying no `#number` at all, which is the assertion that separates
    a parse from `str(ref).split("#")[0]`. A derived loop used to stand where those pins are: it
    computed its expectation by calling `parse_ref` and joining the parts -- `ref_slug`'s own body,
    spelled a second time -- so it passed for every input by construction. Measured, not assumed:
    swapping that naive split into `ref_slug` left all fifteen cases in this section green.
    """
    manifests = _e2a_swept(tmp_path)
    by_id = _e2a_by_id(manifests)
    assert core.select_for_repository(manifests, "acme/platform") == [by_id["auth-scopes"]]
    assert core.select_for_repository(manifests, "acme/warehouse") == manifests
    assert core.select_for_repository(manifests, "acme/plat") == [by_id["keypair-rotation"]], "a prefix is not a slug"
    assert refs.ref_slug(_E2A_APEX["ref"]) == "acme/platform", "an apex still parses, it just never selects"
    assert refs.ref_slug("acme/plat#12") == "acme/plat", "the shorter slug is a slug, not a truncated one"
    assert refs.ref_slug("acme/plat") == "", "no `#number`, no ref, no slug -- ref_slug parses, it does not split"
    for absent in ("acme/pla", "acme/platform-web", "warehouse", ""):
        assert core.select_for_repository(manifests, absent) == [], absent


def test_e2a_property_7_coercion_exactness_edge_endpoints_are_declared_refs_verbatim(tmp_path):
    """7/8 COERCION EXACTNESS, asserted as an IDENTITY rather than as a rule: every endpoint of every
    derived edge is a member of `core.declared_refs`, character for character, per manifest and across
    the union.

    That identity is the entire reason `refs.text` is the ONE coercion in the package. A ref stripped
    on its way to an edge endpoint but not on its way to `declared_refs` would be TWO keys: the
    targeted fetch resolves one string while the graph indexes the other, and the edge disappears from
    the picture instead of raising.

    NEGATIVES, one per direction. Padding IS collapsed, and identically on both sides -- the padded
    string appears in neither list and the derived edge set is unchanged by the padding. Case is NOT
    collapsed: `Acme/Platform#400` stays a distinct declared ref rather than folding into the
    lowercase one. Folding would produce a ref matching no recon item, which `refs.parse_ref`'s dedup
    note is explicit about; the fix for a mis-cased ref is the author's, not the reader's.
    """
    manifests = _e2a_swept(tmp_path)
    by_id = _e2a_by_id(manifests)
    assert core.declared_refs(by_id["auth-scopes"]) == [
        "acme/platform#400",
        "acme/platform#420",
        "acme/platform#900",
        "acme/warehouse#87",
    ]
    # `acme/plat#12` sorts AHEAD of `acme/platform#400`, and the ordering is not a typo to correct:
    # `declared_refs` sorts the raw strings, the two share the prefix `acme/plat`, and the next byte
    # is `#` (0x23) against `f` (0x66). The prefix ref landing adjacent to the ref it is a prefix of
    # is exactly the neighbourhood a prefix bug hides in.
    assert core.declared_refs(by_id["keypair-rotation"]) == [
        "acme/plat#12",
        "acme/platform#400",
        "acme/warehouse#61",
        "acme/warehouse#64",
        "acme/warehouse#70",
    ]
    for manifest in manifests:
        declared = set(core.declared_refs(manifest))
        for edge in core.derive_edges(manifest):
            assert edge["parent"] in declared and edge["child"] in declared

    union = {ref for manifest in manifests for ref in core.declared_refs(manifest)}
    for edge in across.edges_from(manifests):
        assert edge["parent"] in union and edge["child"] in union

    padded = _e2a_platform_doc()
    padded["rows"][0]["ref"] = "  acme/platform#400  "
    assert refs.text(padded["rows"][0]["ref"]) == "acme/platform#400"
    assert "  acme/platform#400  " not in core.declared_refs(padded)
    assert core.derive_edges(padded) == core.derive_edges(_e2a_platform_doc()), "one coercion, both sides"

    folded = _e2a_platform_doc()
    folded["rows"].append(_row("4", "Acme/Platform#400"))
    assert core.validate(folded) == [], "a differently-cased ref is a different ref, not a duplicate"
    assert "Acme/Platform#400" in core.declared_refs(folded), "case is preserved, never folded"


def test_e2a_property_8_pointer_closure_every_non_row_pointer_is_a_full_ref(tmp_path):
    """8/8 POINTER CLOSURE over all three pointer channels, which this tree exercises together:
    `after`, `gate.blocked_by_ref` and `apex.ref`.

    Every one of them is an EDGE ENDPOINT. Prose in any of them produces an edge whose endpoint no
    state lookup can ever resolve, so the row leaves the ready set permanently while the fetch built
    from `declared_refs` goes looking for a sentence. A self-pointer is the mirror defect and is worse
    on the gate channel: `_blocks_edges` drops a self-edge, `unmapped_gates` skips any gate that
    carries a `blocked_by_ref` at all, and `ready_set` then sees a parentless row -- so an open
    decision is erased in three places at once and its row is announced READY.

    NEGATIVES, one per channel, each pinned by its own message: prose in `after`, a gate naming its
    own row, and a shorthand apex. The apex one is STRUCTURAL rather than row-scoped -- it describes a
    sibling key, so there is no subset of rows to keep -- which is why it costs the whole file.
    """
    manifests = _e2a_swept(tmp_path)
    pointers = []
    for manifest in manifests:
        apex = manifest.get("apex")
        if isinstance(apex, dict):
            pointers.append((apex["ref"], None))
        for row in manifest["rows"]:
            pointers += [(entry, row["ref"]) for entry in row.get("after", [])]
            gate = row.get("gate")
            if isinstance(gate, dict) and gate.get("blocked_by_ref"):
                pointers.append((gate["blocked_by_ref"], row["ref"]))
    assert len(pointers) == 4, "one apex, two `after` entries, one gate pointer -- all three channels"
    for pointer, own_ref in pointers:
        assert refs.parse_ref(pointer) is not None, pointer
        assert pointer != own_ref

    prose = _e2a_platform_doc()
    prose["rows"][1]["after"] = ["waiting on PR #400"]
    assert core.validate(prose) == ["rows[1]: after[0] must be a full ref (owner/repo#num), got waiting on PR #400"]

    self_gated = _e2a_warehouse_doc()
    self_gated["rows"][2]["gate"]["blocked_by_ref"] = "acme/warehouse#70"
    assert core.validate(self_gated) == ["rows[2]: gate.blocked_by_ref names its own ref acme/warehouse#70"]

    short_apex = _e2a_platform_doc()
    short_apex["apex"] = {"ref": "platform#900", "label": "auth scopes tracker"}
    assert core.validate(short_apex) == ["apex: ref must be a full ref (owner/repo#num), got platform#900"]


def test_e2a_the_authored_edge_count_across_the_tree_is_eight(tmp_path):
    """THE NUMBER IS DERIVED BY HAND, and the derivation is written out so a reader can check it
    rather than trust it.

    `auth-scopes`, subtotal 5: two `after` edges, #400 -> #420 and #400 -> warehouse#87, both kind
    `stacked`; the two LANE adjacencies are SUPPRESSED because both children appear in an `after`
    list (`core._stacked_edges`' override rule -- explicit parents REPLACE the lane's inference
    instead of adding to it, or an intra-lane fork silently renders as a straight line); three `apex`
    edges from #900 to each row.

    `keypair-rotation`, subtotal 3: two lane `stacked` adjacencies, #61 -> #64 and #64 -> #70; one
    `blocks` edge, platform#400 -> warehouse#70, from the gate. ITS FOURTH ROW CONTRIBUTES ZERO, and
    that is arranged rather than lucky: `acme/plat#12` (property 6's strict-prefix oracle) sits alone
    in a second lane, `_stacked_edges` zips consecutive rows WITHIN a lane so a lane of one emits no
    adjacency, and this manifest declares no apex so there is no per-row `apex` edge either. Adding
    it therefore left this subtotal at 3 and the union at 8, which is why the number below did not
    move; in `auth-scopes` the identical row would have cost +1 through `_apex_edges`.

    Nothing overlaps, so the union is 8 and the dedup on `(kind, parent, child)` collapses nothing.
    The harness's live `>= 14` floor is deliberately NOT inherited: a floor over whatever happens to
    be committed cannot tell a lost edge from a repository that was never swept.
    """
    manifests = _e2a_swept(tmp_path)
    by_id = _e2a_by_id(manifests)
    assert len(core.derive_edges(by_id["auth-scopes"])) == 5
    assert len(core.derive_edges(by_id["keypair-rotation"])) == 3

    edges = across.edges_from(manifests)
    assert len(edges) == 8
    assert sorted(e["kind"] for e in edges) == ["apex"] * 3 + ["blocks"] + ["stacked"] * 4
    triples = _e2a_triples(edges)
    assert triples == {
        ("stacked", "acme/platform#400", "acme/platform#420"),
        ("stacked", "acme/platform#400", "acme/warehouse#87"),
        ("apex", "acme/platform#900", "acme/platform#400"),
        ("apex", "acme/platform#900", "acme/platform#420"),
        ("apex", "acme/platform#900", "acme/warehouse#87"),
        ("stacked", "acme/warehouse#61", "acme/warehouse#64"),
        ("stacked", "acme/warehouse#64", "acme/warehouse#70"),
        ("blocks", "acme/platform#400", "acme/warehouse#70"),
    }
    # Named explicitly even though the set equality above already covers it: this absence IS the
    # override rule, and a reader scanning for it should not have to diff two eight-element sets.
    assert ("stacked", "acme/platform#420", "acme/warehouse#87") not in triples


def test_e2a_adding_one_row_to_the_warehouse_lane_makes_the_count_nine(tmp_path):
    """+1, and it is a LANE ADJACENCY: the new row sits at the tail behind #70, so the only edge that
    can appear is #70 -> #75. Nothing else about the tree moves.

    IT IS APPENDED AFTER THE PREFIX ROW AND STILL LANDS BEHIND #70, which is worth stating because
    the two facts look contradictory. `_row` gives it no `lane`, so `core.lanes` files it under
    `DEFAULT_LANE` alongside #61/#64/#70 and sorts it there by its `order` of 4; the prefix row lives
    in a lane of its own and, for as long as it is alone there, is never a neighbour of anything.

    WHICH IS WHY THE TRIPLE ASSERTION BELOW IS NOT REDUNDANT WITH THE COUNT. Give this row
    `lane="prefix"` instead and the prefix lane holds TWO rows, so `_stacked_edges` zips them and
    emits `acme/plat#12 -> acme/warehouse#75`. The total is STILL 9, `len(edges) == 9` still passes,
    and the only assertion that goes red is the triple -- measured by running exactly that mutation,
    not reasoned about. So a +1 case asserting the count alone would stay green for a tree whose new
    edge hangs off the wrong parent, which is the mistake this note exists to prevent.

    `_e2a_swept`'s clean-sweep assertion is load-bearing here rather than incidental. An added row the
    validator refused would be DROPPED from the manifest, the count would stay at 8, and this case
    would fail for the right number by the wrong route -- or, had the expectation been 8, pass while
    asserting nothing at all.
    """
    grown = _e2a_warehouse_doc()
    grown["rows"].append(_row("4", "acme/warehouse#75"))
    edges = across.edges_from(_e2a_swept(tmp_path, warehouse=grown))
    assert len(edges) == 9
    assert ("stacked", "acme/warehouse#70", "acme/warehouse#75") in _e2a_triples(edges)


def test_e2a_removing_the_warehouse_lane_head_makes_the_count_seven(tmp_path):
    """-1, and the row removed is chosen so the arithmetic is a single LANE ADJACENCY.

    #61 is the lane HEAD: dropping it removes #61 -> #64 and touches nothing else. Dropping the TAIL
    (#70) would cost TWO -- its adjacency and its gate's `blocks` edge -- and dropping the MIDDLE
    (#64) also lands on 7, but by a different route (two adjacencies removed, #61 -> #70 inferred in
    their place), which is a worse oracle because two errors there could cancel.

    `rows[1:]` is index arithmetic on the fixture, so note WHICH rows it keeps: #64, #70 and the
    prefix row, which is last in declaration order and rides along untouched. It emits no edge in
    either tree, so it neither adds to nor subtracts from this 7.
    """
    shortened = _e2a_warehouse_doc()
    shortened["rows"] = shortened["rows"][1:]
    edges = across.edges_from(_e2a_swept(tmp_path, warehouse=shortened))
    assert len(edges) == 7
    triples = _e2a_triples(edges)
    assert ("stacked", "acme/warehouse#64", "acme/warehouse#70") in triples
    assert ("blocks", "acme/platform#400", "acme/warehouse#70") in triples
    assert [t for t in triples if "acme/warehouse#61" in t] == [], "the head is gone from every edge"


def test_e2a_the_clean_tree_is_uncontested(tmp_path):
    """No ref is claimed by two chains, so `contested_refs` is empty.

    Note WHICH refs this is a claim about. `acme/platform#400` appears in BOTH manifests -- as a row
    in `auth-scopes` and as `keypair-rotation`'s `gate.blocked_by_ref` -- and that is not a contest:
    pointing at another chain's work is the cross-repository dependency a manifest exists to express.
    A `contested_refs` built over `declared_refs` instead of over rows would report this clean tree as
    contested, and would make the case below unfalsifiable.
    """
    assert across.contested_refs(_e2a_swept(tmp_path)) == []


def test_e2a_a_third_manifest_claiming_a_platform_row_is_exactly_one_contested_line(tmp_path):
    """The negative that moves the contested count 0 -> 1.

    `platform-audit` -- a third manifest, living in `warehouse` -- declares `acme/platform#400` as one
    of its OWN rows, a ref `auth-scopes` already declares. Two chains claiming one item is a
    declaration conflict for a human to settle, so it is REPORTED and never resolved: hiding it lets
    the loser's chain quietly lose a member.

    ONE line, not two: the intruder's other row (`acme/warehouse#99`) is its own.

    The exact sentence is deliberately NOT pinned here -- `across` owns its wording, and this file is
    not the place a second copy of that format becomes a contract. What is pinned is the ARITY and the
    ATTRIBUTION: one line, naming the contested ref and both claimants by id.
    """
    contested = across.contested_refs(_e2a_swept(tmp_path, intruder=True))
    assert len(contested) == 1, contested
    assert "acme/platform#400" in contested[0]
    assert "auth-scopes" in contested[0] and "platform-audit" in contested[0]
    assert "acme/warehouse#99" not in contested[0], "the shared ref is named, not every ref of a claimant"


def test_e2a_the_collision_is_still_reported_once_the_retired_program_key_is_gone(tmp_path):
    """THE TRIPWIRE, and it is aimed at a dated time bomb rather than at a hypothetical.

    merge-tree's `apply_program_projects` reads each manifest's top-level `program` key and SKIPS any
    manifest that does not carry one, while borg_core's loader stamps `_id` and is pinned never to
    invent `program` (see the declared-id case earlier in this file). So the day AC7 removes the last
    top-level `program` key, that implementation reports ZERO contested refs for a tree with a real
    collision in it -- green because the code stopped running. Measured last session by stripping the
    key from a tree with a collision injected; recorded as a comment in `evals/s4-k3/run.sh`, which
    is the surface that goes quietly green.

    The rewrite is REAL: the same three files, rewritten on disk without the key and rediscovered.
    Identity therefore has to come from `_id`, which falls back to the FILENAME STEM, and the
    collision has to outlive the key. The `program not in` assertion is the part that keeps this
    honest -- without it the case could pass against files that still carry the key.
    """
    keyed = _e2a_swept(tmp_path, intruder=True)
    assert all("program" in m for m in keyed), "precondition: the retired key is on disk to begin with"
    assert len(across.contested_refs(keyed)) == 1

    keyless = _e2a_swept(tmp_path, intruder=True, declared_ids=False)
    assert all("program" not in m for m in keyless), "the key is gone from every file"
    assert sorted(m["_id"] for m in keyless) == ["auth-scopes", "keypair-rotation", "platform-audit"]
    contested = across.contested_refs(keyless)
    assert len(contested) == 1, "identity comes from the loader's _id, so the collision outlives the key"
    assert "acme/platform#400" in contested[0]
    assert "auth-scopes" in contested[0] and "platform-audit" in contested[0]
