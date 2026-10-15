"""Pure logic for the worktree page and for the Queen board's grouping of worktrees under a repository.

SPLIT FROM core.py, which sat at 969 lines against pylint's 1000-line ceiling, and a split must never become
an escape from the Domain rules its functions would have sat under: this module is on pyproject's Domain list
by name, imports nothing outside `__future__`, and test_worktree.py walks its imports by AST.

VOCABULARY, fixed by the 2026-10-13 decision. A REPOSITORY is the git repo. A WORKTREE is a linked checkout
registered on its own, carrying a project of its own. A MAIN CHECKOUT is the directory that holds the repo's
`.git`. The registry's `repo` field is the absolute `--git-common-dir`, byte-identical from the main checkout
and from every linked worktree of it, so it is the one key that says "these entries are one repository".

THE RULE THIS MODULE EXISTS FOR: a page rendered for ONE directory reads ONE directory. `core.repo_sources`
(the union read across a repo group) answers "where did this repository's checkpoints go", which is the wrong
question for a page about a single checkout: it made a worktree's page show a sibling's latest checkpoint and
summary. `own_source` is the right answer for that page, and `repo_sources` stays for `borg next`, whose
repository-level dedupe is a different question.
"""

from __future__ import annotations

_GIT_SUFFIX = "/.git"


def own_source(name: str, repositories: dict) -> list[tuple[str, str]]:
    """The `(name, path)` pair for ONE registry entry alone, or `[]` when it has no path.

    The same shape `core.repo_sources` returns, so the checkpoint readers in `shell` take either; the
    difference is the whole point -- this never looks at a sibling, whatever the entry's `repo` says.
    """
    here = str(((repositories or {}).get(name) or {}).get("path") or "")
    return [(name, here)] if here else []


def main_checkout_path(common_dir: str) -> str:
    """The main checkout a `--git-common-dir` belongs to, or "" when it does not end in `/.git`.

    A bare repository's common dir has no `/.git` leaf, and every checkout of one is a linked worktree;
    "" says "no main checkout to name", which `identity` turns into that reading.
    """
    return common_dir[: -len(_GIT_SUFFIX)] if common_dir.endswith(_GIT_SUFFIX) else ""


def identity(
    path: str, branch: str, common_dir: str, resolved_paths: list[tuple[str, str]], detached: str = ""
) -> dict:
    """What a directory IS to git: `{kind, branch, worktree_of}`, `kind` one of worktree|checkout|directory.

    `path` and every path in `resolved_paths` arrive realpath-normalized (a filesystem act that cannot
    happen here), because `common_dir` is git's own physical answer and the comparison is between those.
    `directory` means git knows nothing about it (no common dir), and says nothing about a relationship.
    `worktree_of` names the registry entry that IS the main checkout, else the main checkout's basename.
    `detached` is the SHORT SHA of a detached HEAD and an ADDITIVE key: present only when non-empty, so every
    identity read before it existed is byte-identical, and `branch` stays a branch name or "".
    """
    base = _identity(path, branch, common_dir, resolved_paths)
    return {**base, "detached": detached} if detached else base


def _identity(path: str, branch: str, common_dir: str, resolved_paths: list[tuple[str, str]]) -> dict:
    """`identity` without the detached key: the relationship of a directory to its repository."""
    if not common_dir:
        return {"kind": "directory", "branch": branch, "worktree_of": ""}
    main = main_checkout_path(common_dir)
    if main and main == path:
        return {"kind": "checkout", "branch": branch, "worktree_of": ""}
    for name, resolved in resolved_paths:
        if main and resolved == main:
            return {"kind": "worktree", "branch": branch, "worktree_of": name}
    leaf = (main or common_dir).rstrip("/").rsplit("/", 1)[-1]
    return {"kind": "worktree", "branch": branch, "worktree_of": leaf.removesuffix(".git")}


def branch_text(ident: dict) -> str:
    """The `Branch:` row's value: the branch name, else `detached at <short sha>`, else "" (git did not state one)."""
    if ident.get("branch"):
        return str(ident["branch"])
    return f"detached at {ident['detached']}" if ident.get("detached") else ""


def scope_label(name: str, ident: dict) -> str:
    """The one-line scope label of a repository-scope page: the directory, and what it is to its repository."""
    kind = ident.get("kind")
    if kind == "worktree":
        parent = ident.get("worktree_of") or ""
        return f"{name} — worktree of {parent}" if parent else f"{name} — worktree"
    if kind == "checkout":
        return f"{name} — main checkout"
    return name


def _group_head(key: str, members: list[str], repositories: dict) -> str:
    """The member that IS the repository: the one registered at the main checkout, else the first."""
    main = main_checkout_path(key)
    for name in members:
        if main and str((repositories.get(name) or {}).get("path") or "").rstrip("/") == main:
            return name
    return members[0]


def repository_groups(order: list[str], repositories: dict) -> list[tuple[str, list[str]]]:
    """`[(head, [worktree, ...])]`: the Queen board's rows, one per REPOSITORY, in the board's own order.

    Entries sharing a non-empty registry `repo` collapse under one head, so a repository with three
    worktrees is one repository and not four. A group sits where its FIRST member sits in `order` (the
    board's sort is by status, and a waiting worktree should not sink because its repository is idle),
    and its worktrees keep `order`'s relative order. A missing or empty `repo` is a group of one, which is
    every entry written before the field existed -- expand before contract, no entry read by a rule it was
    not written under. With no shared `repo` anywhere the result is `[(name, []) for name in order]`.
    """
    members: dict[str, list[str]] = {}
    for name in order:
        key = str((repositories.get(name) or {}).get("repo") or "")
        if key:
            members.setdefault(key, []).append(name)
    groups: list[tuple[str, list[str]]] = []
    placed: set[str] = set()
    for name in order:
        key = str((repositories.get(name) or {}).get("repo") or "")
        if not key or len(members[key]) == 1:
            groups.append((name, []))
        elif key not in placed:
            placed.add(key)
            head = _group_head(key, members[key], repositories)
            groups.append((head, [other for other in members[key] if other != head]))
    return groups


def repository_parents(repositories: dict) -> dict[str, str]:
    """`{worktree: head}`: each worktree's repository, resolved through the registry `repo` key.

    THE ONE PLACE a worktree is mapped to its repository for ranking and for the board's destination suffix:
    the compass block is built with this map (`compass.core.map_repositories`), so `borg next` and the Queen
    board read one answer. It is `repository_groups` flattened, so it agrees with how the board groups rows; an
    entry that is a head, or has no `repo`, is absent from the result and stands for itself.
    """
    groups = repository_groups(list(repositories), repositories)
    return {child: head for head, children in groups for child in children}
