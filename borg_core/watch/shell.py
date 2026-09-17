"""The impure rungs of PR watching: the `gh` sweep, the snapshot file, and the tree comparison.

ONE BATCHED GraphQL CALL, not N REST calls, for the same reason `lib/recon/adapters/
recon-adapter-github` documents at length: this runs on a schedule, so per-PR calls multiply by
every poll forever. Reviews and comment counts come back in the same query as the PR list.
"""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

from borg_core import paths

SNAPSHOT_NAME = "pr-watch-snapshot.json"

# `reviewDecision` is the repository-level rollup GitHub computes; `comments.totalCount` covers
# issue-comments, which is what a cross-machine thread actually uses. Both are cheap in this query
# and neither is available from `gh pr list` without a second call per PR.
_QUERY = """
query($owner:String!, $name:String!) {
  repository(owner:$owner, name:$name) {
    pullRequests(states:OPEN, first:50, orderBy:{field:UPDATED_AT, direction:DESC}) {
      nodes {
        number title state reviewDecision
        author { login }
        headRefOid
        comments { totalCount }
      }
    }
    issues(states:OPEN, first:50, orderBy:{field:UPDATED_AT, direction:DESC}) {
      nodes {
        number title
        author { login }
        comments { totalCount }
      }
    }
  }
}
"""


def snapshot_path() -> Path:
    """Where the last sweep is stored. Under BORG_DIR so it shares the config surface."""
    return Path(paths.borg_dir()) / SNAPSHOT_NAME


def load_snapshot() -> dict:
    """The previous sweep, or `{}` when there is none or it is unreadable.

    An unreadable snapshot is treated as ABSENT rather than raising, which makes the next sweep a
    cold start -- silent by `core.diff`'s contract. That is the right failure: a corrupt file
    should cost one quiet cycle, not a flood of false "new PR" events.
    """
    try:
        data = json.loads(snapshot_path().read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    return data if isinstance(data, dict) else {}


def save_snapshot(snap: dict) -> None:
    """Atomic write: temp file then replace, mirroring the registry's own rule."""
    path = snapshot_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = Path(f"{path}.tmp")
    tmp.write_text(json.dumps(snap, indent=2), encoding="utf-8")
    tmp.replace(path)


def sweep(owner: str, name: str, timeout: int = 45) -> dict:
    """Current open-PR state via one GraphQL call. Returns `{}` when `gh` is unusable.

    DO NOT TREAT NON-ZERO EXIT AS TOTAL FAILURE -- `gh api graphql` exits 1 whenever the response
    carries an `errors` array, including partial successes, which is the trap the recon adapter
    documents. The payload is parsed regardless and only a missing `data` block is fatal.
    """
    try:
        proc = subprocess.run(
            ["gh", "api", "graphql", "-f", f"query={_QUERY}",
             "-F", f"owner={owner}", "-F", f"name={name}"],
            capture_output=True, text=True, timeout=timeout, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return {}
    try:
        payload = json.loads(proc.stdout or "{}")
    except ValueError:
        return {}
    repo = ((payload.get("data") or {}).get("repository") or {})
    nodes = (repo.get("pullRequests") or {}).get("nodes")
    if nodes is None:
        return {}
    prs = []
    for node in nodes:
        if not isinstance(node, dict):
            continue
        prs.append({
            "number": node.get("number"),
            "title": node.get("title") or "",
            "state": node.get("state") or "",
            "review_decision": node.get("reviewDecision") or "",
            "author": ((node.get("author") or {}).get("login")) or "",
            "head": node.get("headRefOid") or "",
            "comment_count": ((node.get("comments") or {}).get("totalCount")) or 0,
        })

    # ISSUES ARE SWEPT IN THE SAME CALL. They were missing entirely, and the gap was not academic:
    # a 9-comment coordination issue for a cross-machine PR control hub was being actively designed
    # on this repository while the watcher reported "quiet" for hours, because the query named
    # `pullRequests` and nothing else. One extra selection on a call already being made, so the cost
    # is a larger response rather than a second round trip.
    #
    # Issues carry NO head and NO tree, so nothing about them can reach the auto-post allowlist --
    # `core.decide` only ever acts on HEAD_MOVED, and its default is refusal. That is why issue
    # support needs no new guard: the allowlist was written to refuse by default rather than to
    # enumerate what it rejects.
    issues = []
    for node in (repo.get("issues") or {}).get("nodes") or []:
        if not isinstance(node, dict):
            continue
        issues.append({
            "number": node.get("number"),
            "title": node.get("title") or "",
            "author": ((node.get("author") or {}).get("login")) or "",
            "comment_count": ((node.get("comments") or {}).get("totalCount")) or 0,
        })
    return {"prs": prs, "issues": issues}


def trees_identical(repo: str, old_sha: str, new_sha: str) -> bool:
    """Do two commits have BYTE-IDENTICAL trees? The basis of an unattended re-stamp.

    A REAL TREE COMPARISON, not a proxy. `git diff --quiet <old> <new>` exits 0 only when no path
    differs; commit counts, diffstat totals and "same number of files" can all be preserved across
    a content change, and any of them standing in here would let a re-stamp carry a verdict onto
    code nobody reviewed. Returns False on ANY failure -- an unknown sha, a missing object after a
    force-push, no git at all -- because the permissive answer is the dangerous one.
    """
    if not old_sha or not new_sha or old_sha == new_sha:
        return False
    try:
        proc = subprocess.run(["git", "-C", repo, "diff", "--quiet", old_sha, new_sha],
                              capture_output=True, text=True, timeout=30, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return False
    return proc.returncode == 0


def comments(repo: str, number: int, timeout: int = 45) -> list:
    """Issue-comments on one PR as `[{author_association, body}]`; `[]` on any failure.

    `authorAssociation` is fetched from the API rather than inferred, because it is the filter that
    makes `core.prior_stamp` safe on a PUBLIC repository where anyone may comment. Returning `[]` on
    failure means a fetch error yields "no prior stamp", which refuses rather than permits.
    """
    try:
        proc = subprocess.run(
            ["gh", "pr", "view", str(number), "--repo", repo,
             "--json", "comments"],
            capture_output=True, text=True, timeout=timeout, check=False)
        payload = json.loads(proc.stdout or "{}")
    except (OSError, subprocess.TimeoutExpired, ValueError):
        return []
    out = []
    for item in payload.get("comments") or []:
        if isinstance(item, dict):
            out.append({"author_association": item.get("authorAssociation") or "",
                        "body": item.get("body") or ""})
    return out


def pr_state(repo: str, number: int, timeout: int = 30) -> str:
    """One PR's real state (`MERGED`/`CLOSED`/`OPEN`), or "" when it cannot be determined.

    Needed because the sweep queries `states:OPEN`, so a snapshot can never say whether a departed
    PR was merged or closed -- `core.diff` reports DEPARTED and this resolves it. One call, and only
    for PRs that actually left the open set, which is rare.
    """
    try:
        proc = subprocess.run(["gh", "pr", "view", str(number), "--repo", repo, "--json", "state"],
                              capture_output=True, text=True, timeout=timeout, check=False)
        return str(json.loads(proc.stdout or "{}").get("state") or "")
    except (OSError, subprocess.TimeoutExpired, ValueError):
        return ""
