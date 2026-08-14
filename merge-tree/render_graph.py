#!/usr/bin/env python3
"""render_graph.py - the STORY GRAPH: an ownership-first, story-telling hub view.

Cards -> state-swimlanes -> isolate-DAG. This replaces the old node-link
"hairball" with the IA ratified in graph-ia-spec.md:

  L0  Project cards (default). ~8 Noah-OWNED projects in two labelled bands
      (NAMED / ALSO YOURS), each a status ribbon: 5-state meter + one NEXT
      ACTION command + a "blocked by ->" callout. NOT a graph -- you scroll.
  L1  One project -> a 4-column state board (Ready | In-flight | Blocked |
      Pending) + a shipped rail, with parallel-group rails and blocked_by prose.
  L2  One item -> a right slide-over with full detail (or a graceful stub for
      the ~20 refs with no data.json row) + an "Isolate chain" button.
  Isolate  The ONE node-link view: transitive closure of a single chain over
      the typed edges, deterministic layered layout, with drag-pan + wheel-zoom.

Primary source  <STATE>/story.json   (the curated project spine; ownership + state)
Enriched by     <STATE>/data.json    (per-item PR/issue/Jira detail; the join)
Overlaid by     <STATE>/annotations.local.json  (OPTIONAL, machine-local why/history)
Writes          <STATE>/graph.html   (self-contained; inline SVG + vanilla JS; no CDN)

STATE defaults to ~/.local/state/borg/merge-tree, overridable via BORG_MERGE_TREE_DIR.
--story/--data/--out/--annotations override the individual paths. python3 stdlib only.

Re-run with:
  BORG_MERGE_TREE_DIR=... python3 merge-tree/render_graph.py
"""

import argparse
import html
import json
import os

STATE = os.environ.get("BORG_MERGE_TREE_DIR", os.path.expanduser("~/.local/state/borg/merge-tree"))

# Projects Noah named in the brief (Password Deprecation umbrella = keypair +
# team-token; Self-Service Ingestion = snowpipe). Everything else is "also yours".
NAMED_IDS = ["keypair-migration", "sme-self-service-pat", "self-service-snowpipe"]
UMBRELLA_IDS = ["keypair-migration", "sme-self-service-pat"]
STATE_ORDER = ["ready-to-start", "in-flight", "blocked", "pending", "done"]

# Infoviz P1 (Cleveland-McGill): the L0 meter's LENGTH is a quantity encoding, so it has to be
# comparable across cards -- a 3-workstream project must not render the same width as a 12-workstream
# one. Meter width is therefore total/MAX_METER_TOTAL of the full-width track. The floor keeps
# single-workstream projects from collapsing to a sliver that its numeric labels (P2) float above
# with nothing underneath them; 0.25 is tuned by eye against the live story.json, not derived.
METER_MIN_WIDTH_FRAC = 0.25

# Same annotation whitelist as render.py: a provenance "source" must never
# clobber an item's own source (the source badge). Identity keys never merge.
ANNOTATION_MERGE_KEYS = {
    "note",
    "one_line",
    "action_needed",
    "blocked",
    "urgency",
    "owner",
    "title",
    "changed",
    "bucket",
    "is_entrypoint",
}


def parse_args():
    """Parse CLI args for the graph.html renderer."""
    parser = argparse.ArgumentParser(description="Render the story-first graph hub (graph.html).")
    parser.add_argument("--story", default=os.path.join(STATE, "story.json"), help="path to story.json")
    parser.add_argument("--data", default=os.path.join(STATE, "data.json"), help="path to data.json")
    parser.add_argument("--out", default=os.path.join(STATE, "graph.html"), help="path to write graph.html")
    parser.add_argument(
        "--annotations",
        default=os.path.join(STATE, "annotations.local.json"),
        help="path to the optional machine-local annotations file",
    )
    return parser.parse_args()


ARGS = parse_args()


def esc(s):
    """HTML-escape a value, treating None as an empty string."""
    return html.escape(str(s if s is not None else ""))


def safe_url(url):
    """http/https only; html.escape does not neutralize a javascript: scheme."""
    u = (url or "").strip()
    low = u.lower()
    return u if low.startswith("http://") or low.startswith("https://") else ""


def load_json(path, default):
    """Read a JSON file; return default on any read/parse failure (no traceback)."""
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except (ValueError, OSError):
        return default


def load_annotations(path):
    """Machine-local annotations map, or {} on any failure. Isolated so a future
    external annotation export can be unioned in here before apply_annotations sees it."""
    ann = load_json(path, {}) if os.path.exists(path) else {}
    return ann if isinstance(ann, dict) else {}


def apply_annotations(rows, ann):
    """Merge machine-local annotation overrides into each row, in place."""
    for it in rows:
        ov = ann.get(it.get("ref"))
        if isinstance(ov, dict):
            it.update({k: v for k, v in ov.items() if k in ANNOTATION_MERGE_KEYS})


# ---------------------------------------------------------------- load + join
story = load_json(ARGS.story, {"projects": []}) or {"projects": []}
D = load_json(ARGS.data, {}) or {}

meta = D.get("meta", {})
items = [it for it in D.get("items", []) if it.get("ref")]  # skip ref-less items
edges = [e for e in D.get("edges", []) if e.get("parent") and e.get("child")]
actions = D.get("actions", {}) or {}

apply_annotations(items, load_annotations(ARGS.annotations))
by_ref = {it["ref"]: it for it in items}
projects = story.get("projects", []) or []


def repo_of_ref(ref):
    """Best-effort repo name for a ref: joined item's repo, else parsed from the ref string."""
    it = by_ref.get(ref)
    if it and it.get("repo"):
        return it["repo"]
    if "#" in ref:
        return ref.split("#", 1)[0]
    if ref.startswith("DE-") or ref.startswith("DEV-"):
        return "jira"
    if " " in ref:
        return ref.split(" ", 1)[0]
    return ref


# ---------------------------------------------------------------- derived fields
def derive_workstream(ws):
    """Compute derived fields (counts, needs_you, awaiting_you, entry ref, max_urgency) on a workstream, in place."""
    wsitems = ws.get("items", []) or []
    ws["n_items"] = len(wsitems)
    ws["n_blocked_reasons"] = len(ws.get("blocked_by", []) or [])
    ws["needs_you"] = any((by_ref.get(r) or {}).get("bucket") == "needs-you" for r in wsitems)
    # viz-1: the awaiting-you tier. Mirrors needs_you exactly, one bucket over. curate.py assigns
    # "review-queue" to open items with a non-empty action_needed owned by Noah — i.e. blocked ON
    # THE READER, which is the most actionable state there is and the one that went unsurfaced on
    # 2026-08-10 because it was buried inside its chain.
    ws["awaiting_you"] = any((by_ref.get(r) or {}).get("bucket") == "review-queue" for r in wsitems)
    entry = next((r for r in wsitems if (by_ref.get(r) or {}).get("is_entrypoint")), None)
    if entry is None:
        entry = next((r for r in wsitems if r in actions), None)
    if entry is None and wsitems:
        entry = wsitems[0]
    ws["entry"] = entry
    urgs = [(by_ref[r].get("urgency") or 0) for r in wsitems if r in by_ref]
    ws["max_urgency"] = max(urgs) if urgs else 0


