"""Tests for borg_core.link.worktree -- the pure half of the worktree page and the Queen board's grouping.

Every case names the mutation that turns it red: a check pointed at the wrong thing does not fail, it reads as
a pass.
"""

from __future__ import annotations

import ast
from pathlib import Path

from borg_core.link import worktree

MAIN = "/dev/borg"
COMMON = "/dev/borg/.git"
PAIRS = [("borg", "/dev/borg"), ("door", "/dev/borg-door"), ("elsewhere", "/dev/elsewhere")]


def test_own_source_is_the_one_entry_never_its_siblings():
    """MUTATION: return `core.repo_sources(...)` here and a worktree's page reads a sibling's checkpoints again --
    the 2026-10-13 report from borg-probes. Both entries share a `repo`, which is exactly the shape that made the
    union read leak."""
    repositories = {
        "borg": {"path": "/dev/borg", "repo": COMMON},
        "door": {"path": "/dev/borg-door", "repo": COMMON},
    }
    assert worktree.own_source("door", repositories) == [("door", "/dev/borg-door")]
    assert worktree.own_source("borg", repositories) == [("borg", "/dev/borg")]


def test_own_source_is_empty_without_a_path_or_an_entry():
    assert worktree.own_source("ghost", {}) == []
    assert worktree.own_source("p", {"p": {"path": None}}) == []
    assert worktree.own_source("p", {"p": None}) == []


def test_main_checkout_path_strips_only_a_dot_git_leaf():
    assert worktree.main_checkout_path(COMMON) == MAIN
    assert worktree.main_checkout_path("/srv/repo.git") == ""
    assert worktree.main_checkout_path("") == ""


def test_identity_names_a_main_checkout_a_worktree_and_a_plain_directory():
    checkout = worktree.identity(MAIN, "main", COMMON, PAIRS)
    assert checkout == {"kind": "checkout", "branch": "main", "worktree_of": ""}

    linked = worktree.identity("/dev/borg-door", "feat", COMMON, PAIRS)
    assert linked == {"kind": "worktree", "branch": "feat", "worktree_of": "borg"}

    plain = worktree.identity("/dev/elsewhere", "", "", PAIRS)
    assert plain == {"kind": "directory", "branch": "", "worktree_of": ""}


def test_identity_carries_a_detached_sha_only_when_there_is_one():
    """`detached` is ADDITIVE: absent from every identity read before it existed, so none of them changes shape.
    MUTATION: always emit the key and the exact-dict assertions above (and in test_shell) go red."""
    detached = worktree.identity("/dev/borg-door", "", COMMON, PAIRS, "8afb0b4")
    assert detached == {"kind": "worktree", "branch": "", "worktree_of": "borg", "detached": "8afb0b4"}
    assert "detached" not in worktree.identity("/dev/borg-door", "feat", COMMON, PAIRS)
    assert "detached" not in worktree.identity("/dev/borg-door", "", COMMON, PAIRS, "")


def test_identity_falls_back_to_the_main_checkouts_basename_when_it_is_not_registered():
    """MUTATION: return "" for the unregistered case and a worktree whose parent was never `borg add`ed reads as
    a worktree of nothing."""
    linked = worktree.identity("/dev/borg-door", "feat", COMMON, [("door", "/dev/borg-door")])
    assert linked["worktree_of"] == "borg"


def test_identity_reads_a_bare_repositorys_checkouts_as_worktrees():
    bare = worktree.identity("/dev/x", "b", "/srv/proj.git", [])
    assert bare == {"kind": "worktree", "branch": "b", "worktree_of": "proj"}


def test_scope_label_says_what_the_directory_is_to_its_repository():
    assert worktree.scope_label("door", {"kind": "worktree", "worktree_of": "borg"}) == "door — worktree of borg"
    assert worktree.scope_label("door", {"kind": "worktree", "worktree_of": ""}) == "door — worktree"
    assert worktree.scope_label("borg", {"kind": "checkout"}) == "borg — main checkout"
    assert worktree.scope_label("plain", {"kind": "directory"}) == "plain"
    assert worktree.scope_label("plain", {}) == "plain"


def test_repository_groups_collapse_worktrees_under_the_registered_main_checkout():
    """MUTATION: group by name only and each worktree is its own repository, which is the defect. The head is the
    entry registered AT the main checkout even though a worktree ranks first in `order`."""
    repositories = {
        "door": {"path": "/dev/borg-door", "repo": COMMON},
        "borg": {"path": "/dev/borg", "repo": COMMON},
        "probes": {"path": "/dev/borg-probes", "repo": COMMON},
        "solo": {"path": "/dev/solo"},
    }
    groups = worktree.repository_groups(["door", "solo", "borg", "probes"], repositories)
    assert groups == [("borg", ["door", "probes"]), ("solo", [])]


def test_repository_groups_sit_where_their_first_member_sits():
    """A waiting worktree must not sink because its repository is idle."""
    repositories = {
        "door": {"path": "/dev/borg-door", "repo": COMMON},
        "borg": {"path": "/dev/borg", "repo": COMMON},
        "solo": {"path": "/dev/solo"},
    }
    assert [head for head, _ in worktree.repository_groups(["solo", "door", "borg"], repositories)] == ["solo", "borg"]
    assert [head for head, _ in worktree.repository_groups(["door", "solo", "borg"], repositories)] == ["borg", "solo"]


def test_repository_groups_take_the_first_member_when_the_main_checkout_is_not_registered():
    repositories = {
        "a": {"path": "/dev/borg-a", "repo": COMMON},
        "b": {"path": "/dev/borg-b", "repo": COMMON},
    }
    assert worktree.repository_groups(["a", "b"], repositories) == [("a", ["b"])]


def test_a_registry_with_no_shared_repo_groups_to_itself():
    """Expand before contract: an entry written before `repo` existed is a group of one, so a pre-field registry
    renders exactly as it always did."""
    repositories = {"a": {"path": "/a"}, "b": {"path": "/b", "repo": None}, "c": {"path": "/c", "repo": ""}}
    assert worktree.repository_groups(["b", "a", "c"], repositories) == [("b", []), ("a", []), ("c", [])]


def test_two_independent_clones_are_two_repositories():
    repositories = {
        "one": {"path": "/dev/one", "repo": "/dev/one/.git"},
        "two": {"path": "/dev/two", "repo": "/dev/two/.git"},
    }
    assert worktree.repository_groups(["one", "two"], repositories) == [("one", []), ("two", [])]


def test_worktree_imports_nothing_but_the_future():
    """The module is on pyproject's Domain list by name. W9004's allow-list would wave a `pathlib` or `os`
    import through, so the exact root set is pinned here, by AST, the way test_render.py pins render.py."""
    tree = ast.parse(Path(worktree.__file__).read_text(encoding="utf-8"))
    roots = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            roots.update(alias.name.split(".")[0] for alias in node.names)
        elif isinstance(node, ast.ImportFrom):
            roots.add((node.module or "").split(".")[0])
    assert roots == {"__future__"}
