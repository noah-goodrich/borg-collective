"""Typer CLI entrypoint for `borg recon` (ports cmd_recon / _recon_print_digest in borg.zsh).

typer is imported LAZILY inside main() (Part 1 convention): importing this module for tests must
stay cheap and must not pull in the CLI framework at package-import time.
"""

from __future__ import annotations

import json as jsonlib
import os
import sys
import tempfile
from datetime import datetime, timezone

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
    by_project = core.merge_by_project(tracks)
    sources_json = core.build_sources_summary(tracks)
    contradictions = _collect_contradictions(projects, by_project)
    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
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

    registry_path = os.environ.get("BORG_REGISTRY", "")
    if not registry_path or not os.path.isfile(registry_path):
        _die(f"no registry at {registry_path}")

    projects_names = [p.strip() for p in projects_filter.split(",") if p.strip()] if projects_filter else None
    projects = shell.load_registry_projects(registry_path, projects_names)

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


def main() -> None:
    """Entrypoint for `python3 -m borg_core.recon.cli`. Imports typer lazily (Part 1 convention)."""
    # JUSTIFICATION: lazy import keeps importing this module for tests cheap (Part 1 convention).
    import typer  # pylint: disable=import-outside-toplevel

    app = typer.Typer(add_completion=False)

    @app.command()
    def recon(
        since: str = typer.Option("", "--since"),
        sources: str = typer.Option("", "--sources"),
        projects: str = typer.Option("", "--projects"),
        json_only: bool = typer.Option(False, "--json"),
        adapters: bool = typer.Option(False, "--adapters", "--list"),
    ) -> None:
        exit_code = _run(since, sources, projects, json_only, adapters)
        raise SystemExit(exit_code)

    app()


if __name__ == "__main__":
    main()