def hero_index(wss):
    """Index of the workstream to highlight: needs-you-and-in-flight first, else state priority order."""
    for i, ws in enumerate(wss):
        if ws.get("state") == "in-flight" and ws.get("needs_you"):
            return i
    for target in ("ready-to-start", "in-flight", "blocked", "pending"):
        for i, ws in enumerate(wss):
            if ws.get("state") == target:
                return i
    return 0 if wss else None


def derive_project(project):
    """Compute derived fields (meter, next_idx, repos, named, any_needs_you, any_awaiting_you) on a project, in place."""
    wss = project.get("workstreams", []) or []
    for ws in wss:
        derive_workstream(ws)
    project["meter"] = {s: 0 for s in STATE_ORDER}
    for ws in wss:
        if ws.get("state") in project["meter"]:
            project["meter"][ws["state"]] += 1
    project["meter_total"] = sum(project["meter"].values())
    project["next_idx"] = hero_index(wss)
    repos = set()
    for ws in wss:
        for r in ws.get("items", []) or []:
            repos.add(repo_of_ref(r))
    project["repos"] = sorted(repos)
    project["named"] = project.get("id") in NAMED_IDS
    project["any_needs_you"] = any(ws.get("needs_you") for ws in wss)
    project["any_awaiting_you"] = any(ws.get("awaiting_you") for ws in wss)


for p in projects:
    derive_project(p)

# Computed once here, not per card: meterHtml() runs for every rendered project, and rescanning all
# projects inside it would make L0 render O(n^2) for a value that never changes after this point.
MAX_METER_TOTAL = max((p["meter_total"] for p in projects), default=0)


# ---------------------------------------------------------------- baked payloads
def trimmed_item(it):
    """Flatten one item to the fields the client needs, plus its action block if any."""
    ref = it["ref"]
    act = actions.get(ref)
    return {
        "ref": ref,
        "title": it.get("title") or "",
        "project": it.get("project") or "",
        "repo": it.get("repo") or "",
        "source": it.get("source") or "",
        "state": it.get("state") or "",
        "bucket": it.get("bucket") or "",
        "owner": it.get("owner") or "",
        "url": safe_url(it.get("url")),
        "one_line": it.get("one_line") or "",
        "action_needed": it.get("action_needed") or "",
        "urgency": it.get("urgency"),
        "is_entrypoint": bool(it.get("is_entrypoint")),
        "blocked": bool(it.get("blocked")),
        "changed": it.get("changed") or "",
        "action": (
            {"label": act.get("label", ""), "command": act.get("command", ""), "class": act.get("class", "readonly")}
            if isinstance(act, dict)
            else None
        ),
    }


BYREF = {it["ref"]: trimmed_item(it) for it in items}
ACT = {
    r: {"label": a.get("label", ""), "command": a.get("command", ""), "class": a.get("class", "readonly")}
    for r, a in actions.items()
    if isinstance(a, dict)
}
EDGES = [{"parent": e["parent"], "child": e["child"], "kind": e.get("kind", "stacked")} for e in edges]
STORY = {"projects": projects, "meta": story.get("meta", {})}
META = {
    "today": meta.get("today", ""),
    "machine": meta.get("machine", ""),
    "repos": meta.get("repos", []),
    "health": meta.get("health", []),
}

CONSTS = (
    "const STORY=" + json.dumps(STORY, separators=(",", ":")) + ";\n"
    "const BYREF=" + json.dumps(BYREF, separators=(",", ":")) + ";\n"
    "const ACT=" + json.dumps(ACT, separators=(",", ":")) + ";\n"
    "const EDGES=" + json.dumps(EDGES, separators=(",", ":")) + ";\n"
    "const META=" + json.dumps(META, separators=(",", ":")) + ";\n"
    "const NAMED=" + json.dumps(NAMED_IDS) + ";\n"
    "const UMBRELLA=" + json.dumps(UMBRELLA_IDS) + ";\n"
    "const STATE_ORDER=" + json.dumps(STATE_ORDER) + ";\n"
    "const MAX_METER_TOTAL=" + json.dumps(MAX_METER_TOTAL) + ";\n"
    "const METER_MIN_WIDTH_FRAC=" + json.dumps(METER_MIN_WIDTH_FRAC) + ";\n"
)

