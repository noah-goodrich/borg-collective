"""stdlib argparse CLI entrypoint for `borg recon` (ports cmd_recon / _recon_print_digest in borg.zsh).

Deliberately stdlib-only (no `typer`/`click`). `typer` was the original Part 1 convention, but it is
declared only in the `dev` dependency group (pyproject.toml), never provisioned at runtime by
install.sh, and `cmd_recon` in borg.zsh dispatches to this module unconditionally with no shell
fallback -- so a real (non-dev) install would hard-crash with ModuleNotFoundError. argparse ships
with every Python 3 interpreter, so this removes the unprovisioned runtime dependency entirely
rather than papering over it with an install-time pip step. See the migration ledger
(docs/plans/assimilated/2026-08-12-recon-migration-ledger.md) for the record of this deviation.
"""

from __future__ import annotations

import argparse
import json as jsonlib
import os
import sys
import tempfile

from borg_core import timefmt
from borg_core.recon import core, shell


def _die(message: str) -> None:
    """Print an error to stderr and exit non-zero, mirroring the zsh CLI's `die` helper."""
    print(f"borg recon: {message}", file=sys.stderr)
    raise SystemExit(1)


def _select_adapters(sources_filter: str) -> list[tuple[str, str]]:
    """Discover adapters and narrow to --sources, dying if none are found/matched."""
    adapters = shell.discover_adapters()
    if not adapters:
        _die(f"no recon adapters found on {shell.adapter_search_path()} — see 'borg recon --adapters'")
    if sources_filter:
        wanted = {s.strip() for s in sources_filter.split(",") if s.strip()}
        adapters = [(s, p) for s, p in adapters if s in wanted]
    if not adapters:
        _die(f"no adapters matched --sources '{sources_filter}'")
    return adapters


def _collect_contradictions(projects: dict, by_project: dict[str, list[dict]]) -> list[dict]:
    """Detect stale-blocker contradictions for every project with items and checkpoint blockers."""
    contradictions: list[dict] = []
    for project, project_info in projects.items():
        items = by_project.get(project, [])
        if not items:
            continue
        blockers = shell.read_checkpoint_blockers(project_info.get("path", ""))
        if not blockers:
            continue
        contradictions.extend(core.project_contradictions(project, blockers, items))
    return contradictions


def _filter_by_project(by_project: dict[str, list[dict]], keep_names: list[str] | None) -> dict[str, list[dict]]:
    """Make --projects authoritative even if an adapter over-returns items for other projects."""
    if not keep_names:
        return by_project
    keep = set(keep_names)
    return {k: v for k, v in by_project.items() if k in keep}


def _run_sweep(resolved_since: str, projects_file: str, adapters: list[tuple[str, str]], projects: dict) -> dict:
    """Run the fan-out + reconcile pipeline and assemble the reconciled doc."""
    tracks = shell.fanout(resolved_since, projects_file, adapters)
    tracks, source_contradictions = core.dedup_cross_source(tracks)
    by_project = core.merge_by_project(tracks)
    sources_json = core.build_sources_summary(tracks)
    contradictions = source_contradictions + _collect_contradictions(projects, by_project)
    generated_at = timefmt.now_iso()
    return core.assemble(resolved_since, generated_at, sources_json, by_project, contradictions)


def _sweep(since: str, sources_filter: str, projects: dict, projects_names: list[str] | None) -> dict:
    """Resolve `since`, select adapters, fan out, reconcile, persist the last-run marker."""
    project_dirs = [v.get("path", "") for v in projects.values() if v.get("path")]
    resolved_since = shell.resolve_since(since, project_dirs)
    adapters = _select_adapters(sources_filter)

    with tempfile.TemporaryDirectory(prefix="borg-recon.") as workdir:
        projects_file = os.path.join(workdir, "projects.json")
        shell.write_projects_file(projects, projects_file)
        doc = _run_sweep(resolved_since, projects_file, adapters, projects)
        doc["items_by_project"] = _filter_by_project(doc["items_by_project"], projects_names)
        shell.write_last_run_marker(resolved_since)

    return doc


def _run(
    since: str,
    sources_filter: str,
    projects_filter: str,
    json_only: bool,
    list_only: bool,
) -> int:
    """Dispatch one `borg recon` invocation; returns the process exit code."""
    if list_only:
        return _run_list_adapters()

    registry_file = str(shell.registry_path())
    if not os.path.isfile(registry_file):
        _die(f"no registry at {registry_file}")

    projects_names = [p.strip() for p in projects_filter.split(",") if p.strip()] if projects_filter else None
    projects = shell.load_registry_projects(registry_file, projects_names)

    doc = _sweep(since, sources_filter, projects, projects_names)

    if json_only:
        print(jsonlib.dumps(doc))
    else:
        print(core.render_digest(doc))
    return 0


def _run_list_adapters() -> int:
    """Handle --adapters/--list: print discovered sources, or how to add one."""
    adapters = shell.discover_adapters()
    if not adapters:
        print(f"No recon adapters found on: {shell.adapter_search_path()}")
        print("Drop an executable named 'recon-adapter-<source>' on that path to add a source.")
        return 0
    print("Available recon sources:")
    for source, path in adapters:
        print(f"  {source:<12} {path}")
    return 0


def _build_parser() -> argparse.ArgumentParser:
    """Build the stdlib argparse parser mirroring the zsh `cmd_recon` flag surface."""
    parser = argparse.ArgumentParser(
        prog="borg recon",
        description="Fan out across recon source adapters and reconcile against local checkpoints.",
    )
    parser.add_argument("--since", default="")
    parser.add_argument("--sources", default="")
    parser.add_argument("--projects", default="")
    parser.add_argument("--json", dest="json_only", action="store_true")
    parser.add_argument("--adapters", "--list", dest="adapters", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> None:
    """Entrypoint for `python3 -m borg_core.recon.cli`.

    stdlib argparse only -- see the module docstring for why this isn't typer/click.
    """
    args = _build_parser().parse_args(argv)
    exit_code = _run(args.since, args.sources, args.projects, args.json_only, args.adapters)
    raise SystemExit(exit_code)


if __name__ == "__main__":
    main()
