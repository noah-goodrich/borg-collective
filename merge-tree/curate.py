#!/usr/bin/env python3
"""curate.py - the curation pass: raw recon gather -> ratified data.json.

The recon fan-out (borg#95) emits a *dumb*, source-agnostic gather: thin items
with a coarse STRING urgency ("now" | "this_week" | "fyi") and no bucket. All
judgement about numeric urgency and which of the four buckets an item belongs in
is concentrated here, in one re-runnable pass, so data.json stays a reproducible
projection (rerun curation, the assignments update; no re-gather needed). See
SCHEMA.md ("bucket and urgency are curation-derived, not adapter-emitted").

Raw gather shape (input):
  { meta:   {gathered_at, machine, today, repos[], health[]},
    items:  [ {ref, project, repo, source, title, state, changed, owner, url,
               one_line, urgency: "now"|"this_week"|"fyi", action_needed,
               is_entrypoint, blocked} ],
    edges:  [ {parent, child, kind} ],
    actions:{ "<ref>": {label, command, class} } }

Ratified output (data.json): identical shape EXCEPT every item carries a numeric
`urgency` and a `bucket` in {needs-you, active-chains, standalone, collapsed-noise}.

Run with:
  python3 merge-tree/curate.py --in gather.raw.json --out data.json
  python3 merge-tree/curate.py --in merge-tree/fixtures/gather.raw.json \\
      --out merge-tree/fixtures/data.golden.json   # regenerate the golden fixture
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import OrderedDict
from typing import Any

# Coarse string urgency -> numeric base. Entrypoints and blocked items get a
# small bump so the item that actually needs a hand sorts to the top of its band.
URGENCY_BASE = {"now": 88, "this_week": 55, "fyi": 30}
ENTRYPOINT_BUMP = 5
BLOCKED_BUMP = 5
URGENCY_CAP = 99
NOISE_STATES = {"MERGED", "CLOSED"}
VALID_STATUS = {"ok", "warn", "down"}

# The "awaiting you" tier. Its own bucket so it can render as a labelled section rather than being
# ranked against everything else — see docs/plans/directives/2026-08-11-viz-1-awaiting-you-tier.md.
#
# WHY THIS DERIVATION EXISTS AT ALL. render.py has referenced `bucket == "review-queue"` since
# 2026-07-30, but NOTHING EVER PRODUCED IT: bucket_for() returned only the four buckets below, and
# fixtures/data.golden.json contains zero such items. The eight in the machine-local data.json were
# hand-assigned and are dated 2026-07-27. So this tier has never been reproducible — it was curated
# data plus a renderer, and it silently emptied the moment anything regenerated. That is why
# sme-self-service-pat (three approved PRs behind one human merge gate) was never surfaced on
# 2026-08-10 despite the renderer nominally supporting the tier.
#
# The directive's stronger condition (open + reviewDecision==APPROVED + mergeable==MERGEABLE) is NOT
# yet derivable: recon-adapter-github fetches only number/title/state/isDraft/updatedAt/author/url,
# so review and mergeability are not gathered. This is the weaker condition that today's gather can
# actually support; tightening it is queued behind the adapter change (see viz-2).
NOAH_LOGINS = {"noah-goodrich", "noah goodrich", "noahgoodrich", "noah", "ngoodrich"}
REVIEW_BUCKET = "review-queue"


def is_noah(owner: Any) -> bool:
    """True when an item's owner login resolves to Noah, case/format-insensitively."""
    return str(owner or "").strip().lower() in NOAH_LOGINS


def awaits_you(item: dict[str, Any]) -> bool:
    """True when an item is open, needs a human action, and that human is Noah.

    Deliberately requires a NON-EMPTY action_needed rather than merely `open + mine`: in the golden
    fixture 6 of 13 items carry `action_needed: ""`, so dropping that clause would sweep every open
    PR Noah authored into the tier and reproduce the overload the tier exists to cut through.
    """
    return (
        str(item.get("state") or "").upper() == "OPEN"
        and bool(str(item.get("action_needed") or "").strip())
        and is_noah(item.get("owner"))
    )


def numeric_urgency(item: dict[str, Any]) -> int:
    """Map a coarse string urgency to a stable numeric score (capped)."""
    raw = item.get("urgency")
    if isinstance(raw, (int, float)):  # already curated / pass-through
        return int(raw)
    base = URGENCY_BASE.get(str(raw).lower(), URGENCY_BASE["fyi"])
    if item.get("is_entrypoint"):
        base += ENTRYPOINT_BUMP
    if item.get("blocked"):
        base += BLOCKED_BUMP
    return min(base, URGENCY_CAP)


def chain_refs(edges: list[dict[str, Any]]) -> set[str]:
    """Refs that participate in a stacked/apex chain (parent or child)."""
    refs: set[str] = set()
    for e in edges:
        if e.get("kind") in ("stacked", "apex"):
            for key in ("parent", "child"):
                if e.get(key):
                    refs.add(e[key])
    return refs