CSS = """
:root{
  --bg:#0d1117; --panel:#161b22; --panel2:#0f141a; --bd:#30363d;
  --tx:#c9d1d9; --muted:#8b949e;
  --ready:#3fb950; --flight:#d29922; --blocked:#f85149; --blocked-soft:#a35b52; --pending:#8b949e;
  --done:#6e7681; --wip:#d29922; --you:#e3b341; --acc:#1f6feb; --red:#f85149;
  --merged:#6e7681; --you-glow:0 0 0 1px var(--you) inset,0 0 10px #e3b34155;
  --card:linear-gradient(180deg,#171d26,#12171f);
  --card-hi:linear-gradient(180deg,#1b2230,#141a23);
  --elev:0 1px 0 #ffffff08 inset, 0 2px 6px #00000060;
  --ring:0 0 0 1px var(--acc) inset;
  --pg1:#6ea8fe; --pg2:#4bc0b0; --pg3:#c08cf0; --pg4:#e08a5a; --pg5:#8bb26a;
}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--tx);
  font:14px/1.45 ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;padding:0 0 60px}
a{color:var(--acc);text-decoration:none} a:hover{text-decoration:underline}
header{position:sticky;top:0;z-index:30;background:linear-gradient(180deg,#0d1117,#0d1117f2);
  border-bottom:1px solid var(--bd);padding:12px 20px 8px;backdrop-filter:blur(6px)}
h1{font-size:15px;margin:0;letter-spacing:.5px}
h1 .sub{color:var(--muted);font-weight:400;font-size:11px;margin-left:10px}
.bar{display:flex;flex-wrap:wrap;gap:16px;align-items:flex-start;margin-top:8px}
.fgroup{display:flex;flex-wrap:wrap;gap:4px;align-items:center;max-width:640px}
.fgroup b{color:var(--muted);font-weight:400;margin-right:4px;font-size:11px;text-transform:uppercase;letter-spacing:.6px}
.fgroup.toggles{margin-left:auto}
.chip-f{cursor:pointer;padding:2px 9px;border-radius:11px;border:1px solid var(--bd);
  background:var(--panel);color:var(--muted);font-size:11px;transition:.12s ease}
.chip-f:hover{border-color:var(--acc)}
.chip-f.on{background:var(--acc);color:#fff;border-color:var(--acc)}
.tg{cursor:pointer;padding:3px 12px;border-radius:6px;border:1px solid var(--bd);
  background:var(--panel);color:var(--muted);font-size:12px}
.tg.on{background:var(--you);color:#000;border-color:var(--you)}
.crumbs{font-size:12px;color:var(--muted);margin:8px 0 2px}
.crumbs .cr{cursor:pointer;color:var(--acc)} .crumbs .cr:hover{text-decoration:underline}
.crumbs .sep{color:var(--muted);margin:0 6px}
main{max-width:1280px;margin:0 auto;padding:18px 20px}

/* ---- L0 bands + cards ---- */
.band{margin-bottom:26px}
.bandhdr{font-size:12px;font-weight:600;text-transform:uppercase;letter-spacing:.8px;
  color:var(--muted);border-bottom:1px solid var(--bd);padding-bottom:6px;margin-bottom:14px}
.bandsub{font-weight:400;text-transform:none;letter-spacing:0;margin-left:8px;opacity:.8}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(340px,1fr));gap:16px}
.umbrella{border-top:1px dashed var(--bd);padding-top:10px;margin-bottom:16px}
.umbrella .kicker{font-size:11px;text-transform:uppercase;letter-spacing:.9px;color:var(--you);margin-bottom:10px}
.pcard{background:var(--card);border:1px solid var(--bd);border-radius:10px;padding:14px;
  box-shadow:var(--elev);cursor:pointer;transition:.12s ease;display:flex;flex-direction:column;gap:8px}
.pcard:hover{background:var(--card-hi);transform:translateY(-1px);border-color:#3d4756}
.pcard.named{border-left:3px solid var(--acc)}
.pcard.needsyou{border:1px solid var(--you);border-left:4px solid var(--you);
  background:linear-gradient(180deg,#221c0e,#151007);box-shadow:var(--you-glow),var(--elev)}
.chead{display:flex;align-items:center;gap:8px}
.rank{font-size:11px;color:var(--muted);border:1px solid var(--bd);border-radius:6px;padding:0 6px}
.ptitle{font-size:15px;font-weight:600;flex:1;line-height:1.25}
.pip{color:#000;background:var(--you);border-radius:5px;padding:0 6px;font-weight:700;box-shadow:0 0 8px #e3b34166}
.crow{display:flex;flex-wrap:wrap;gap:5px;align-items:center}
.owner{color:var(--muted);font-size:11px;margin-right:2px}
.badge{font-size:10px;color:var(--muted);border:1px solid var(--bd);border-radius:4px;padding:0 5px;text-transform:lowercase}
.badge.muted{opacity:.7}
.summary{font-size:12px;color:var(--muted);display:-webkit-box;-webkit-line-clamp:2;
  -webkit-box-orient:vertical;overflow:hidden}
.meterlabs{display:flex;gap:8px;font-size:11px;height:14px}
.mlab{font-weight:600}
/* .metertrack is the full-width shared reference the proportional .meter is read against, so
   "how long is this bar" is a judgment against a common scale rather than against nothing. */
.metertrack{width:100%;height:10px;background:var(--bg);border-radius:5px}
.meter{display:flex;gap:2px;height:10px;background:var(--bg);border-radius:5px;overflow:hidden}
.mseg{min-width:3px;border-radius:0}
.mseg:first-child{border-radius:5px 0 0 5px} .mseg:last-child{border-radius:0 5px 5px 0}
.nextact{font-size:12px;color:var(--tx);margin-top:2px}
.nextact .tri{color:var(--ready);font-weight:700;margin-right:5px}
.blockedby{font-size:11px;color:var(--muted);border-left:2px solid var(--blocked-soft);
  padding-left:8px;margin-top:2px}
.blockedby .more{color:var(--muted)}
.cmd{margin-top:6px;display:flex;align-items:center;gap:8px;font-size:11px;cursor:copy}
.cmd code{background:var(--bg);border:1px solid var(--bd);border-radius:5px;padding:2px 7px;
  color:var(--tx);white-space:pre-wrap;word-break:break-all;flex:1}
.cmd-cls{font-size:9px;text-transform:uppercase;letter-spacing:.4px;border-radius:8px;padding:1px 6px;border:1px solid}
.cmd-readonly .cmd-cls{color:var(--ready);border-color:#1f3a26}
.cmd-confirm .cmd-cls{color:var(--you);border-color:var(--you)}

/* ---- L1 board ---- */
.board{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;align-items:start}
.col{background:var(--panel2);border:1px solid var(--bd);border-radius:8px;padding:10px;border-top:3px solid var(--bd);min-height:80px}
.col-ready{border-top-color:var(--ready)} .col-flight{border-top-color:var(--flight)}
.col-blocked{border-top-color:var(--blocked-soft)} .col-pending{border-top-color:var(--pending)}
.colhdr{font-size:12px;text-transform:uppercase;letter-spacing:.6px;color:var(--muted);margin-bottom:10px}
.colhdr .cc{float:right;opacity:.7}
.colempty{color:var(--muted);opacity:.35;text-align:center;font-size:22px;padding:12px 0}
.wscard{background:var(--card);border:1px solid var(--bd);border-radius:8px;padding:10px;margin-bottom:10px;
  box-shadow:var(--elev);transition:.12s ease}
.wscard.dim{opacity:.2}
.wshead{display:flex;align-items:center;gap:6px}
.wstitle{font-weight:600;font-size:13px;flex:1;line-height:1.25}
.pgtag{font-size:10px;color:var(--muted);border:1px solid var(--bd);border-radius:8px;padding:0 6px;white-space:nowrap}
.wsmeta{display:flex;gap:8px;align-items:center;margin:6px 0;color:var(--muted);font-size:11px}
.ownerchip{color:var(--muted)}
.nitems{opacity:.8}
.wsnext{font-size:11px;color:var(--tx);margin-bottom:8px}
.chips{display:flex;flex-wrap:wrap;gap:4px}
.ichip{font-size:11px;font-family:ui-monospace,Menlo,Consolas,monospace;color:var(--acc);
  background:var(--bg);border:1px solid var(--bd);border-radius:5px;padding:1px 6px;cursor:pointer}
.ichip:hover{border-color:var(--acc)}
.ichip.entry{box-shadow:0 0 0 1px var(--ready) inset}
.ichip.blk{border-left:3px solid var(--blocked-soft)}
.ichip.you{color:#000;background:var(--you);border-color:var(--you);font-weight:700}
.ichip.untracked{color:var(--muted);opacity:.75}
.waiting{margin-top:8px;border:1px solid var(--bd);border-radius:6px;padding:7px 8px;background:var(--panel2)}
.waiting b{display:block;font-size:10px;text-transform:uppercase;letter-spacing:.4px;color:var(--blocked-soft);margin-bottom:4px}
.wrow{font-size:11px;color:var(--tx);margin:2px 0}
.shiprail{margin-top:16px;border-top:1px dashed var(--bd);padding-top:8px;display:flex;flex-wrap:wrap;gap:8px;align-items:center}
.shiprail .rl{font-size:11px;text-transform:uppercase;letter-spacing:.5px;color:var(--muted);margin-right:6px}
.shipitem{font-size:11px;color:var(--merged);text-decoration:line-through;opacity:.6;border:1px solid var(--bd);border-radius:5px;padding:1px 7px}

/* ---- L2 slide-over ---- */
#overlay{position:fixed;inset:0;background:#000a;z-index:40;display:none}
#overlay.open{display:block}
#panel{position:fixed;top:0;right:0;bottom:0;width:360px;max-width:94vw;background:var(--panel2);
  border-left:1px solid var(--bd);box-shadow:var(--elev);z-index:50;overflow-y:auto;padding:16px;
  transform:translateX(100%);transition:transform .16s ease}
#panel.open{transform:translateX(0)}
#panel h3{margin:0 0 10px;font-size:14px;color:var(--acc)}
.pclose{position:absolute;top:10px;right:14px;cursor:pointer;color:var(--muted);font-size:16px}
.pclose:hover{color:var(--tx)}
#panel .row{margin:9px 0;font-size:12px}
#panel .row b{color:var(--muted);display:block;font-size:10px;text-transform:uppercase;letter-spacing:.4px;margin-bottom:2px}
.badges{display:flex;gap:6px;flex-wrap:wrap;margin:8px 0}
.schip{font-size:10px;text-transform:uppercase;letter-spacing:.4px;padding:1px 7px;border-radius:10px;border:1px solid}
.schip-open{color:var(--tx);border-color:var(--bd)}
.schip-blocked{color:var(--blocked-soft);border-color:var(--blocked-soft)}
.schip-merged{color:var(--merged);border-color:var(--merged)}
.schip-wip{color:var(--wip);border-color:var(--wip)}
.mono{font-family:ui-monospace,Menlo,Consolas,monospace}
.erow{font-size:11px;margin:3px 0}
.ekind{display:inline-block;min-width:56px;color:var(--muted)}
.erow-blocks .ekind{color:var(--blocked)}
.erow-apex .ekind{color:var(--acc)}
.eref{cursor:pointer;color:var(--acc)} .eref:hover{text-decoration:underline}
.isorow{margin-top:14px}
.btn{cursor:pointer;padding:5px 12px;border-radius:6px;border:1px solid var(--acc);
  background:transparent;color:var(--acc);font:12px ui-monospace,Menlo,monospace}
.btn:hover{background:var(--acc);color:#fff}

/* ---- isolate canvas ---- */
#isoWrap{position:fixed;inset:0;z-index:60;background:#0a0d12f2;display:none;flex-direction:column}
#isoWrap.open{display:flex}
#isoBar{display:flex;align-items:center;gap:14px;padding:10px 18px;border-bottom:1px solid var(--bd);
  background:var(--panel);z-index:2}
#isoTitle{font-weight:600}
.isohint{color:var(--muted);font-size:11px}
#isoBar .btn{margin-left:0}
#isoBar .spacer{flex:1}
#isoStage{flex:1;width:100%;cursor:grab;touch-action:none;background:
  radial-gradient(circle at 1px 1px,#ffffff0a 1px,transparent 0);background-size:26px 26px}
/* P6: animate the level/zoom jumps (reuse the panel's .16s ease); bypass while
   actively drag-panning so the pan stays 1:1 with the cursor. */
#camG{transition:transform .16s ease}
#camG.panning{transition:none}
.gn rect{fill:var(--panel);stroke:var(--bd);stroke-width:1.5}
.gn.entry rect{stroke:var(--ready);stroke-width:2}
.gn.blk rect{stroke:var(--blocked-soft)}
.gn.you rect{stroke:var(--you);stroke-width:3;fill:#1c1810}
.gn.root rect{stroke:var(--acc);stroke-width:2.5}
.gn.missing rect{stroke-dasharray:3,3;fill:var(--panel2)}
.gn text{fill:var(--tx);font:12px ui-monospace,Menlo,Consolas,monospace}
.gn .gref{font-weight:700;fill:var(--acc)}
.gn .grepo{fill:var(--muted);font-size:10px}
.gn{cursor:pointer}
.ge{fill:none}
.ge-stacked{stroke:var(--bd);stroke-width:1.5}
.ge-apex{stroke:var(--acc);stroke-width:1.5;stroke-dasharray:2,4}
.ge-blocks{stroke:var(--blocked-soft);stroke-width:1.5}
.ge-back{stroke-dasharray:5,4;opacity:.6}
footer{color:var(--muted);font-size:11px;text-align:center;margin-top:24px}
"""

