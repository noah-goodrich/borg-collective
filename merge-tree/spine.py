#!/usr/bin/env python3
"""spine.py — generate story.json's skeleton from a raw recon gather.

WHY THIS EXISTS. story.json — the cross-repo project/workstream spine the Story-Lens renders — had
NO GENERATOR. Nothing in the repo wrote it; render_graph.py only reads it, and neither SCHEMA.md nor
PROTOCOL.md documented its provenance. It was authored by hand in a session on 2026-07-28T16:15Z and
froze at that moment. Thirteen days later it had never heard of infrastructure#2564/#2566 — the exact
PRs an orchestrator session then spent 51 seconds of model time reconstructing by hand.

A stale spine is worse than no spine, because it looks authoritative: eight projects, 34 workstreams,
~426 items, 72 typed edges, and confident prose, with nothing on screen saying "this is a picture of
two weeks ago".

THE SPLIT. Two kinds of content live in story.json and they have completely different lifetimes:

  SKELETON (derivable, regenerated every run)   — project grouping, workstream membership,
                                                  blocked_by, per-workstream state, item refs
  JUDGMENT (not derivable, persisted in overlay) — project priority/name/summary,
                                                  workstream title/next_action

Regenerating must never destroy judgment. That is what the overlay file is for, and why it is keyed
by stable ids rather than by position.

SIBLING STAGE, NOT PART OF curate. Recorded deliberately, because viz-2's risk section warns that two
independent gather-consumers is how the render.py/render_graph.py divergence happened. curate.py maps
gather -> data.json (a per-ITEM projection: bucket + numeric urgency). This maps gather -> story.json
(a per-PROJECT structure). Different output, different shape, different consumer. Keeping them
separate means neither has to know the other's schema; the coupling they DO share is the raw gather,
which both read read-only.

Run with:
  python3 merge-tree/spine.py --gather <raw.json> --overlay <overlay.json> --out <story.json>
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from datetime import datetime, timezone
from typing import Any

STATE = os.environ.get("BORG_MERGE_TREE_DIR", os.path.expanduser("~/.local/state/borg/merge-tree"))

# Edges that mean "these items are one unit of work". `blocks` is deliberately NOT here: a blocking
# edge is a dependency BETWEEN workstreams, not evidence they are the same workstream. Conflating
# them would merge a blocker and its victim into one row and lose the dependency entirely.
CHAIN_KINDS = {"stacked", "apex"}
BLOCKING_KINDS = {"blocks"}

# Workstream state, derived from member item states. Order is precedence, not preference: a
# workstream with any blocked member is blocked regardless of what else is in it.
TERMINAL_STATES = {"MERGED", "CLOSED"}


def utc_now_iso() -> str:
    """Current UTC timestamp, ISO-8601 with a Z suffix (matches the rest of the spine).

    Deliberately NOT reusing borg_core.recon.core.epoch_to_iso: that takes an epoch, this takes
    nothing, and more importantly merge-tree/ and borg_core/ are separate programs with separate
    toolchains (see Makefile). borg_core is not an installed package, so importing across that
    boundary would need path manipulation to share two lines.
    """
    return datetime.now(tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def slugify(name: str) -> str:
    """Stable id from a human project name.

    The gather carries prose project names ("SFP - Keypair migration"); the spine keys projects by
    id. This is the mapping, and it must stay stable across runs or the overlay loses its anchor —
    so it is deliberately boring: lowercase, non-alphanumerics collapsed to single hyphens, trimmed.
    """
    return re.sub(r"-{2,}", "-", re.sub(r"[^a-z0-9]+", "-", str(name or "").lower())).strip("-")


def _components(refs: list[str], edges: list[dict[str, Any]]) -> list[list[str]]:
    """Group refs into connected components over chain edges (union-find, no recursion).

    Items sharing a stacked/apex edge are one workstream. Anything unconnected is its own
    single-item workstream — that is a real answer, not a degenerate one: a standalone PR IS a
    workstream of one.
    """
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
    # Sort members and groups so the output is byte-stable across runs — a spine that reorders on
    # every regeneration is undiffable, which defeats the point of generating it.
    return sorted((sorted(v) for v in groups.values()), key=lambda g: g[0])


def workstream_key(members: list[str]) -> str:
    """Stable overlay key for a workstream: its lexicographically smallest member ref.

    KNOWN LIMIT, stated rather than hidden: if that anchor item leaves the workstream, the key
    changes and this workstream's judgment (title, next_action) is orphaned rather than migrated.
    The alternative — hashing the full member set — is worse, because it changes when ANY member is
    added or removed, which happens constantly. Anchoring on one ref means judgment survives the
    common case (members join a chain) and is lost only in the rarer one (the anchor itself goes).
    Orphaned judgment is reported by find_orphans, not silently dropped.
    """
    # min(), not members[0]: callers inside this module happen to pass sorted lists, but a function
    # whose contract is "the smallest ref" must not silently depend on that.
    return min(members) if members else ""


def derive_state(members: list[str], by_ref: dict[str, dict[str, Any]]) -> str:
    """Workstream state from its members. Precedence, not preference — see TERMINAL_STATES."""
    items = [by_ref[r] for r in members if r in by_ref]
    if not items:
        return "pending"
    if any(it.get("blocked") for it in items):
        return "blocked"
    if all(str(it.get("state") or "").upper() in TERMINAL_STATES for it in items):
        return "done"
    if any(str(it.get("state") or "").upper() == "OPEN" for it in items):
        return "in-flight"
    return "pending"


def derive_blocked_by(members: list[str], edges: list[dict[str, Any]]) -> list[str]:
    """Refs that block any member of this workstream, via `blocks` edges. Sorted, deduplicated."""
    member_set = set(members)
    blockers = {
        e["parent"]
        for e in edges
        if e.get("kind") in BLOCKING_KINDS and e.get("child") in member_set and e.get("parent")
    }
    return sorted(blockers - member_set)


def generate_skeleton(gather: dict[str, Any]) -> dict[str, Any]:
    """Derive the spine skeleton — everything that does NOT require judgment."""
    items = [it for it in (gather.get("items") or []) if it.get("ref") and it.get("project")]
    edges = [e for e in (gather.get("edges") or []) if e.get("parent") and e.get("child")]
    by_ref = {it["ref"]: it for it in items}

    by_project: dict[str, list[dict[str, Any]]] = {}
    for it in items:
        by_project.setdefault(str(it["project"]), []).append(it)

    projects = []
    for name in sorted(by_project):
        proj_items = by_project[name]
        refs = sorted(it["ref"] for it in proj_items)
        workstreams = []
        for members in _components(refs, edges):
            workstreams.append(
                {
                    "key": workstream_key(members),
                    "state": derive_state(members, by_ref),
                    "blocked_by": derive_blocked_by(members, edges),
                    "items": members,
                }
            )
        projects.append(
            {
                "id": slugify(name),
                "gather_name": name,  # provenance: what the gather called it, before slugging
                "workstreams": workstreams,
            }
        )

    return {
        "meta": {
            # S3: the SKELETON's age. Judgment carries its own authored_at per field, because the
            # summary is simultaneously the highest-value and most perishable content in the spine —
            # a fresh skeleton wrapped around two-week-old prose must be detectable as such.
            "generated_at": utc_now_iso(),
            "gathered_at": (gather.get("meta") or {}).get("gathered_at", ""),
            "source": "spine.py",
        },
        "projects": projects,
    }


def apply_overlay(skeleton: dict[str, Any], overlay: dict[str, Any]) -> dict[str, Any]:
    """Merge persisted judgment onto a freshly derived skeleton.

    The skeleton always wins on structure; the overlay always wins on judgment. Neither can clobber
    the other, which is what makes regeneration safe to run at any time.
    """
    op = overlay.get("projects") or {}
    out = json.loads(json.dumps(skeleton))  # deep copy; skeleton stays pristine for callers

    for project in out["projects"]:
        pj = op.get(project["id"]) or {}
        project["name"] = pj.get("name") or project["gather_name"]
        project["priority"] = pj.get("priority")
        project["summary"] = pj.get("summary", "")
        project["summary_authored_at"] = pj.get("summary_authored_at", "")
        project["owner"] = pj.get("owner", "")
        wj = pj.get("workstreams") or {}
        for ws in project["workstreams"]:
            j = wj.get(ws["key"]) or {}
            ws["title"] = j.get("title", "")
            ws["next_action"] = j.get("next_action", "")
            ws["owner"] = j.get("owner", "")
            ws["title_authored_at"] = j.get("title_authored_at", "")

    # Unprioritised projects sort last but stay present and visible — dropping them would recreate
    # exactly the failure this directive exists to fix.
    out["projects"].sort(key=lambda p: (p.get("priority") is None, p.get("priority") or 0, p["id"]))
    return out


def find_orphans(skeleton: dict[str, Any], overlay: dict[str, Any]) -> dict[str, list[str]]:
    """Report structure with no judgment, and judgment with no structure.

    S5. Both directions matter and they fail differently:
      - unknown_projects / unknown_workstreams: NEW work the overlay has never seen. Silently
        rendering these with blank titles is how infrastructure#2564 stayed invisible.
      - stale_* : judgment whose anchor is gone (see workstream_key's known limit). Prose someone
        wrote that no longer attaches to anything — worth surfacing before it is lost.
    """
    op = overlay.get("projects") or {}
    skel_ids = {p["id"] for p in skeleton["projects"]}
    skel_ws = {(p["id"], ws["key"]) for p in skeleton["projects"] for ws in p["workstreams"]}

    unknown_projects = sorted(skel_ids - set(op))
    unknown_workstreams = sorted(
        f"{pid}/{key}"
        for (pid, key) in skel_ws
        if pid in op and key not in ((op[pid].get("workstreams") or {}))
    )
    stale_projects = sorted(set(op) - skel_ids)
    stale_workstreams = sorted(
        f"{pid}/{key}"
        for pid, pj in op.items()
        for key in (pj.get("workstreams") or {})
        if (pid, key) not in skel_ws
    )
    return {
        "unknown_projects": unknown_projects,
        "unknown_workstreams": unknown_workstreams,
        "stale_projects": stale_projects,
        "stale_workstreams": stale_workstreams,
    }


def _load(path: str, default: Any) -> Any:
    try:
        with open(path) as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return default


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--gather", default=os.path.join(STATE, "gather.raw.json"))
    p.add_argument("--overlay", default=os.path.join(STATE, "story.overlay.json"))
    p.add_argument("--out", default=os.path.join(STATE, "story.json"))
    args = p.parse_args()

    gather = _load(args.gather, None)
    if not gather:
        print(f"spine.py: cannot read a gather at {args.gather}", file=sys.stderr)
        return 1

    skeleton = generate_skeleton(gather)
    overlay = _load(args.overlay, {})
    spine = apply_overlay(skeleton, overlay)
    orphans = find_orphans(skeleton, overlay)

    with open(args.out, "w") as fh:
        json.dump(spine, fh, indent=2, sort_keys=True)
        fh.write("\n")

    n_ws = sum(len(pr["workstreams"]) for pr in spine["projects"])
    print(f"wrote {args.out}: {len(spine['projects'])} projects, {n_ws} workstreams")
    for label, refs in orphans.items():
        if refs:
            print(f"  {label}: {', '.join(refs)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
