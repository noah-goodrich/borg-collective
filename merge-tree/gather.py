#!/usr/bin/env python3
"""gather.py — assemble a raw gather from `borg recon --json`.

WHY THIS EXISTS. `curate.py` and `spine.py` both consume a "raw gather" shape
(`{meta, items, edges, actions}`), and NOTHING PRODUCED IT. `merge-tree/fixtures/gather.raw.json`
was hand-written; `borg recon --json` emits a different, reconciled document
(`{since, generated_at, sources, items_by_project, contradictions}`). No command bridged the two, so
the whole viz pipeline — curate, the spine generator, the renderer — ran only on a frozen fixture.

This is that bridge:

    borg recon --json ──> gather.py ──> gather.raw.json ──┬──> curate.py ──> data.json
                                                          └──> spine.py  ──> story.json

EDGES ARE THE HARD PART, and the reason this is more than a reshape. The recon track contract is
`{source, summary, items}` — it has no concept of edges at all, so the fixture's 9 edges were
authored by hand. Without them every workstream in the generated spine is a singleton and every
`blocked_by` is empty, which makes the cross-repo chain view (the entire point of the viz program)
structurally impossible on real data.

`stacked` edges ARE derivable, from branch topology: a stacked PR's base branch is its parent's head
branch. The github adapter now emits `head_ref`/`base_ref` per item, and this module turns that into
edges. But a base branch is a REPO-LOCAL name, so every derived edge is repo-local by construction —
which means the cross-repo case, the entire point of the viz program, is not derivable at all.

Those come from borg's own program manifests (`programs.py`, `<project>/.borg/programs/*.json`) as
`declared` edges, unioned here. Every edge carries `source: "derived" | "declared"` so a wrong one is
falsifiable, and a declared order contradicting branch topology is reported rather than resolved.

Run with:
  borg recon --json | python3 merge-tree/gather.py --out gather.raw.json \\
      --programs-dir ~/dev/some-project --programs-dir ~/dev/another
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from typing import Any

import programs

STATE = os.environ.get("BORG_MERGE_TREE_DIR", os.path.expanduser("~/.local/state/borg/merge-tree"))


def utc_now_iso() -> str:
    """Current UTC timestamp, ISO-8601 with a Z suffix."""
    return datetime.now(tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def repo_of(item: dict[str, Any]) -> str:
    """The item's repo, preferring the adapter's explicit field and falling back to the ref.

    Refs are `repo#num`, so the prefix is the repo. The fallback matters for items from adapters
    that predate the `repo` field — an employer-injected Jira/Slack adapter, for instance, is a
    separate machine-local layer this repo never sees and cannot require a field from.
    """
    explicit = str(item.get("repo") or "").strip()
    if explicit:
        return explicit
    ref = str(item.get("ref") or "")
    return ref.split("#", 1)[0] if "#" in ref else ""


def flatten_items(reconciled: dict[str, Any]) -> list[dict[str, Any]]:
    """Flatten recon's `items_by_project` map into the flat `items[]` the gather contract wants.

    Sorted by ref so the output is byte-stable across runs — an undiffable gather defeats the point
    of generating it, the same reason spine.py sorts.
    """
    by_project = reconciled.get("items_by_project") or {}
    items: list[dict[str, Any]] = []
    for project_items in by_project.values():
        items.extend(it for it in (project_items or []) if it.get("ref"))
    return sorted(items, key=lambda it: str(it.get("ref") or ""))


def derive_stacked_edges(items: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Derive `stacked` edges from branch topology.

    A PR whose base branch is another PR's head branch is stacked on it. Scoped PER REPO: two
    unrelated repos both having a `main` or a `feature/foo` must not produce a spurious edge, and
    that would otherwise fire constantly since almost every PR targets `main`.

    Deliberately conservative — it emits an edge only when both sides are real, distinct PRs in the
    same repo. A base branch with no corresponding open PR (the overwhelmingly common case, `main`)
    produces nothing rather than a guess.
    """
    head_index: dict[tuple[str, str], str] = {}
    for it in items:
        head = str(it.get("head_ref") or "").strip()
        if head:
            # First writer wins, deterministically: items arrive ref-sorted, so a duplicated head
            # branch resolves the same way on every run rather than by dict iteration luck.
            head_index.setdefault((repo_of(it), head), str(it["ref"]))

    edges = []
    for it in items:
        base = str(it.get("base_ref") or "").strip()
        if not base:
            continue
        parent = head_index.get((repo_of(it), base))
        if parent and parent != it["ref"]:
            # `source` is provenance, not decoration: it is what makes a wrong edge falsifiable.
            # A `derived` edge is an inference from branch topology and can be stale (a rebase moves
            # a base branch); a `declared` edge is someone's stated intent. Telling them apart is the
            # difference between "the graph is wrong" and "the plan changed".
            edges.append({"parent": parent, "child": str(it["ref"]), "kind": "stacked", "source": "derived"})
    return sorted(edges, key=lambda e: (e["child"], e["parent"]))


