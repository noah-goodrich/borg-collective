import json
import glob

S = "/private/tmp/claude-501/-Users-noah-dev-borg-collective/9efa4c28-5eee-4d82-8a1d-49b6b519ca20/scratchpad"
g = json.load(open(S + "/gather.live.json"))
items = {it["ref"]: it for it in g["items"]}

programs = []
chained_refs = set()
for path in sorted(glob.glob(S + "/poc/projects/*/.borg/programs/*.json")):
    m = json.load(open(path))
    lanes = {}
    for row in m["rows"]:
        lane = row.get("lane") or "main"
        lanes.setdefault(lane, []).append(row)
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
                "project": it["project"],
            }
        )

data = {
    "generated_at": g["meta"]["gathered_at"],
    "programs": programs,
    "unchained": sorted(unchained, key=lambda x: x["ref"]),
    "provenance": g["meta"]["edge_provenance"],
    "open_total": len([i for i in g["items"] if i["state"] == "open"]),
}
json.dump(data, open(S + "/chains.json", "w"), indent=1)
print("programs:", len(programs), "| unchained open:", len(unchained), "| chained refs:", len(chained_refs))
for p in programs:
    for L in p["lanes"]:
        print(" ", p["program"], "/", L["lane"], "->", len(L["nodes"]), "nodes")
