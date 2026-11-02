"""`python3 -m borg_core.evals.sweep.cli [--repo DIR] [--model ID]`: the weekly live eval sweep.

Runs the lifecycle-manifests model cases (one invocation) and the link-next cases (one invocation each, one run each)
against the build in the checkout, under a $10 sweep cap and a $1.50 per-case ceiling, then writes
`<state root>/evals/sweep-last.json` (contract: borg_core/evals/sweep/core.py). Harnesses append their own history
records; this driver appends a `skip` or `error` record for every case it did not or could not run.

ENVIRONMENT
    BORG_EVAL_SWEEP_MODEL   the pinned model id (default claude-opus-5-5; never the moving `opus` alias)
    BORG_CLAUDE_BIN         absolute path to claude (launchd's PATH omits ~/.local/bin)
    BORG_EVAL_HISTORY       the history file (default: the state root)
    BORG_USAGE_HALT_*       the usage guardian's switch and thresholds (see shell.guardian_halted)

EXIT: 0 when every case passed; 1 when any case skipped, errored or failed, or the sweep was halted. The summary file
is the record; the exit code only keeps a launchd log honest.
"""

from __future__ import annotations

import argparse
import os
import sys
import tempfile
import time
from pathlib import Path

from borg_core.evals.sweep import core, shell


def _parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="borg_core.evals.sweep.cli", description=__doc__.splitlines()[0])
    p.add_argument("--repo", help="the checkout to sweep (default: the one this module is in)")
    p.add_argument("--model", help="the pinned model id (default: $BORG_EVAL_SWEEP_MODEL, else claude-opus-5-5)")
    return p


def _whole_sweep(groups: list[core.Group], verdict: str, reason: str) -> list[dict]:
    rows: list[dict] = []
    for group in groups:
        rows.extend(
            core.skipped_rows(group, reason)
            if verdict == "skip"
            else [dict(r, verdict="error", reason=reason) for r in core.skipped_rows(group, reason)]
        )
    return rows


def _run_all(repo: Path, model: str, groups: list[core.Group], env: dict[str, str]) -> tuple[list[dict], float]:
    rows: list[dict] = []
    spent = 0.0
    started = env["BORG_SWEEP_STARTED"]
    for group in groups:
        run, reason = core.decide(group, spent)
        if not run:
            rows.extend(core.skipped_rows(group, reason))
            continue
        print(f"sweep: {group.harness} {','.join(group.cases)} (spent ${spent:.2f})", file=sys.stderr)
        shell.run_group(group, repo, model, env)
        records = shell.records_since(started)
        rows.extend(core.case_results(group, records))
        spent += core.group_spend(group, records)
    return rows, spent


def _execute(repo: Path, model: str, groups: list[core.Group], started: str) -> tuple[list[dict], str, float]:
    """(rows, halted reason, spend): the guardian check, the claude and plugin preconditions, then the groups."""
    if shell.guardian_halted(time.time()):
        halted = "usage guardian: new dispatch is halted (session usage at or over the halt threshold)"
        return _whole_sweep(groups, "skip", halted), halted, 0.0
    claude = shell.resolve_claude()
    if claude is None:
        return _whole_sweep(groups, "error", "claude CLI not found (set BORG_CLAUDE_BIN)"), "", 0.0
    env = {**os.environ, "BORG_SWEEP_STARTED": started, "BORG_CLAUDE_BIN": claude}
    env["PATH"] = f"{Path(claude).parent}{os.pathsep}{env.get('PATH', '')}"
    with tempfile.TemporaryDirectory(prefix="borg-sweep-plugin-") as scratch:
        plugin = Path(scratch) / "borg-collective"
        failure = shell.build_plugin(repo, plugin)
        if failure:
            return _whole_sweep(groups, "error", failure), "", 0.0
        env["EVAL_PLUGIN_DIR"] = str(plugin)
        rows, spent = _run_all(repo, model, groups, env)
    return rows, "", spent


def main(argv: list[str] | None = None) -> int:
    """Run one sweep and write its summary. See the module docstring."""
    args = _parser().parse_args(argv)
    repo = Path(args.repo).resolve() if args.repo else shell.repo_root()
    model = args.model or os.environ.get("BORG_EVAL_SWEEP_MODEL") or core.DEFAULT_MODEL
    started = shell.utc_now()
    sha = shell.git_sha(repo)
    rows, halted, spent = _execute(repo, model, core.plan_groups(shell.link_next_cases(repo)), started)
    # The driver's own rows (skips, errors it decided) go into the history; the harnesses wrote the rest.
    shell.append_records([r for r in rows if _driver_wrote(r, started)], sha, shell.utc_now())
    doc = core.summarize_sweep(
        started=started, ts=shell.utc_now(), git_sha=sha, model=model, spend_usd=spent, halted=halted, cases=rows
    )
    path = shell.write_summary(doc)
    print(
        f"sweep: {doc['counts']} spend ${doc['spend_usd']:.2f} of ${doc['cap_usd']:.2f}; summary {path}",
        file=sys.stderr,
    )
    return 1 if doc["needs_attention"] else 0


def _driver_wrote(row: dict, started: str) -> bool:
    """True for a row no harness recorded: a skip the budget or guardian decided, or a missing-record error."""
    records = shell.records_since(started)
    return not any(r["harness"] == row["harness"] and r["case"] == row["case"] for r in records)


if __name__ == "__main__":
    raise SystemExit(main())
