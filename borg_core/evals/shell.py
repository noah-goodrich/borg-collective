"""I/O for the eval ledger and selector: reading the tree, the ledger and git."""

from __future__ import annotations

import datetime
import json
import subprocess
from pathlib import Path

from borg_core.evals import core


def load_ledger(root: Path) -> dict:
    """Read the ledger; a missing or unparseable file is a ValueError naming it."""
    path = root / core.LEDGER_PATH
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot read {core.LEDGER_PATH}: {exc}") from exc
    if not isinstance(data, dict):
        raise ValueError(f"{core.LEDGER_PATH}: top level must be an object")
    return data


def today() -> str:
    """The real date as YYYY-MM-DD -- the one clock read, so `check` can be pinned by `--today`."""
    # JUSTIFICATION: stdlib date API is a two-step chain by design
    return datetime.date.today().isoformat()  # pylint: disable=clean-arch-demeter


def discover_items(root: Path) -> list[str]:
    """Every skill (`skills/*/SKILL.md`) and agent (`agents/*.md`) as `skills/<n>` / `agents/<n>`."""
    skills = [f"skills/{p.parent.name}" for p in (root / "skills").glob("*/SKILL.md")]
    agents = [f"agents/{p.stem}" for p in (root / "agents").glob("*.md")]
    return sorted(skills + agents)


def existing_evals(root: Path, names: list[str]) -> set[str]:
    """The subset of eval paths that carry a runnable `run.sh`."""
    return {n for n in names if (root / n / "run.sh").is_file()}


def _git(root: Path, *args: str) -> str:
    done = subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True, check=False)
    if done.returncode != 0:
        raise ValueError(f"git {' '.join(args)} failed: {done.stderr.strip()}")
    return done.stdout


def changed_files(root: Path, base: str | None, head: str) -> list[str]:
    """Files changed from `base` to `head`; `base` defaults to merge-base(origin/main, head)."""
    start = base if base else _git(root, "merge-base", "origin/main", head).strip()
    return [line for line in _git(root, "diff", "--name-only", "--no-renames", start, head).splitlines() if line]