JS = r"""
function esc(s){var d=document.createElement('div');d.textContent=s==null?'':String(s);return d.innerHTML;}
const LS='borg-hub-story-v2';
function defState(){return{level:0,project:null,ref:null,isolate:null,
  filters:{projects:[],repos:[],namedOnly:false,parallel:false},cam:{tx:0,ty:0,k:1}};}
function loadState(){try{var s=JSON.parse(localStorage.getItem(LS));if(s&&typeof s==='object'){
  var d=defState();d=Object.assign(d,s);d.filters=Object.assign(defState().filters,s.filters||{});
  d.cam=Object.assign({tx:0,ty:0,k:1},s.cam||{});return d;}}catch(e){}return defState();}
function saveState(){try{localStorage.setItem(LS,JSON.stringify(S));}catch(e){}}
var S=loadState();

var PROJ={};STORY.projects.forEach(function(p){PROJ[p.id]=p;});
var STATE_VAR={'ready-to-start':'--ready','in-flight':'--flight','blocked':'--blocked','pending':'--pending','done':'--done'};
var STATE_LABEL={'ready-to-start':'Ready','in-flight':'In-flight','blocked':'Blocked','pending':'Pending','done':'Done'};
var COL_MAP=[['ready-to-start','ready'],['in-flight','flight'],['blocked','blocked'],['pending','pending']];
var PG_VARS=['--pg1','--pg2','--pg3','--pg4','--pg5'];
var PG_COLOR={};(function(){var i=0;STORY.projects.forEach(function(p){(p.workstreams||[]).forEach(function(w){
  if(w.parallel_group&&!(w.parallel_group in PG_COLOR)){PG_COLOR[w.parallel_group]=PG_VARS[i%PG_VARS.length];i++;}});});})();

function shortTitle(p){return (p.name||p.id||'').split('(')[0].split(' -- ')[0].trim();}
function shortOwner(o){return (o||'').split('(')[0].trim()||'noah';}
function ageStr(s){if(!s)return '-';var d=new Date(String(s).slice(0,10));var t=new Date(String(META.today||'').slice(0,10));
  if(isNaN(d)||isNaN(t))return String(s).slice(0,10);var days=Math.round((t-d)/86400000);return days<=0?'today':days+'d';}
function urg(r){var it=BYREF[r];return it&&typeof it.urgency==='number'?it.urgency:0;}
function workstreamOf(ref){for(var i=0;i<STORY.projects.length;i++){var ws=STORY.projects[i].workstreams||[];
  for(var j=0;j<ws.length;j++){if((ws[j].items||[]).indexOf(ref)>=0)return ws[j];}}return null;}

/* ---- filters ---- */
function projRepos(p){return p.repos||[];}
function repoOk(repos){if(!S.filters.repos.length)return true;return repos.some(function(r){return S.filters.repos.indexOf(r)>=0;});}
function projPasses(p){
  if(S.filters.projects.length&&S.filters.projects.indexOf(p.id)<0)return false;
  if(!repoOk(projRepos(p)))return false;return true;}

function buildFilters(){
  var pf=document.getElementById('projFilter');
  STORY.projects.slice().sort(byPriority).forEach(function(p){
    var c=document.createElement('span');c.className='chip-f';c.textContent=shortTitle(p);c.dataset.p=p.id;
    if(S.filters.projects.indexOf(p.id)>=0)c.classList.add('on');
    c.addEventListener('click',function(){var i=S.filters.projects.indexOf(p.id);
      if(i>=0)S.filters.projects.splice(i,1);else S.filters.projects.push(p.id);c.classList.toggle('on');render();});
    pf.appendChild(c);});
  var rf=document.getElementById('repoFilter');
  (META.repos||[]).forEach(function(r){
    var c=document.createElement('span');c.className='chip-f badge';c.textContent=r;c.dataset.r=r;
    if(S.filters.repos.indexOf(r)>=0)c.classList.add('on');
    c.addEventListener('click',function(){var i=S.filters.repos.indexOf(r);
      if(i>=0)S.filters.repos.splice(i,1);else S.filters.repos.push(r);c.classList.toggle('on');render();});
    rf.appendChild(c);});
  var nt=document.getElementById('namedToggle');nt.classList.toggle('on',S.filters.namedOnly);
  nt.addEventListener('click',function(){S.filters.namedOnly=!S.filters.namedOnly;nt.classList.toggle('on');render();});
  var pt=document.getElementById('parallelToggle');pt.classList.toggle('on',S.filters.parallel);
  pt.addEventListener('click',function(){S.filters.parallel=!S.filters.parallel;pt.classList.toggle('on');render();});
}
function byPriority(a,b){return (a.priority-b.priority)||((b.any_needs_you?1:0)-(a.any_needs_you?1:0))||(a.id<b.id?-1:1);}

/* ---- crumbs ---- */
function renderCrumbs(){
  var c=document.getElementById('crumbs');var b=['<span class="cr" data-lvl="0">Projects</span>'];
  if(S.level>=1&&S.project&&PROJ[S.project]){b.push('<span class="sep">&#9656;</span><span class="cr" data-lvl="1">'+esc(shortTitle(PROJ[S.project]))+'</span>');}
  if(S.ref){b.push('<span class="sep">&#9656;</span><span class="cr" data-lvl="ref">'+esc(S.ref)+'</span>');}
  c.innerHTML=b.join('');
  [].forEach.call(c.querySelectorAll('.cr'),function(s){s.addEventListener('click',function(){
    var l=s.dataset.lvl;if(l==='0'){goto(0,null);}else if(l==='1'){goto(1,S.project);}else{openPanel(S.ref);}});});
}
function goto(level,project){S.level=level;S.project=project;if(level===0)S.project=null;closePanel();render();}

/* ---- L0 ---- */
function meterHtml(p){
  var labs=STATE_ORDER.map(function(s){var c=p.meter[s]||0;return c>0?'<span class="mlab" style="color:var('+STATE_VAR[s]+')">'+c+'</span>':'';}).join('');
  var segs=STATE_ORDER.map(function(s){var c=p.meter[s]||0;
    return '<span class="mseg" title="'+STATE_LABEL[s]+': '+c+'" style="flex-grow:'+(c>0?c:0)+';background:var('+STATE_VAR[s]+');opacity:'+(c>0?1:.3)+'"></span>';}).join('');
  var total=p.meter_total||0;
  var frac=MAX_METER_TOTAL>0?Math.max(METER_MIN_WIDTH_FRAC,total/MAX_METER_TOTAL):1;
  return '<div class="meterlabs">'+labs+'</div><div class="metertrack" title="'+total+' of '+MAX_METER_TOTAL+' (busiest project)">'
    +'<div class="meter" style="width:'+(frac*100).toFixed(1)+'%">'+segs+'</div></div>';}
function cmdHtml(act){var cls=act['class']==='confirm'?'confirm':'readonly';
  return '<div class="cmd cmd-'+cls+'" data-cmd="'+esc(act.command)+'"><span class="cmd-cls">'+cls+'</span><code>'+esc(act.command)+'</code></div>';}
function nextHtml(p){if(p.next_idx==null)return '';var ws=p.workstreams[p.next_idx];if(!ws)return '';
  var h='<div class="nextact"><span class="tri">&#9656;</span>'+esc(ws.next_action)+'</div>';
  var act=ws.entry&&ACT[ws.entry];if(act&&act.command)h+=cmdHtml(act);return h;}
function blockedByHtml(p){
  var ws=p.next_idx!=null?p.workstreams[p.next_idx]:null;
  var hasReady=(p.workstreams||[]).some(function(w){return w.state==='ready-to-start';});
  var anyBlk=(p.workstreams||[]).some(function(w){return w.state==='blocked';});
  var show=(ws&&ws.state==='blocked')||(anyBlk&&!hasReady);if(!show)return '';
  var bws=(ws&&ws.state==='blocked'&&(ws.blocked_by||[]).length)?ws:(p.workstreams||[]).filter(function(w){return w.state==='blocked'&&(w.blocked_by||[]).length;})[0];
  if(!bws)return '';var first=bws.blocked_by[0];
  var more=bws.blocked_by.length>1?' <span class="more">+'+(bws.blocked_by.length-1)+' more</span>':'';
  return '<div class="blockedby">blocked by &rarr; '+esc(first)+more+'</div>';}
function cardHtml(p){
  var cls=['pcard'];if(p.named)cls.push('named');if(p.any_needs_you)cls.push('needsyou');
  var pip=p.any_needs_you?'<span class="pip" title="needs you">&#9873;</span>':'';
  var repos=(p.repos||[]).map(function(r){return '<span class="badge">'+esc(r)+'</span>';}).join('');
  return '<div class="'+cls.join(' ')+'" data-proj="'+esc(p.id)+'">'
    +'<div class="chead"><span class="rank">#'+esc(p.priority)+'</span><span class="ptitle">'+esc(shortTitle(p))+'</span>'+pip+'</div>'
    +'<div class="crow"><span class="owner">@'+esc(shortOwner(p.owner))+'</span>'+repos+'</div>'
    +'<div class="summary" title="'+esc(p.summary)+'">'+esc(p.summary)+'</div>'
    +meterHtml(p)+nextHtml(p)+blockedByHtml(p)+'</div>';}
function renderL0(){
  var projs=STORY.projects.filter(projPasses);
  var named=projs.filter(function(p){return p.named;}).sort(byPriority);
  var others=projs.filter(function(p){return !p.named;}).sort(byPriority);
  var umb=named.filter(function(p){return UMBRELLA.indexOf(p.id)>=0;}).sort(byPriority);
  var restNamed=named.filter(function(p){return UMBRELLA.indexOf(p.id)<0;});
  var nh='';
  if(umb.length>1)nh+='<div class="umbrella"><div class="kicker">Snowflake Password Deprecation</div><div class="grid">'+umb.map(cardHtml).join('')+'</div></div>';
  else if(umb.length===1)restNamed.unshift(umb[0]);
  if(restNamed.length)nh+='<div class="grid">'+restNamed.map(cardHtml).join('')+'</div>';
  // viz-1: the awaiting-you tier, ABOVE the named band. Deliberately absent (not empty) when
  // nothing awaits you -- an always-present labelled section in the highest-value region trains the
  // eye to skip that region, which is D3's "a row that says what every other row says costs space
  // and returns nothing".
  var awaiting=projs.filter(function(p){return p.any_awaiting_you;}).sort(byPriority);
  var out='';
  if(awaiting.length)
    out+='<div class="band"><div class="bandhdr">AWAITING YOU<span class="bandsub">blocked on you \u2014 '+awaiting.length+'</span></div><div class="grid">'+awaiting.map(cardHtml).join('')+'</div></div>';
  out+='<div class="band"><div class="bandhdr">NAMED<span class="bandsub">your top-of-mind programs</span></div>'+(nh||'<div class="colempty">none match filters</div>')+'</div>';
  if(!S.filters.namedOnly)
    out+='<div class="band"><div class="bandhdr">ALSO YOURS<span class="bandsub">easy to forget ('+others.length+')</span></div><div class="grid">'+(others.map(cardHtml).join('')||'<div class="colempty">none match filters</div>')+'</div></div>';
  return out;}
function wireL0(){
  [].forEach.call(document.querySelectorAll('.pcard'),function(card){
    card.addEventListener('click',function(ev){if(ev.target.closest('.cmd'))return;goto(1,card.dataset.proj);});});
  wireCopy();}

/* ---- L1 ---- */
function chipHtml(ref){var it=BYREF[ref];var cls=['ichip'];
  if(it){if(it.is_entrypoint)cls.push('entry');if(it.blocked)cls.push('blk');if(it.bucket==='needs-you')cls.push('you');}
  else cls.push('untracked');
  return '<span class="'+cls.join(' ')+'" data-ref="'+esc(ref)+'">'+esc(ref)+'</span>';}
function wsCardHtml(ws){
  var pg=ws.parallel_group;var rail=pg?'var('+PG_COLOR[pg]+')':'transparent';
  var chips=(ws.items||[]).map(chipHtml).join('');
  var blk='';if(ws.state==='blocked'&&(ws.blocked_by||[]).length)
    blk='<div class="waiting"><b>waiting on</b>'+ws.blocked_by.map(function(b){return '<div class="wrow">'+esc(b)+'</div>';}).join('')+'</div>';
  var pgtag=pg?'<span class="pgtag">&#8741; '+esc(pg)+'</span>':'';
  var pip=ws.needs_you?'<span class="pip" title="needs you">&#9873;</span>':'';
  return '<div class="wscard" data-pg="'+esc(pg||'')+'" style="border-left:3px solid '+rail+'">'
    +'<div class="wshead"><span class="wstitle">'+esc(ws.title)+'</span>'+pgtag+pip+'</div>'
    +'<div class="wsmeta"><span class="ownerchip">@'+esc(shortOwner(ws.owner))+'</span><span class="nitems">'+ws.n_items+' items</span></div>'
    +'<div class="wsnext">'+esc(ws.next_action)+'</div>'
    +'<div class="chips">'+chips+'</div>'+blk+'</div>';}
function renderL1(p){
  var cols=COL_MAP.map(function(cm){
    var st=cm[0];var list=(p.workstreams||[]).filter(function(w){return w.state===st;})
      .sort(function(a,b){return (b.max_urgency-a.max_urgency)||(a.title<b.title?-1:1);});
    var body=list.length?list.map(wsCardHtml).join(''):'<div class="colempty">0</div>';
    return '<div class="col col-'+cm[1]+'"><div class="colhdr">'+STATE_LABEL[st]+'<span class="cc">'+list.length+'</span></div>'+body+'</div>';
  }).join('');
  var done=(p.workstreams||[]).filter(function(w){return w.state==='done';});
  var ship='';if(done.length){ship='<div class="shiprail"><span class="rl">shipped</span>'
    +done.map(function(w){return '<span class="shipitem" title="'+esc(w.next_action)+'">'+esc(w.title)+'</span>';}).join('')+'</div>';}
  return '<div class="board">'+cols+'</div>'+ship;}
function wireL1(){
  [].forEach.call(document.querySelectorAll('.ichip:not(.untracked)'),function(ch){
    ch.addEventListener('click',function(){openPanel(ch.dataset.ref);});});
  [].forEach.call(document.querySelectorAll('.ichip.untracked'),function(ch){
    ch.addEventListener('click',function(){openPanel(ch.dataset.ref);});});
  if(S.filters.parallel){
    [].forEach.call(document.querySelectorAll('.wscard'),function(card){
      var pg=card.dataset.pg;if(!pg)return;
      card.addEventListener('mouseenter',function(){[].forEach.call(document.querySelectorAll('.wscard'),function(o){
        o.classList.toggle('dim',o.dataset.pg!==pg);});});
      card.addEventListener('mouseleave',function(){[].forEach.call(document.querySelectorAll('.wscard'),function(o){o.classList.remove('dim');});});});
  }}

/* ---- L2 panel ---- */
function stateChip(it){var st=(it.state||'').toUpperCase();var c='open',l=it.state||'open';
  if(it.blocked&&st==='OPEN'){c='blocked';l='blocked';}else if(st==='MERGED'){c='merged';l='merged';}
  else if(st==='CLOSED'){c='merged';l='closed';}else if(st==='OPEN'){c='open';l='open';}else{c='wip';l=it.state;}
  return '<span class="schip schip-'+c+'">'+esc(l)+'</span>';}
function edgeListHtml(ref){var rows=[];EDGES.forEach(function(e){
  if(e.parent===ref)rows.push({kind:e.kind,dir:'&rarr;',other:e.child});
  else if(e.child===ref)rows.push({kind:e.kind,dir:'&larr;',other:e.parent});});
  if(!rows.length)return '';
  var body=rows.map(function(r){return '<div class="erow erow-'+r.kind+'"><span class="ekind">'+r.kind+'</span> '+r.dir+' <span class="eref" data-ref="'+esc(r.other)+'">'+esc(r.other)+'</span></div>';}).join('');
  return '<div class="row"><b>edges</b>'+body+'</div>';}
function openPanel(ref){
  S.ref=ref;var it=BYREF[ref];var body=document.getElementById('panelBody');
  if(it){
    var act='';if(it.action&&it.action.command)act='<div class="row"><b>action</b>'+esc(it.action.label)+cmdHtml(it.action)+'</div>';
    var link=it.url?'<a href="'+esc(it.url)+'" target="_blank" rel="noopener">'+esc(it.title||ref)+'</a>':esc(it.title||ref);
    body.innerHTML='<h3>'+esc(ref)+'</h3>'
      +'<div class="row"><b>title</b>'+link+'</div>'
      +'<div class="badges">'+stateChip(it)+(it.repo?'<span class="badge">'+esc(it.repo)+'</span>':'')+(it.source?'<span class="badge">'+esc(it.source)+'</span>':'')+'</div>'
      +'<div class="row"><b>owner</b>'+esc(it.owner||'-')+'</div>'
      +'<div class="row"><b>age</b>'+esc(ageStr(it.changed))+(typeof it.urgency==='number'?' &middot; urgency '+it.urgency:'')+'</div>'
      +'<div class="row"><b>one line</b>'+esc(it.one_line||'-')+'</div>'
      +'<div class="row"><b>action needed</b>'+esc(it.action_needed||'-')+'</div>'
      +act+edgeListHtml(ref)
      +'<div class="isorow"><button class="btn" id="isoBtn">Isolate chain &rarr;</button></div>';
    var ib=document.getElementById('isoBtn');if(ib)ib.addEventListener('click',function(){openIsolate(ref);});
    [].forEach.call(body.querySelectorAll('.eref'),function(e){e.addEventListener('click',function(){openPanel(e.dataset.ref);});});
  }else{
    var tag=ref.indexOf('DE-')===0?'jira (not gathered)':'local / untracked';
    var ws=workstreamOf(ref);
    body.innerHTML='<h3>'+esc(ref)+'</h3>'
      +'<div class="row"><b>ref</b><span class="mono">'+esc(ref)+'</span></div>'
      +'<div class="row"><b>status</b><span class="badge muted">'+esc(tag)+'</span></div>'
      +'<div class="row"><b>next action</b>'+esc(ws?ws.next_action:'-')+'</div>'
      +edgeListHtml(ref);
    [].forEach.call(body.querySelectorAll('.eref'),function(e){e.addEventListener('click',function(){openPanel(e.dataset.ref);});});
  }
  wireCopy();
  document.getElementById('panel').classList.add('open');
  document.getElementById('overlay').classList.add('open');
  renderCrumbs();saveState();}
function closePanel(){S.ref=null;document.getElementById('panel').classList.remove('open');
  document.getElementById('overlay').classList.remove('open');renderCrumbs();saveState();}

/* ---- isolate canvas (the one node-link view) ---- */
var NW=190,NH=60,COL_W=250,ROW_H=96,SVGNS='http://www.w3.org/2000/svg';
function connectedSet(ref){var adj={};function add(a,b){(adj[a]=adj[a]||{})[b]=1;(adj[b]=adj[b]||{})[a]=1;}
  EDGES.forEach(function(e){add(e.parent,e.child);});
  var seen={};seen[ref]=1;var q=[ref];while(q.length){var c=q.shift();var nb=adj[c]||{};
    Object.keys(nb).forEach(function(n){if(!seen[n]){seen[n]=1;q.push(n);}});}return Object.keys(seen);}
function layout(refs){
  var setobj={};refs.forEach(function(r){setobj[r]=1;});
  var din={},outA={},back={};refs.forEach(function(r){din[r]=0;});
  EDGES.forEach(function(e){if((e.kind==='stacked'||e.kind==='blocks')&&setobj[e.parent]&&setobj[e.child]){
    (outA[e.parent]=outA[e.parent]||[]).push(e.child);din[e.child]++;}});
  var rank={};refs.forEach(function(r){rank[r]=0;});
  var indeg=Object.assign({},din);var q=refs.filter(function(r){return indeg[r]===0;});var proc=0;
  var qq=q.slice();while(qq.length){var n=qq.shift();proc++;(outA[n]||[]).forEach(function(c){
    if(rank[n]+1>rank[c])rank[c]=rank[n]+1;if(--indeg[c]===0)qq.push(c);});}
  var byRank={};refs.forEach(function(r){(byRank[rank[r]]=byRank[rank[r]]||[]).push(r);});
  var pos={};Object.keys(byRank).map(Number).sort(function(a,b){return a-b;}).forEach(function(rk){
    var col=byRank[rk].sort(function(a,b){return (urg(b)-urg(a))||(a<b?-1:1);});
    col.forEach(function(r,i){pos[r]={x:rk*COL_W,y:i*ROW_H,rank:rk};});});
  return {pos:pos,rank:rank};}
function mkNode(ref,pos){var it=BYREF[ref];var cls=['gn'];
  if(ref===S.isolate)cls.push('root');
  if(it){if(it.is_entrypoint)cls.push('entry');if(it.blocked)cls.push('blk');if(it.bucket==='needs-you')cls.push('you');}
  else cls.push('missing');
  var g=document.createElementNS(SVGNS,'g');g.setAttribute('class',cls.join(' '));
  g.setAttribute('transform','translate('+pos.x+','+pos.y+')');g.dataset.ref=ref;
  var repo=it?(it.repo||''):(ref.indexOf('DE-')===0?'jira (not gathered)':'untracked');
  var title=it?(it.title||''):'';
  g.innerHTML='<rect width="'+NW+'" height="'+NH+'" rx="7"></rect>'
    +'<text class="gref" x="10" y="18">'+esc(ref)+'</text>'
    +'<text class="grepo" x="10" y="34">'+esc(repo)+'</text>'
    +'<text x="10" y="50" font-size="10" fill="var(--muted)">'+esc(title.slice(0,26))+'</text>';
  g.addEventListener('click',function(ev){ev.stopPropagation();openPanel(ref);});
  return g;}
function mkEdge(a,b,kind,back){var p=document.createElementNS(SVGNS,'path');
  var x1=a.x+NW,y1=a.y+NH/2,x2=b.x,y2=b.y+NH/2;var mx=(x1+x2)/2;
  p.setAttribute('d','M'+x1+','+y1+' C'+mx+','+y1+' '+mx+','+y2+' '+x2+','+y2);
  p.setAttribute('class','ge ge-'+kind+(back?' ge-back':''));
  if(kind==='blocks')p.setAttribute('marker-end','url(#arrow)');return p;}
function openIsolate(ref){
  S.isolate=ref;var refs=connectedSet(ref);var lo=layout(refs);var pos=lo.pos,rank=lo.rank;
  var cam=document.getElementById('camG');cam.innerHTML='<defs><marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="var(--blocked-soft)"/></marker></defs>';
  var setobj={};refs.forEach(function(r){setobj[r]=1;});
  EDGES.forEach(function(e){
    if(!setobj[e.parent]||!setobj[e.child])return;var a=pos[e.parent],b=pos[e.child];if(!a||!b)return;
    var isBack=(e.kind==='stacked'||e.kind==='blocks')&&rank[e.parent]>=rank[e.child];
    cam.appendChild(mkEdge(a,b,e.kind,isBack));});
  refs.forEach(function(r){cam.appendChild(mkNode(r,pos[r]));});
  document.getElementById('isoTitle').textContent='Chain from '+ref+'  ('+refs.length+' nodes)';
  document.getElementById('isoWrap').classList.add('open');
  fit();renderCrumbs();saveState();}
function closeIsolate(){S.isolate=null;document.getElementById('isoWrap').classList.remove('open');saveState();}
function applyCam(){document.getElementById('camG').setAttribute('transform','translate('+S.cam.tx+','+S.cam.ty+') scale('+S.cam.k+')');}
function stageEl(){return document.getElementById('isoStage');}
function fit(pad){pad=pad||34;var cam=document.getElementById('camG');var b;try{b=cam.getBBox();}catch(e){return;}
  if(!b.width||!b.height)return;var r=stageEl().getBoundingClientRect();
  var k=Math.min((r.width-2*pad)/b.width,(r.height-2*pad)/b.height);k=Math.min(2.5,Math.max(0.3,k));
  S.cam.k=k;S.cam.tx=(r.width-b.width*k)/2-b.x*k;S.cam.ty=(r.height-b.height*k)/2-b.y*k;applyCam();saveState();}
/* pan (mouse drag) + zoom (wheel) -- confined to the isolate stage */
var dragging=false,px=0,py=0;
function onDown(e){dragging=true;px=e.clientX;py=e.clientY;stageEl().style.cursor='grabbing';document.getElementById('camG').classList.add('panning');}
function onMove(e){if(!dragging)return;S.cam.tx+=e.clientX-px;S.cam.ty+=e.clientY-py;px=e.clientX;py=e.clientY;applyCam();}
function onUp(){if(!dragging)return;dragging=false;stageEl().style.cursor='grab';document.getElementById('camG').classList.remove('panning');saveState();}
function onWheel(e){e.preventDefault();var r=stageEl().getBoundingClientRect();var cx=e.clientX-r.left,cy=e.clientY-r.top;
  var kOld=S.cam.k;var k=S.cam.k*(e.deltaY<0?1.1:1/1.1);k=Math.min(2.5,Math.max(0.3,k));
  S.cam.tx=cx-(cx-S.cam.tx)*(k/kOld);S.cam.ty=cy-(cy-S.cam.ty)*(k/kOld);S.cam.k=k;applyCam();saveState();}

/* ---- copy wiring ---- */
function wireCopy(){[].forEach.call(document.querySelectorAll('.cmd'),function(c){
  if(c._wired)return;c._wired=1;c.title='click to copy';
  c.addEventListener('click',function(ev){ev.stopPropagation();var t=c.dataset.cmd||c.textContent;
    if(navigator.clipboard)navigator.clipboard.writeText(t);
    c.classList.add('copied');setTimeout(function(){c.classList.remove('copied');},600);});});}

/* ---- dispatcher ---- */
function render(){
  renderCrumbs();var v=document.getElementById('view');
  if(S.level===1&&S.project&&PROJ[S.project]){v.innerHTML=renderL1(PROJ[S.project]);wireL1();}
  else{S.level=0;v.innerHTML=renderL0();wireL0();}
  saveState();}

function wireGlobal(){
  document.getElementById('panelClose').addEventListener('click',closePanel);
  document.getElementById('overlay').addEventListener('click',closePanel);
  document.getElementById('isoClose').addEventListener('click',closeIsolate);
  document.getElementById('isoFit').addEventListener('click',function(){fit();});
  var st=stageEl();
  st.addEventListener('mousedown',onDown);
  window.addEventListener('mousemove',onMove);
  window.addEventListener('mouseup',onUp);
  st.addEventListener('wheel',onWheel,{passive:false});
  window.addEventListener('keydown',function(e){
    if(document.getElementById('isoWrap').classList.contains('open')){
      if(e.key==='Escape'){closeIsolate();return;}
      if(e.key==='0'){fit();return;}
      if(e.key==='+'||e.key==='='){S.cam.k=Math.min(2.5,S.cam.k*1.1);applyCam();saveState();return;}
      if(e.key==='-'){S.cam.k=Math.max(0.3,S.cam.k/1.1);applyCam();saveState();return;}
    }
    if(e.key==='Escape'){
      if(document.getElementById('panel').classList.contains('open')){closePanel();return;}
      if(S.level>0){goto(S.level-1,null);return;}
    }});
}

function init(){buildFilters();wireGlobal();S.ref=null;render();
  if(S.isolate&&BYREF){openIsolate(S.isolate);}}
init();
"""


