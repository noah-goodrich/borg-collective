"""Thin `subprocess` wrapper around `gh`. Argv lists only, never a shell string."""

from __future__ import annotations

import json
import subprocess

VIEW_FIELDS = "statusCheckRollup,headRefOid,mergeStateStatus,state,mergeCommit"


class GhError(RuntimeError):
    """`gh` could not be run or exited non-zero where the caller needed it to succeed."""


GH_TIMEOUT = 120.0


def run(argv: list[str]) -> tuple[int, str, str]:
    try:
        proc = subprocess.run(["gh", *argv], capture_output=True, text=True, check=False, timeout=GH_TIMEOUT)
    except subprocess.TimeoutExpired as exc:
        raise GhError(f"gh {' '.join(argv[:2])} timed out after {GH_TIMEOUT:g}s") from exc
    except OSError as exc:
        raise GhError(f"cannot run gh: {exc}") from exc
    return proc.returncode, proc.stdout, proc.stderr


def _repo(repo: str) -> list[str]:
    return ["--repo", repo] if repo else []


def view(n: int, repo: str = "") -> dict:
    rc, out, err = run(["pr", "view", str(n), "--json", VIEW_FIELDS, *_repo(repo)])
    if rc != 0:
        raise GhError(f"gh pr view {n} failed: {err.strip() or out.strip()}")
    try:
        doc: dict = json.loads(out)
    except ValueError as exc:
        raise GhError(f"gh pr view {n} returned non-JSON output") from exc
    return doc


def update_branch(n: int, repo: str = "") -> tuple[int, str]:
    rc, out, err = run(["pr", "update-branch", str(n), "--rebase", *_repo(repo)])
    return rc, (err or out).strip()


def rerun_failed(run_id: str, repo: str = "") -> tuple[int, str]:
    rc, out, err = run(["run", "rerun", run_id, "--failed", *_repo(repo)])
    return rc, (err or out).strip()


def merge(n: int, head: str, method: str = "squash", repo: str = "") -> tuple[int, str]:
    rc, out, err = run(
        ["pr", "merge", str(n), f"--{method}", "--delete-branch", "--match-head-commit", head, *_repo(repo)]
    )
    return rc, (err or out).strip()
