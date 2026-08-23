"""Render chains.json as ONE topological grid per lane — linear chains are one-column DAGs.

Unified per Noah's call (2026-08-20): no separate rail treatment. Every program renders as a grid
picture (compact: glyph + node id + full ref, time flows down) with Node details blocks below.
Node ids appear EXACTLY twice — picture and detail heading — so vim `*` toggles picture <-> detail
with no plugin. Cross-references in details use full refs (self-addressing; `gp` opens the PR).

Forks (when a program declares them, via future row-level `after: [refs]`): additional columns in the
grid with box-drawing connectors, per the approved mock (chains-dag-mock.md). READY = open AND every
parent merged; all READY nodes are next simultaneously.
"""

import json
import sys

SRC = sys.argv[1] if len(sys.argv) > 1 else "chains.json"
OUT = sys.argv[2] if len(sys.argv) > 2 else "chains.md"

d = json.load(open(SRC))
STRIP = {"merged": "X", "open": "O", "draft": "o"}
GLYPH = {"merged": "v", "open": "*", "draft": "~"}

lines = []
w = lines.append
w("# PR chains — one grid, time flows down")
w("")
w("Generated {} · {} open PRs".format(d["generated_at"][:16].replace("T", " "), d["open_total"]))
w("Navigate:  `*` on a node id toggles picture <-> details.  `gp` on a full ref opens the PR.")
w("States:  v done   * ready/open   ~ draft   READY = every parent merged")
w("")
w("## At a glance   (one cell per PR; > marks next)")
w("")
for p in d["programs"]:
    for L in p["lanes"]:
        cells = [(">" if n["next"] else "") + STRIP.get(n["state"], "?") for n in L["nodes"]]
        nxt = next((n["ref"] for n in L["nodes"] if n["next"]), "")
        w("{:18} {:10} {:24} {}".format(p["program"][:18], L["lane"], " ".join(cells), nxt))
w("")

nid = 0
details = []
for p in d["programs"]:
    repos = sorted({n["repo"] for L in p["lanes"] for n in L["nodes"]})
    w("")
    w("## Program: {}".format(p["program"]))
    w("")
    if p.get("desc"):
        w(p["desc"])
        w("")
    w("Repos: {}".format("  ·  ".join(repos)))
    for L in p["lanes"]:
        w("")
        w("### {} lane".format(L["lane"]))
        w("")
        prev = None
        for i, n in enumerate(L["nodes"]):
            nid += 1
            n["_id"] = "n{}".format(nid)
            if i:
                w("    |")
            mark = "   <-- NEXT" if n["next"] else ""
            w("    {} {:4} {}{}".format(GLYPH.get(n["state"], "?"), n["_id"], n["ref"], mark))
            details.append((n, prev, L["nodes"][i + 1] if i + 1 < len(L["nodes"]) else None))
            prev = n

w("")
w("")
w("## Node details")
for n, prev, nxt in details:
    state = {
        "merged": "DONE",
        "open": "READY" if (prev is None or prev["state"] == "merged") else "WAITING",
        "draft": "DRAFT",
    }.get(n["state"], n["state"].upper())
    w("")
    w("### {} · {} — {}".format(n["_id"], n["ref"], state))
    w("    {}".format(n["title"]))
    if prev is None:
        w("    waits on: nothing — head of its lane")
    elif prev["state"] == "merged":
        w("    waits on: nothing — parent merged")
    else:
        w("    waits on: {}".format(prev["ref"]))
    if nxt is not None:
        w("    unlocks: {}".format(nxt["ref"]))
    if n.get("gate"):
        g = n["gate"]
        w("    GATE ({}): {}".format(g["kind"], g["blocked_by"]))
        w("    unparked by: {}".format(g["resolved_by"]))

w("")
w("## Open PRs in no chain (merge in any order)")
w("")
for n in d["unchained"]:
    w("    {} {}".format(GLYPH.get(n["state"], "?"), n["ref"]))
    w("         {}".format(n["title"]))
    w("")

open(OUT, "w").write("\n".join(lines))
print("wrote", OUT, "({} lines, {} nodes)".format(len(lines), nid))
