"""Build chains.json — the chain-map data model — from a gather doc + program manifests.

Usage:
  python3 build_chains.py <gather.json> <programs-dir> [<programs-dir> ...] [--out chains.json]

Portable: no hardcoded paths. <programs-dir> is any directory containing *.json manifests (e.g. the
committed docs/pr158-rider/manifests/, or a project's .borg/programs/). The committed chains.json in
this directory was produced from live recon data on 2026-08-20; render_chains_md.py on it reproduces
rendered/chains.md byte-for-byte, so the render step is runnable with no machine-local data.
"""

import glob
import json
import os
import sys

args = [a for a in sys.argv[1:] if a != "--out"]
out = "chains.json"
if "--out" in sys.argv:
    out = sys.argv[sys.argv.index("--out") + 1]
    args = [a for a in args if a != out]
if len(args) < 2:
    print(__doc__)
    raise SystemExit(1)

gather_path, program_dirs = args[0], args[1:]
g = json.load(open(gather_path))
items = {it["ref"]: it for it in g["items"]}

programs = []
chained_refs = set()
manifest_files = sorted(f for d in program_dirs for f in glob.glob(os.path.join(d, "*.json")))
for path in manifest_files:
    m = json.load(open(path))
    if not isinstance(m.get("rows"), list):
        continue
    lanes = {}
    for row in m["rows"]:
        lanes.setdefault(row.get("lane") or "main", []).append(row)
    out_lanes = []
    for lane, rows in lanes.items():
        nodes = []
        for row in rows:
            ref = row["ref"]
            it = items.get(ref, {})
            chained_refs.add(ref)
            state = it.get("state", "unknown")
            if state == "open" and "draft" in str(it.get("changed", "")):
                state = "draft"
            nodes.append(
                {
                    "ref": ref,
                    "short": ref.split("/")[-1],
                    "repo": ref.split("#")[0],
                    "order": row.get("order", ""),
                    "state": state,
                    "title": it.get("title", row.get("why", ""))[:80],
                    "url": "https://github.com/" + ref.replace("#", "/pull/"),
                    "next": bool(row.get("next")),
                    "gate": row.get("gate"),
                }
            )
        out_lanes.append({"lane": lane, "nodes": nodes})
    programs.append({"program": m["program"], "desc": m.get("desc", ""), "note": m.get("note", ""), "lanes": out_lanes})

unchained = []
for it in g["items"]:
    if it["state"] == "open" and it["ref"] not in chained_refs:
        state = "draft" if "draft" in str(it.get("changed", "")) else "open"
        unchained.append(
            {
                "ref": it["ref"],
                "short": it["ref"].split("/")[-1],
                "repo": it["ref"].split("#")[0],
                "state": state,
                "title": it["title"][:90],
                "url": "https://github.com/" + it["ref"].replace("#", "/pull/"),
                "project": it.get("project", ""),
            }
        )

data = {
    "generated_at": g["meta"]["gathered_at"],
    "programs": programs,
    "unchained": sorted(unchained, key=lambda x: x["ref"]),
    "provenance": g["meta"]["edge_provenance"],
    "open_total": len([i for i in g["items"] if i["state"] == "open"]),
}
json.dump(data, open(out, "w"), indent=1)
print(
    "wrote {}: {} programs, {} chained refs, {} unchained open".format(
        out, len(programs), len(chained_refs), len(unchained)
    )
)