def merge_edges(
    derived: list[dict[str, Any]], declared: list[dict[str, Any]]
) -> tuple[list[dict[str, Any]], int, list[str]]:
    """Union derived and declared edges. Returns `(edges, overlap_count, conflicts)`.

    DECLARED WINS a duplicate. Branch topology is an inference; a manifest row is the owner saying
    what the order *is*. When they agree the edge is simply corroborated (counted as overlap, not a
    problem).

    A CONFLICT is the interesting case: declared says A -> B while topology says B -> A. One of them
    is wrong — usually a rebase that moved a base branch out from under the plan, or a manifest that
    was never updated. Reported rather than silently resolved, because picking a winner here would
    hide exactly the drift the audit exists to surface.
    """
    by_key = {(e["kind"], e["parent"], e["child"]): e for e in derived}
    overlap = 0
    conflicts: list[str] = []

    for edge in declared:
        key = (edge["kind"], edge["parent"], edge["child"])
        reversed_key = (edge["kind"], edge["child"], edge["parent"])
        if key in by_key:
            overlap += 1
        elif reversed_key in by_key:
            conflicts.append(f"{edge['kind']}: declared {edge['parent']} -> {edge['child']}, topology says the reverse")
            del by_key[reversed_key]
        by_key[key] = edge

    return (
        sorted(by_key.values(), key=lambda e: (e["kind"], e["child"], e["parent"])),
        overlap,
        sorted(conflicts),
    )


def apply_program_projects(items: list[dict[str, Any]], manifests: list[dict[str, Any]]) -> tuple[int, list[str]]:
    """Re-key each manifest member's `project` to the program that declares it.

    Returns `(reassigned_count, contested)` — `contested` is one line per ref that more than one
    program claims. The FIRST manifest (discovery order, deterministic) keeps the ref; the collision
    is REPORTED, never silently resolved, same policy as merge_edges conflicts: two programs claiming
    one item is a declaration conflict for a human, and hiding it would let the loser's chain quietly
    lose a member.

    WHY THIS EXISTS. spine.py groups by `items[].project` BEFORE computing connected components, and
    recon keys `items_by_project` by REGISTERED PROJECT — one per repo. A declared edge that crosses
    repos therefore also crosses projects, and the spine severs the chain at the project boundary: the
    cross-repo case the manifest exists to express is exactly the case grouping destroys. Measured live
    (2026-08-20): the same declared 4-repo program renders as 0 cross-repo workstreams without this and
    2 with it.

    A program IS the project for the work it declares — that is what declaring it means — so the
    manifest's own `program` id is the grouping key for its members. Only members of a manifest are
    touched; every other item keeps the project recon gave it. Declared-away items therefore LEAVE
    their home project's grouping in every downstream view — deliberate: the program is where that
    work's story lives now, and the home project's remaining items still group under the home project.
    """
    by_ref: dict[str, str] = {}
    contested: list[str] = []
    for manifest in manifests:
        program = str(manifest.get("program") or "").strip()
        if not program:
            continue
        refs = [str(r.get("ref") or "").strip() for r in (manifest.get("rows") or []) if isinstance(r, dict)]
        apex = manifest.get("apex")
        apex_ref = str(apex.get("ref") or "").strip() if isinstance(apex, dict) else ""
        if apex_ref:
            refs.append(apex_ref)
        for ref in refs:
            if not ref:
                continue
            holder = by_ref.setdefault(ref, program)
            if holder != program:
                contested.append(f"{ref}: kept by {holder}, also claimed by {program}")

    reassigned = 0
    for item in items:
        program = by_ref.get(str(item.get("ref") or ""))
        if program and item.get("project") != program:
            item["project"] = program
            reassigned += 1
    return reassigned, sorted(contested)