def build_html():
    """Assemble the full graph.html document: CSS, header, body, baked JSON payloads, and JS."""
    proj_n = len(projects)
    ws_n = sum(len(p.get("workstreams", []) or []) for p in projects)
    repos_n = len(META.get("repos", []))
    header = (
        "<header>"
        f'<h1>STORY GRAPH <span class="sub">{proj_n} projects &middot; {ws_n} workstreams &middot; '
        f"{len(items)} items / {repos_n} repos &middot; {esc(META.get('machine', ''))} &middot; "
        '<a href="index.html">&larr; List view</a></span></h1>'
        '<div class="bar">'
        '<div class="fgroup" id="projFilter"><b>project</b></div>'
        '<div class="fgroup" id="repoFilter"><b>repo</b></div>'
        '<div class="fgroup toggles"><button class="tg" id="namedToggle">Named only</button>'
        '<button class="tg" id="parallelToggle">Highlight parallel</button></div>'
        "</div>"
        '<div class="crumbs" id="crumbs"></div>'
        "</header>"
    )
    body = (
        '<main><div id="view"></div>'
        "<footer>story-first hub &middot; source: story.json (spine) + data.json (detail) &middot; "
        "merge-tree/render_graph.py</footer></main>"
        '<div id="overlay"></div>'
        '<aside id="panel"><span class="pclose" id="panelClose">&#10005;</span><div id="panelBody"></div></aside>'
        '<div id="isoWrap"><div id="isoBar"><span id="isoTitle"></span>'
        '<span class="isohint">drag to pan &middot; wheel to zoom &middot; 0 = fit &middot; Esc = close</span>'
        '<span class="spacer"></span><button class="btn" id="isoFit">Fit</button>'
        '<button class="btn" id="isoClose">Close &#10005;</button></div>'
        '<svg id="isoStage" xmlns="http://www.w3.org/2000/svg"><g id="camG"></g></svg></div>'
    )
    return (
        '<!doctype html>\n<html lang="en"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        "<title>Story Graph - PR Control Hub</title>"
        "<style>"
        + CSS
        + "</style></head><body>"
        + header
        + body
        + "<script>"
        + CONSTS
        + JS
        + "</script>"
        + "</body></html>"
    )


if __name__ == "__main__":
    doc = build_html()
    with open(ARGS.out, "w", encoding="utf-8") as f:
        f.write(doc)
    top_level = len(projects)
    print("wrote", ARGS.out)
    print(
        "top-level project cards:",
        top_level,
        "workstreams:",
        sum(len(p.get("workstreams", []) or []) for p in projects),
        "items joined:",
        len(items),
        "edges:",
        len(EDGES),
    )
    print("bytes:", os.path.getsize(ARGS.out))
