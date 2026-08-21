"""Render chains.json to the terminal: color, generous spacing, OSC-8 clickable refs (Ghostty).

Falls back gracefully: if the terminal ignores OSC 8, refs render as plain colored text and the
Links section at the bottom stays cmd-clickable.
"""

import json
import sys

SRC = sys.argv[1] if len(sys.argv) > 1 else "chains.json"
d = json.load(open(SRC))

R = "\033[0m"
BOLD = "\033[1m"
DIM = "\033[2m"
GREEN = "\033[32m"
VIOLET = "\033[35m"
GREY = "\033[90m"
RED = "\033[31m"
AMBER = "\033[33m"


def link(text, url):
    return "\033]8;;{}\033\\{}\033]8;;\033\\".format(url, text)


def state_tag(state):
    if state == "merged":
        return VIOLET + "done " + R
    if state == "open":
        return GREEN + BOLD + "OPEN " + R
    if state == "draft":
        return GREY + "draft" + R
    return state


def node_lines(n, indent="  "):
    out = []
    ref = BOLD + link(n["short"], n["url"]) + R
    nxt = AMBER + BOLD + " <-- NEXT" + R if n["next"] else ""
    out.append("{}{}  {}{}".format(indent, state_tag(n["state"]), ref, nxt))
    out.append("{}       {}".format(indent, DIM + n["title"] + R))
    if n.get("gate"):
        g = n["gate"]
        out.append("{}       {}GATE ({}): {}{}".format(indent, RED, g["kind"], g["blocked_by"], R))
        out.append("{}       {}unparked by: {}{}".format(indent, RED, g["resolved_by"], R))
    return out


print()
print(
    BOLD
    + "PR CHAINS"
    + R
    + DIM
    + "   merge order reads top to bottom   ·   generated "
    + d["generated_at"][:16].replace("T", " ")
    + R
)
print()
for p in d["programs"]:
    repos = sorted({n["repo"] for L in p["lanes"] for n in L["nodes"]})
    print(BOLD + AMBER + p["program"] + R + DIM + "   ({} repos)".format(len(repos)) + R)
    for L in p["lanes"]:
        print()
        print("  " + DIM + L["lane"] + " lane" + R)
        print()
        for i, n in enumerate(L["nodes"]):
            if i:
                print("  " + DIM + "   |" + R)
            for ln in node_lines(n):
                print(ln)
    print()
print(BOLD + "OPEN, IN NO CHAIN" + R + DIM + "   independent, any order" + R)
print()
for n in d["unchained"]:
    for ln in node_lines(n):
        print(ln)
    print()