def assemble(
    reconciled: dict[str, Any],
    declared_edges: list[dict[str, Any]] | None = None,
    manifests: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    """Turn a reconciled recon document into the raw gather curate.py and spine.py consume.

    `declared_edges` come from borg's program manifests (see programs.py) and carry the cross-repo
    dependencies branch topology cannot express — a base branch is a repo-local name, so every derived
    edge is repo-local by construction. `manifests` (the same discovery's output) re-key their members'
    `project` so the spine groups a declared program as one workstream instead of severing it per repo.
    """
    items = flatten_items(reconciled)
    programs_applied, program_contested = apply_program_projects(items, manifests or [])
    sources = reconciled.get("sources") or []
    repos = sorted({repo_of(it) for it in items if repo_of(it)})
    generated = str(reconciled.get("generated_at") or utc_now_iso())

    machine = os.environ.get("BORG_MACHINE", "")
    edges, overlap, conflicts = merge_edges(derive_stacked_edges(items), declared_edges or [])

    health = []
    for s in sources:
        dropped = int(s.get("dropped") or 0)
        status = "ok" if s.get("ok") else "down"
        detail = str(s.get("summary") or "")
        if s.get("ok") and dropped:
            # Recon's `ok` means the track RAN; items dropped as contract-invalid still leave it true.
            # A consumer reading "ok" as "this source's items are here" is wrong exactly when it
            # matters most: a source whose EVERY item was dropped has contributed nothing and must not
            # read as healthy. Partial drops degrade; total drops count as down.
            status = "warn" if int(s.get("count") or 0) else "down"
            detail = f"{detail} ({dropped} item(s) dropped as contract-invalid)"
        health.append(
            {
                "check": f"recon:{s.get('source', '?')}",
                "machine": machine,
                "status": status,
                "detail": detail,
                "checked_at": generated,
            }
        )
    if conflicts:
        # Reuse the existing health panel rather than inventing a surface: it exists precisely so a
        # degradation is visible at a glance instead of silently skewing the render.
        health.append(
            {
                "check": "edges:declared-vs-derived",
                "machine": machine,
                "status": "warn",
                "detail": "; ".join(conflicts),
                "checked_at": generated,
            }
        )
    if program_contested:
        # Same policy as edge conflicts: a ref claimed by two programs is a declaration conflict for a
        # human to settle. First manifest kept it (deterministic); the loser must not vanish silently.
        health.append(
            {
                "check": "programs:contested-refs",
                "machine": machine,
                "status": "warn",
                "detail": "; ".join(program_contested),
                "checked_at": generated,
            }
        )

    # Two sources reporting the same ref both flow through recon's merge today, and a duplicated item
    # inflates every downstream count (workstream sizes, READY sets) — measured live 2026-08-21 with a
    # second adapter: one PR rendered twice inside one workstream. Dedup belongs in recon (identity is
    # a source-merge concern); this counter is the guard that makes a bypass or regression visible here.
    seen: dict[str, int] = {}
    for it in items:
        ref = str(it.get("ref") or "")
        if ref:
            seen[ref] = seen.get(ref, 0) + 1
    duplicate_refs = sorted(r for r, n in seen.items() if n > 1)
    if duplicate_refs:
        health.append(
            {
                "check": "items:duplicate-refs",
                "machine": machine,
                "status": "warn",
                "detail": f"{len(duplicate_refs)} ref(s) appear more than once across sources: "
                + ", ".join(duplicate_refs[:5]),
                "checked_at": generated,
            }
        )

    # Endpoints that match no gathered item produce edges that vanish from the graph without raising.
    # Counting them is the guard against a silent normalization mismatch between a manifest's refs and
    # what the adapters actually emit.
    refs = {str(it.get("ref")) for it in items}
    dangling = sorted({ref for e in edges for ref in (e["parent"], e["child"]) if ref not in refs})

    return {
        "meta": {
            "gathered_at": generated,
            "machine": machine,
            "today": generated[:10],
            "repos": repos,
            # Carried through so the health panel keeps working: a source that failed must stay
            # visible rather than silently reducing the item count. Recon marks these `ok: false`.
            "health": health,
            # Countable, so a manifest whose refs match nothing is visible instead of silently inert.
            "program_regrouped_items": programs_applied,
            "program_contested_refs": program_contested,
            "edge_provenance": {
                "derived": len([e for e in edges if e.get("source") == "derived"]),
                "declared": len([e for e in edges if e.get("source") == "declared"]),
                "overlap": overlap,
                "conflicts": conflicts,
                "dangling_endpoints": dangling,
            },
        },
        "items": items,
        "edges": edges,
        # Not derived here — see the module docstring. `actions` are the renderer's command buttons
        # and are curation/judgment, not gathered facts.
        "actions": {},
    }


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--in", dest="src", default="-", help="recon --json document, or - for stdin")
    p.add_argument("--out", default=os.path.join(STATE, "gather.raw.json"))
    p.add_argument(
        "--programs-dir",
        action="append",
        default=[],
        metavar="PROJECT_DIR",
        help="project root to sweep for .borg/programs/*.json (repeatable). The caller resolves "
        "registered project paths; this module stays free of registry/config dependencies.",
    )
    args = p.parse_args()

    try:
        raw = sys.stdin.read() if args.src == "-" else open(args.src).read()
        reconciled = json.loads(raw)
    except (OSError, ValueError) as exc:
        print(f"gather.py: cannot read a recon document: {exc}", file=sys.stderr)
        return 1

    manifests, warnings = programs.discover(args.programs_dir)
    for warning in warnings:
        # Named, never silent: an unnamed skip is indistinguishable from a file that was never there.
        print(f"  MANIFEST SKIPPED {warning}", file=sys.stderr)

    gather = assemble(reconciled, programs.edges_from(manifests), manifests)
    with open(args.out, "w") as fh:
        json.dump(gather, fh, indent=2, sort_keys=True)
        fh.write("\n")

    down = [h["check"] for h in gather["meta"]["health"] if h["status"] != "ok"]
    prov = gather["meta"]["edge_provenance"]
    print(
        f"wrote {args.out}: {len(gather['items'])} items, "
        f"{len(gather['edges'])} edges ({prov['derived']} derived, {prov['declared']} declared), "
        f"{len(gather['meta']['repos'])} repos, {len(manifests)} programs"
    )
    if down:
        # A degraded source silently shrinking the item count is exactly the kind of plausible-wrong
        # output this session kept finding. Say it out loud.
        print(f"  DEGRADED SOURCES: {', '.join(down)}", file=sys.stderr)
    for conflict in prov["conflicts"]:
        print(f"  EDGE CONFLICT {conflict}", file=sys.stderr)
    for contested in gather["meta"]["program_contested_refs"]:
        # A ref two programs both declare. First manifest kept it; a human settles the claim.
        print(f"  CONTESTED REF {contested}", file=sys.stderr)
    if prov["dangling_endpoints"]:
        # These edges are in the graph but reference nothing gathered, so they render as nothing at
        # all. Silent disappearance is the failure mode; a count is the guard.
        print(
            f"  {len(prov['dangling_endpoints'])} edge endpoint(s) match no gathered item: "
            f"{', '.join(prov['dangling_endpoints'][:5])}",
            file=sys.stderr,
        )
    if not gather["edges"]:
        print("  no edges — every workstream will be a singleton", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
