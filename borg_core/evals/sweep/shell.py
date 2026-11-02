"""The I/O half of the weekly eval sweep: claude resolution, the plugin build, harness subprocesses, the guardian
sample, the summary file. Decisions are borg_core/evals/sweep/core.py; this module only reads and runs things.

Unclassified under the clean-arch linter on purpose, like every `shell.py`.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from borg_core.evals import history
from borg_core.evals.sweep import core
from borg_core.paths import state_root

LIFECYCLE_TIMEOUT_SEC = 2 * 60 * 60
LINK_NEXT_TIMEOUT_SEC = 30 * 60
BUILD_TIMEOUT_SEC = 300


def utc_now() -> str:
    """ISO-8601 UTC at second resolution, the format history records use (so string compare orders them)."""
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def repo_root() -> Path:
    """The checkout this module runs from: the build under review."""
    return Path(__file__).resolve().parents[3]


def git_sha(repo: Path) -> str | None:
    """HEAD of `repo`, or None."""
    try:
        proc = subprocess.run(
            ["git", "-C", str(repo), "rev-parse", "HEAD"], capture_output=True, text=True, check=False
        )
    except OSError:
        return None
    return proc.stdout.strip() or None if proc.returncode == 0 else None


def link_next_cases(repo: Path) -> list[str]:
    """The link-next case names: one directory each under evals/link-next/cases."""
    root = repo / "evals" / "link-next" / "cases"
    return sorted(p.name for p in root.iterdir() if p.is_dir()) if root.is_dir() else []


def resolve_claude() -> str | None:
    """An ABSOLUTE path to claude, the way lib/borg/claude-bin.sh does: launchd's PATH omits ~/.local/bin."""
    override = os.environ.get("BORG_CLAUDE_BIN", "")
    if override.startswith("/") and os.access(override, os.X_OK) and not os.path.isdir(override):
        return override
    found = shutil.which("claude")
    if found and found.startswith("/"):
        return found
    default_dirs = f"{Path.home()}/.local/bin:/opt/homebrew/bin:/usr/local/bin"
    for directory in os.environ.get("BORG_CLAUDE_SEARCH_DIRS", default_dirs).split(":"):
        candidate = Path(directory) / "claude" if directory else None
        if candidate and candidate.is_file() and os.access(candidate, os.X_OK):
            return str(candidate)
    return None


def _int_env(name: str, default: int) -> int:
    raw = os.environ.get(name, "")
    return int(raw) if str.isdigit(raw) else default


def guardian_halted(now_epoch: float) -> bool:
    """Read the usage guardian's last sample the way the dispatch guard does (fail-open). The master switch
    BORG_USAGE_HALT_ENABLED defaults to ON here, not off like the hook: a paid sweep must not spend into a halted
    session, and a sweep that quietly ignored a switch nobody set would be the worse default."""
    samples = Path(os.environ.get("BORG_USAGE_SAMPLES") or (state_root() / "usage-samples.jsonl"))
    try:
        lines = samples.read_text(encoding="utf-8", errors="replace").splitlines()
        sample = json.loads(lines[-1]) if lines else {}
    except (OSError, ValueError):
        return False
    if not isinstance(sample, dict):
        return False
    age = None
    try:
        stamp = str(sample.get("ts", "")).split(".", maxsplit=1)[0].rstrip("Z") + "+00:00"
        age = int(now_epoch - datetime.fromisoformat(stamp).timestamp())
    except ValueError:
        age = None
    return core.guardian_halted(
        os.environ.get("BORG_USAGE_HALT_ENABLED", "1") == "1",
        str(sample.get("status", "")),
        sample.get("session_pct"),
        age,
        _int_env("BORG_USAGE_HALT_PCT", 92),
        _int_env("BORG_USAGE_HALT_TTL_SEC", 300),
    )


def build_plugin(repo: Path, dest: Path) -> str:
    """Build the plugin from `repo`'s source into `dest`. Returns "" on success, else the failure reason."""
    env = {**os.environ, "PLUGIN_DIR_OVERRIDE": str(dest)}
    try:
        proc = subprocess.run(
            ["bash", str(repo / "scripts" / "build-plugin.sh")],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            check=False,
            timeout=BUILD_TIMEOUT_SEC,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return f"plugin build failed: {exc}"
    if proc.returncode != 0:
        tail = (proc.stderr or proc.stdout).strip().splitlines()[-1:] or ["no output"]
        return f"plugin build exited {proc.returncode}: {tail[0]}"
    return ""


def harness_command(group: core.Group, repo: Path, model: str) -> tuple[list[str], dict[str, str], int]:
    """(argv, extra env, timeout) for one invocation. Lifecycle takes its model and cap from the environment,
    link-next from flags, and link-next runs ONE run per case: the history accumulates samples across weeks."""
    cap = f"{group.ceiling_usd:.2f}"
    if group.harness == core.LIFECYCLE_HARNESS:
        env = {"EVAL_MODEL": model, "EVAL_MAX_BUDGET_USD": cap}
        return ["bash", str(repo / "evals" / "lifecycle-manifests" / "run.sh")], env, LIFECYCLE_TIMEOUT_SEC
    argv = ["bash", str(repo / "evals" / "link-next" / "live.sh"), "--runs", "1", "--model", model]
    argv += ["--max-cost-usd", cap, "--case", group.cases[0]]
    return argv, {}, LINK_NEXT_TIMEOUT_SEC


def run_group(group: core.Group, repo: Path, model: str, env: dict[str, str]) -> int:
    """Run one invocation, output passed through to our own stdout and stderr. Returns the exit code (124: timeout)."""
    argv, extra, timeout = harness_command(group, repo, model)
    try:
        proc = subprocess.run(
            argv,
            cwd=repo,
            env={**env, **extra},
            check=False,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        print(f"sweep: {group.harness} {','.join(group.cases)} timed out after {timeout}s", file=sys.stderr)
        return 124
    except OSError as exc:
        print(f"sweep: could not start {group.harness}: {exc}", file=sys.stderr)
        return 127
    return proc.returncode


def records_since(started: str) -> list[dict[str, Any]]:
    """History records at or after `started`, in time order."""
    records, _bad = history.read_records()
    return [r for r in records if r["ts"] >= started]


def append_records(rows: list[dict[str, Any]], sha: str | None, ts: str) -> None:
    """Write the sweep's OWN rows (skips and errors it decided, not a harness) into the history."""
    for row in rows:
        history.append(
            history.make_record(row["harness"], row["case"], row["verdict"], reason=row["reason"], git_sha=sha, ts=ts)
        )


def summary_path() -> Path:
    """`<state root>/evals/sweep-last.json`."""
    return state_root() / "evals" / "sweep-last.json"


def write_summary(doc: dict[str, Any]) -> Path:
    """Replace sweep-last.json whole (temp file, then rename), so a reader never sees half a document."""
    target = summary_path()
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", dir=target.parent, delete=False, encoding="utf-8", suffix=".tmp") as handle:
        json.dump(doc, handle, indent=2, sort_keys=True)
        handle.write("\n")
    os.replace(handle.name, target)
    return target