def bucket_for(item: dict[str, Any], in_chain: set[str]) -> str:
    """Assign one of the four ratified buckets, deterministically.

    Precedence: an item that needs Noah *now* is always surfaced; otherwise
    chain membership wins over raw state so merged-but-in-a-live-chain PRs stay
    with their chain; terminal states with no chain collapse to noise.
    """
    if str(item.get("urgency")).lower() == "now":
        return "needs-you"
    # Ranked BELOW needs-you deliberately: an item that is both urgent and awaiting Noah belongs in
    # the hero tier, not the review queue. Ranked ABOVE active-chains so a PR waiting on Noah is not
    # buried inside its chain — being blocked ON THE READER is the most actionable state there is,
    # which is exactly the inversion that hid sme-self-service-pat on 2026-08-10.
    if awaits_you(item):
        return REVIEW_BUCKET
    if item.get("ref") in in_chain:
        return "active-chains"
    if (item.get("state") or "").upper() in NOISE_STATES:
        return "collapsed-noise"
    return "standalone"


def normalize_health(health: list[dict[str, Any]] | None) -> list[dict[str, Any]]:
    """Coerce every health check to a tri-state status (default down if unknown)."""
    out = []
    for h in health or []:
        h = dict(h)
        status = str(h.get("status") or "down").lower()
        h["status"] = status if status in VALID_STATUS else "down"
        out.append(h)
    return out


def curate(raw: dict[str, Any]) -> dict[str, Any]:
    """Map a raw recon gather into the ratified data.json projection."""
    meta = dict(raw.get("meta") or {})
    meta["health"] = normalize_health(meta.get("health"))

    raw_items = [it for it in (raw.get("items") or []) if it.get("ref")]
    edges = [e for e in (raw.get("edges") or []) if e.get("parent") and e.get("child")]
    in_chain = chain_refs(edges)

    items = []
    for it in raw_items:
        cur = dict(it)
        cur["bucket"] = bucket_for(it, in_chain)
        cur["urgency"] = numeric_urgency(it)
        cur.setdefault("is_entrypoint", False)
        cur.setdefault("blocked", False)
        cur.setdefault("one_line", "")
        cur.setdefault("action_needed", "")
        items.append(cur)

    # Deterministic order (highest urgency first, then ref) so the golden
    # fixture is byte-stable and diffable across regenerations. render.py
    # re-buckets/re-sorts, so item order here is presentation-neutral.
    items.sort(key=lambda it: (-(it.get("urgency") or 0), it.get("ref", "")))

    ref_set = {it["ref"] for it in items}

    # Dedupe edges; keep any edge with at least one endpoint we know about
    # (apex headers legitimately point at a synthetic tracker ref).
    seen: set[tuple[str, str, str]] = set()
    clean_edges = []
    for e in edges:
        key = (e["parent"], e["child"], e.get("kind", ""))
        if key in seen:
            continue
        if e["parent"] in ref_set or e["child"] in ref_set:
            seen.add(key)
            edge = {"parent": e["parent"], "child": e["child"], "kind": e.get("kind", "stacked")}
            # Provenance survives curation (opus review finding 3 / PM5): stripping `source` here
            # meant it never reached data.json or the renderers, so a wrong edge was not falsifiable
            # downstream — the exact property the field exists to provide.
            if e.get("source"):
                edge["source"] = e["source"]
            clean_edges.append(edge)

    # Actions: keep only those addressed to a known item ref.
    actions = OrderedDict()
    for ref, act in (raw.get("actions") or {}).items():
        if ref in ref_set and isinstance(act, dict):
            actions[ref] = {
                "label": act.get("label", ""),
                "command": act.get("command", ""),
                "class": act.get("class", "readonly"),
            }

    return {"meta": meta, "items": items, "edges": clean_edges, "actions": actions}


def main() -> int:
    """CLI entrypoint: read a raw gather, curate it, write ratified data.json."""
    p = argparse.ArgumentParser(description="Curate a raw recon gather into ratified data.json.")
    p.add_argument("--in", dest="src", required=True, help="path to the raw gather JSON")
    p.add_argument("--out", dest="dst", required=True, help="path to write the curated data.json")
    args = p.parse_args()

    try:
        with open(args.src, encoding="utf-8") as f:
            raw = json.load(f)
    except (ValueError, OSError) as exc:
        return _fail(f"curate.py: cannot read gather at {args.src}: {exc}")

    data = curate(raw)

    try:
        with open(args.dst, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
            f.write("\n")
    except OSError as exc:
        return _fail(f"curate.py: cannot write {args.dst}: {exc}")

    counts: dict[str, int] = {}
    for it in data["items"]:
        counts[it["bucket"]] = counts.get(it["bucket"], 0) + 1
    print("wrote", args.dst)
    print("items:", len(data["items"]), "edges:", len(data["edges"]), "actions:", len(data["actions"]))
    print("per-bucket:", counts)
    return 0


def _fail(msg: str) -> int:
    print(msg, file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
