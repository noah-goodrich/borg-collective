"""Shared pytest fixtures for borg_core.

Autouse git identity, applied to every test in this tree (present and future) that shells to
`git commit`.
"""

from __future__ import annotations

import pytest


@pytest.fixture(autouse=True)
def _git_identity(monkeypatch):
    """Give every pytest run a git identity, the same way bats does.

    SAME BUG CLASS AS `tests/test_helper/setup.bash`'s "GIVE THE SANDBOX A GIT IDENTITY" fix
    (98264f3), but a DIFFERENT MECHANISM. bats redirects HOME, so `~/.gitconfig` is gone by
    construction. pytest does not redirect HOME at all — Noah's machine has a global
    `~/.gitconfig` that git falls back to, so `test_a_worktree_registered_beside_its_parent_loads_
    each_manifest_once` and `test_repository_slug_resolves_a_real_linked_worktree` (both in
    borg_core/manifest/test_shell.py, both of which shell to `git commit` to build a fixture
    worktree) pass locally and die on a fresh GitHub runner with `CalledProcessError` rc=128
    ("please tell me who you are") — the runner has no global identity to fall back to. Both are
    the same root cause: the dev environment silently supplies what CI doesn't.

    Same values as the bats harness (`borg tests` / `tests@borg.invalid`) so the two suites can
    never drift into disagreeing about what a "test git identity" is. `GIT_CONFIG_NOSYSTEM=1`
    closes the one hole neither HOME nor this fixture covers: the system gitconfig
    (/etc/gitconfig, /opt/homebrew/etc/gitconfig) is read regardless of the user's HOME.
    """
    monkeypatch.setenv("GIT_AUTHOR_NAME", "borg tests")
    monkeypatch.setenv("GIT_AUTHOR_EMAIL", "tests@borg.invalid")
    monkeypatch.setenv("GIT_COMMITTER_NAME", "borg tests")
    monkeypatch.setenv("GIT_COMMITTER_EMAIL", "tests@borg.invalid")
    monkeypatch.setenv("GIT_CONFIG_NOSYSTEM", "1")
