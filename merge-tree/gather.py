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
edges. `blocks` and `apex` edges are NOT derivable this way and remain unproduced — see
"Not derived here" below.

Run with:
  borg recon --json | python3 merge-tree/gather.py --out gather.raw.json
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from typing import Any

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
            edges.append({"parent": parent, "child": str(it["ref"]), "kind": "stacked"})
    return sorted(edges, key=lambda e: (e["child"], e["parent"]))


def assemble(reconciled: dict[str, Any]) -> dict[str, Any]:
    """Turn a reconciled recon document into the raw gather curate.py and spine.py consume."""
    items = flatten_items(reconciled)
    sources = reconciled.get("sources") or []
    repos = sorted({repo_of(it) for it in items if repo_of(it)})
    generated = str(reconciled.get("generated_at") or utc_now_iso())

    return {
        "meta": {
            "gathered_at": generated,
            "machine": os.environ.get("BORG_MACHINE", ""),
            "today": generated[:10],
            "repos": repos,
            # Carried through so the health panel keeps working: a source that failed must stay
            # visible rather than silently reducing the item count. Recon marks these `ok: false`.
            "health": [
                {
                    "check": f"recon:{s.get('source', '?')}",
                    "machine": os.environ.get("BORG_MACHINE", ""),
                    "status": "ok" if s.get("ok") else "down",
                    "detail": str(s.get("summary") or ""),
                    "checked_at": generated,
                }
                for s in sources
            ],
        },
        "items": items,
        "edges": derive_stacked_edges(items),
        # Not derived here — see the module docstring. `actions` are the renderer's command buttons
        # and are curation/judgment, not gathered facts.
        "actions": {},
    }


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--in", dest="src", default="-", help="recon --json document, or - for stdin")
    p.add_argument("--out", default=os.path.join(STATE, "gather.raw.json"))
    args = p.parse_args()

    try:
        raw = sys.stdin.read() if args.src == "-" else open(args.src).read()
        reconciled = json.loads(raw)
    except (OSError, ValueError) as exc:
        print(f"gather.py: cannot read a recon document: {exc}", file=sys.stderr)
        return 1

    gather = assemble(reconciled)
    with open(args.out, "w") as fh:
        json.dump(gather, fh, indent=2, sort_keys=True)
        fh.write("\n")

    down = [h["check"] for h in gather["meta"]["health"] if h["status"] != "ok"]
    print(
        f"wrote {args.out}: {len(gather['items'])} items, "
        f"{len(gather['edges'])} stacked edges, {len(gather['meta']['repos'])} repos"
    )
    if down:
        # A degraded source silently shrinking the item count is exactly the kind of plausible-wrong
        # output this session kept finding. Say it out loud.
        print(f"  DEGRADED SOURCES: {', '.join(down)}", file=sys.stderr)
    if not gather["edges"]:
        print("  no stacked edges derived — every workstream will be a singleton", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
