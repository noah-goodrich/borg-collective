#!/usr/bin/env python3
"""backfill.py — recover declared edges from a historical data.json into borg-native manifests.

WHY THIS EXISTS. `programs.py` gives borg a place to declare cross-repo dependencies, but it starts
empty, and an empty declaration surface is the shape that failed four times before (CLAUDE.md,
Learned: cairn — four voluntary-write surfaces, one real row in five months). There is however already
a body of declared edges on disk: `~/.local/state/borg/merge-tree/data.json`, hand-curated in July,
carries 72 typed edges — 26 `apex`, 14 `blocks`, 32 `stacked` — across 430 items and 14 repos.

That is judgment somebody already did. This module converts it into manifests rather than asking for
it to be re-entered.

WHAT THE BACKFILL IS AND IS NOT WORTH. Measured on the real file: only **1 of 72** edges crosses a
repo boundary. So this does NOT conjure the rich cross-repo graph the viz program wants — it recovers
the 40 `apex`/`blocks` edges that no mechanical signal can derive, plus one genuine cross-repo
dependency. The remaining 32 `stacked` edges are re-derivable from branch topology for anything still
open, so their value is mostly historical.

Stated plainly because the alternative is a backfill that looks like a win and isn't.

GROUPING. Programs are connected components over CHAIN edges (`apex` + `stacked`) — the same rule
spine.py uses to build workstreams, for the same reason: those two kinds mean "one unit of work",
while `blocks` is a dependency between units and must not merge them. Each component becomes one
manifest. Within a component, `order` comes from a topological walk of the stacked chain, so the
declared merge sequence matches the recorded topology instead of being invented.

Run with:
  python3 merge-tree/backfill.py --data ~/.local/state/borg/merge-tree/data.json --out-dir <dir>
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from typing import Any

CHAIN_KINDS = {"stacked", "apex"}


def slugify(name: str) -> str:
    """Stable filename/program id from a project name. Mirrors spine.slugify deliberately.

    Not imported from spine.py: that module's copy anchors the OVERLAY's keys, and coupling a one-shot
    migration to it would mean a change here could silently re-key persisted judgment.
    """
    return re.sub(r"-{2,}", "-", re.sub(r"[^a-z0-9]+", "-", str(name or "").lower())).strip("-")


def components(refs: list[str], edges: list[dict[str, Any]]) -> list[list[str]]:
    """Group refs into connected components over chain edges only (union-find, no recursion)."""
    parent = {r: r for r in refs}

    def find(x: str) -> str:
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for e in edges:
        if e.get("kind") not in CHAIN_KINDS:
            continue
        a, b = e.get("parent"), e.get("child")
        if a in parent and b in parent:
            ra, rb = find(a), find(b)
            if ra != rb:
                parent[ra] = rb

    groups: dict[str, list[str]] = {}
    for r in refs:
        groups.setdefault(find(r), []).append(r)
    return sorted((sorted(v) for v in groups.values()), key=lambda g: g[0])


def chain_order(members: list[str], edges: list[dict[str, Any]]) -> list[str]:
    """Members in declared merge order: a topological walk of the `stacked` edges among them.

    Kahn's algorithm, with ties broken by ref so the result is byte-stable. A member in no stacked
    edge has no declared position and sorts after the chains, by ref — inventing an order for it would
    be a guess dressed as a declaration.
    """
    member_set = set(members)
    stacked = [
        e
        for e in edges
        if e.get("kind") == "stacked" and e.get("parent") in member_set and e.get("child") in member_set
    ]

    children: dict[str, list[str]] = {m: [] for m in members}
    indegree = {m: 0 for m in members}
    for e in stacked:
        children[e["parent"]].append(e["child"])
        indegree[e["child"]] += 1

    in_chain = {r for e in stacked for r in (e["parent"], e["child"])}
    ready = sorted(r for r in in_chain if indegree[r] == 0)
    ordered: list[str] = []

    while ready:
        node = ready.pop(0)
        ordered.append(node)
        for child in sorted(children[node]):
            indegree[child] -= 1
            if indegree[child] == 0:
                ready.append(child)
        ready.sort()

    # A cycle would leave members unvisited. Append them rather than dropping work on the floor.
    ordered += sorted(in_chain - set(ordered))
    return ordered + sorted(member_set - in_chain)


def apex_of(members: list[str], edges: list[dict[str, Any]]) -> str:
    """The component's apex: an `apex` edge parent that is not itself anyone's apex child.

    Returns "" when the component has none, which is a real answer — core rule 1's exception is a
    program small enough to need no tracker, and pointing at one that does not exist is worse.
    """
    member_set = set(members)
    parents = {
        e["parent"]
        for e in edges
        if e.get("kind") == "apex" and e.get("parent") in member_set
    }
    children = {
        e["child"] for e in edges if e.get("kind") == "apex" and e.get("child") in member_set
    }
    roots = sorted(parents - children)
    return roots[0] if roots else ""


def blockers_for(members: list[str], edges: list[dict[str, Any]]) -> dict[str, str]:
    """Map of member ref -> the ref that blocks it, from `blocks` edges. One blocker per row.

    The manifest carries at most one `blocked_by_ref` per row, so a row with several recorded blockers
    keeps the lexicographically smallest and the rest are reported as dropped by the caller — a silent
    truncation would misrepresent how blocked the work is.
    """
    found: dict[str, list[str]] = {}
    member_set = set(members)
    for e in edges:
        if e.get("kind") == "blocks" and e.get("child") in member_set and e.get("parent"):
            found.setdefault(str(e["child"]), []).append(str(e["parent"]))
    return {child: sorted(refs)[0] for child, refs in found.items()}


def dropped_blockers(members: list[str], edges: list[dict[str, Any]]) -> list[str]:
    """Blocks edges that cannot fit the one-blocker-per-row manifest shape."""
    found: dict[str, list[str]] = {}
    member_set = set(members)
    for e in edges:
        if e.get("kind") == "blocks" and e.get("child") in member_set and e.get("parent"):
            found.setdefault(str(e["child"]), []).append(str(e["parent"]))
    return sorted(
        f"{child} also blocked by {other}"
        for child, refs in found.items()
        for other in sorted(refs)[1:]
    )


def build_manifest(
    members: list[str],
    edges: list[dict[str, Any]],
    by_ref: dict[str, dict[str, Any]],
    program: str,
) -> dict[str, Any]:
    """One manifest for one component."""
    apex_ref = apex_of(members, edges)
    body = [m for m in chain_order(members, edges) if m != apex_ref]
    blockers = blockers_for(members, edges)

    rows = []
    position = 0
    for ref in body:
        item = by_ref.get(ref, {})
        state = str(item.get("state") or "").upper()
        merged = state == "MERGED"
        if not merged:
            # Numbering counts only rows that still have to merge, so a chain reads `–, 1, 2` rather
            # than `–, 2, 3`. Prerequisites are already done; they hold no position in what remains.
            position += 1
        row: dict[str, Any] = {
            # A MERGED item is a prerequisite, not a position in the remaining merge order — the same
            # meaning `–` carries in the format this shape mirrors.
            "order": "–" if merged else str(position),
            "ref": ref,
            "ticket": str(item.get("ticket") or ""),
            "status": "merged" if state == "MERGED" else "review",
        }
        if ref in blockers:
            row["status"] = "stacked"
            row["gate"] = {
                "blocked_by": f"depends on {blockers[ref]}",
                "blocked_by_ref": blockers[ref],
                "kind": "verification",
                "resolved_by": f"{blockers[ref]} merges",
            }
        rows.append(row)

    manifest: dict[str, Any] = {
        "program": program,
        "note": "Backfilled from the 2026-07-30 hand-curated data.json. Order reflects the recorded "
        "stacked topology; gates were synthesised from `blocks` edges and should be reviewed.",
        "rows": rows,
    }
    if apex_ref:
        manifest["apex"] = {"ref": apex_ref, "label": str(by_ref.get(apex_ref, {}).get("title") or "")}
    return manifest


def backfill(data: dict[str, Any]) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    """Convert a historical data.json into manifests. Returns `(manifests, stats)`."""
    items = [it for it in (data.get("items") or []) if it.get("ref")]
    edges = [e for e in (data.get("edges") or []) if e.get("parent") and e.get("child")]
    by_ref = {str(it["ref"]): it for it in items}

    # Only refs that actually participate in an edge are worth a manifest: a component of one with no
    # edges declares nothing that could not be derived.
    linked = sorted({str(r) for e in edges for r in (e["parent"], e["child"]) if str(r) in by_ref})

    manifests = []
    dropped: list[str] = []
    covered: set[str] = set()

    for members in components(linked, edges):
        if len(members) < 2:
            continue
        project = str(by_ref.get(members[0], {}).get("project") or "backfill")
        # Anchor on the number alone, not the whole ref: the repo is usually already in the project
        # name, and `data-eng-dags-data-eng-dags-65` reads as a bug even when it isn't.
        anchor = members[0].rsplit("#", 1)[-1]
        program = slugify(f"{project}-{anchor}")
        manifests.append(build_manifest(members, edges, by_ref, program))
        dropped += dropped_blockers(members, edges)
        covered |= set(members)

    # A `blocks` edge does NOT merge components (spine.py keeps it out of CHAIN_KINDS on purpose), so a
    # blocked item that is in no chain lands in a component of one and would be filtered out by the
    # rule above — silently discarding the edge. That is how the ONLY cross-repo edge in the source
    # data disappeared on the first run of this module. A blocked singleton gets its own one-row
    # manifest: a lone row carrying a gate still declares a real, non-derivable dependency.
    for child in sorted({str(e["child"]) for e in edges if e.get("kind") == "blocks"}):
        if child in covered or child not in by_ref:
            continue
        project = str(by_ref.get(child, {}).get("project") or "backfill")
        program = slugify(f"{project}-{child.rsplit('#', 1)[-1]}")
        manifests.append(build_manifest([child], edges, by_ref, program))
        dropped += dropped_blockers([child], edges)
        covered.add(child)

    def is_cross_repo(edge: dict[str, Any]) -> bool:
        return str(edge["parent"]).split("#")[0] != str(edge["child"]).split("#")[0]

    source_blocks = [e for e in edges if e.get("kind") == "blocks"]
    kept_blocks = {
        (str(r["gate"]["blocked_by_ref"]), str(r["ref"]))
        for m in manifests
        for r in m["rows"]
        if isinstance(r.get("gate"), dict) and r["gate"].get("blocked_by_ref")
    }

    stats = {
        "source_edges": len(edges),
        "source_items": len(items),
        "linked_refs": len(linked),
        "programs": len(manifests),
        "rows": sum(len(m["rows"]) for m in manifests),
        "cross_repo_source": len([e for e in edges if is_cross_repo(e)]),
        # Counted, not assumed. An earlier version of this module reported the SOURCE cross-repo count
        # as though it proved preservation, while the edge was in fact being dropped.
        "cross_repo_kept": len([p for p in kept_blocks if p[0].split("#")[0] != p[1].split("#")[0]]),
        "blocks_source": len(source_blocks),
        "blocks_kept": len(kept_blocks),
        "dropped_blockers": dropped,
    }
    return manifests, stats


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--data", required=True, help="historical data.json to mine")
    p.add_argument("--out-dir", required=True, help="directory to write <program>.json into")
    p.add_argument("--dry-run", action="store_true", help="report what would be written, write nothing")
    args = p.parse_args()

    try:
        with open(args.data) as fh:
            data = json.load(fh)
    except (OSError, ValueError) as exc:
        print(f"backfill.py: cannot read {args.data}: {exc}", file=sys.stderr)
        return 1

    manifests, stats = backfill(data)

    print(
        f"{stats['source_edges']} source edges over {stats['linked_refs']} linked refs "
        f"-> {stats['programs']} programs, {stats['rows']} rows"
    )
    print(
        f"  blocks edges: {stats['blocks_kept']} of {stats['blocks_source']} preserved  |  "
        f"cross-repo: {stats['cross_repo_kept']} of {stats['cross_repo_source']} preserved"
    )
    if stats["blocks_kept"] < stats["blocks_source"]:
        # Loud, because a dropped `blocks` edge is the single least recoverable thing here: it is pure
        # judgment, unlike `stacked`, which topology can re-derive for anything still open.
        print(
            f"  WARNING: {stats['blocks_source'] - stats['blocks_kept']} blocks edge(s) not "
            f"represented — see DROPPED lines above",
            file=sys.stderr,
        )
    for note in stats["dropped_blockers"]:
        # A row carries one blocker; extra ones must be named, never silently truncated.
        print(f"  DROPPED (one blocker per row): {note}", file=sys.stderr)

    if args.dry_run:
        for m in manifests:
            print(f"  DRY: would write {m['program']}.json ({len(m['rows'])} rows)")
        return 0

    os.makedirs(args.out_dir, exist_ok=True)
    for m in manifests:
        path = os.path.join(args.out_dir, f"{m['program']}.json")
        with open(path, "w") as fh:
            json.dump(m, fh, indent=2, sort_keys=True)
            fh.write("\n")
    print(f"wrote {len(manifests)} manifests to {args.out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
