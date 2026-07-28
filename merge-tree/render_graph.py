#!/usr/bin/env python3
"""render_graph.py - interactive drill-down dependency-graph view for the PR control hub.

Reads  <STATE>/data.json               (same curated recon artifact as render.py)
Reads  <STATE>/annotations.local.json  (OPTIONAL, machine-local; joined at render time)
Writes <STATE>/graph.html              (self-contained dark-mode node-link graph; no external deps)

STATE defaults to ~/.local/state/borg/merge-tree but is overridable via the
BORG_MERGE_TREE_DIR env var. --data/--out/--annotations CLI flags override the
individual paths. python3 stdlib only -- see render.py for the schema contract.

Drill-down model:
  Level 0 (field of play): projects as columns, one row per TOP-LEVEL item.
    A top-level item is NOT the child of any stacked/apex edge. A top-level
    PR with stacked/apex descendants renders as one node with a "+N stacked"
    badge; its descendants are hidden at this level.
  Level 1 (stack sub-graph): clicking a grouped top-level node opens its
    descendants (the stacked/apex chain) as a small internal graph, plus any
    blocks edges that cross the group boundary (shown as external stubs).
  Level 2 (info panel): clicking any leaf node opens the full informational
    panel for that item (ref/title/repo/project/source/state/bucket/owner/
    url/one_line/action_needed/urgency/blocked + the actions[ref] command).

Re-run with:  python3 merge-tree/render_graph.py
"""
import argparse
import html
import json
import os
from collections import defaultdict

STATE = os.environ.get("BORG_MERGE_TREE_DIR", os.path.expanduser("~/.local/state/borg/merge-tree"))


def parse_args():
    p = argparse.ArgumentParser(description="Render the interactive dependency-graph view from data.json.")
    p.add_argument("--data", default=os.path.join(STATE, "data.json"), help="path to data.json")
    p.add_argument("--out", default=os.path.join(STATE, "graph.html"), help="path to write graph.html")
    p.add_argument("--annotations", default=os.path.join(STATE, "annotations.local.json"),
                   help="path to the optional machine-local annotations file")
    return p.parse_args()


ARGS = parse_args()
DATA = ARGS.data
ANNOT = ARGS.annotations
OUT = ARGS.out

with open(DATA) as f:
    D = json.load(f)

annotations = {}
if os.path.exists(ANNOT):
    try:
        with open(ANNOT) as f:
            annotations = json.load(f) or {}
    except (ValueError, OSError):
        annotations = {}

meta = D.get("meta", {})
items = D.get("items", [])
edges = D.get("edges", [])
actions = D.get("actions", {})

for it in items:
    ov = annotations.get(it.get("ref"))
    if isinstance(ov, dict):
        it.update({k: v for k, v in ov.items() if k not in ("history",)})

by_ref = {it["ref"]: it for it in items}


def esc(s):
    return html.escape(str(s if s is not None else ""))


def project_hue(project):
    """Stable hash -> hue (0-359); same convention as render.py so colors match."""
    h = 0
    for ch in project or "":
        h = (h * 31 + ord(ch)) & 0xFFFFFFFF
    return h % 360


def repo_hue(repo):
    h = 0
    for ch in (repo or "")[::-1]:
        h = (h * 37 + ord(ch)) & 0xFFFFFFFF
    return h % 360


# ---------------------------------------------------------------- edge indices
stacked_children = defaultdict(list)   # parent -> [child]  (stacked kind only)
apex_children = defaultdict(list)      # parent -> [child]  (apex kind only)
group_parent_children = defaultdict(list)  # parent -> [child] for stacked+apex (grouping)
blocks_pairs = []                      # [(parent, child)]
child_of_group = set()                 # refs that are children of a stacked/apex edge

for e in edges:
    k, p, c = e.get("kind"), e.get("parent"), e.get("child")
    if not p or not c:
        continue
    if k == "stacked":
        stacked_children[p].append(c)
        group_parent_children[p].append(c)
        child_of_group.add(c)
    elif k == "apex":
        apex_children[p].append(c)
        group_parent_children[p].append(c)
        child_of_group.add(c)
    elif k == "blocks":
        blocks_pairs.append((p, c))


def descendants_of(root):
    """BFS over stacked+apex edges from root -> full flat descendant set (refs only)."""
    seen = []
    seen_set = set()
    frontier = [root]
    while frontier:
        nxt = []
        for node in frontier:
            for c in group_parent_children.get(node, []):
                if c not in seen_set and c != root:
                    seen_set.add(c)
                    seen.append(c)
                    nxt.append(c)
        frontier = nxt
    return seen


# top-level refs: not a child of any stacked/apex edge, and present in items
top_level_refs = [it["ref"] for it in items if it["ref"] not in child_of_group]

# representative map: any ref -> the top-level ref whose group contains it
representative = {}
group_members = {}   # top-level ref -> [descendant refs] (flat)
for root in top_level_refs:
    desc = descendants_of(root)
    group_members[root] = desc
    representative[root] = root
    for d in desc:
        representative[d] = root

# blocks edges projected to top-level representatives, for the level-0 view
top_blocks = []
seen_pairs = set()
for p, c in blocks_pairs:
    rp = representative.get(p, p)
    rc = representative.get(c, c)
    if rp == rc:
        continue
    key = (rp, rc)
    if key in seen_pairs:
        continue
    seen_pairs.add(key)
    top_blocks.append({"parent": rp, "child": rc, "detail": f"{p} blocks {c}"})


def node_payload(ref):
    it = by_ref.get(ref)
    if not it:
        return {"ref": ref, "title": "", "missing": True}
    act = actions.get(ref) or {}
    return {
        "ref": ref,
        "title": it.get("title") or "",
        "project": it.get("project") or "misc / infra",
        "repo": it.get("repo") or "",
        "source": it.get("source") or "",
        "state": it.get("state") or "",
        "bucket": it.get("bucket") or "",
        "owner": it.get("owner") or "",
        "url": it.get("url") or "",
        "one_line": it.get("one_line") or "",
        "action_needed": it.get("action_needed") or "",
        "urgency": it.get("urgency"),
        "blocked": bool(it.get("blocked")),
        "is_entrypoint": bool(it.get("is_entrypoint")),
        "action": {"label": act.get("label", ""), "command": act.get("command", ""),
                   "class": act.get("class", "readonly")} if act else None,
    }


# ---------------------------------------------------------------- build node/edge payloads
nodes_out = {}
for it in items:
    nodes_out[it["ref"]] = node_payload(it["ref"])

top_nodes = []
for root in top_level_refs:
    payload = dict(nodes_out[root])
    payload["group"] = group_members[root]
    top_nodes.append(payload)

# order projects the same way render.py does: by max urgency desc, then name
proj_of_top = defaultdict(list)
for n in top_nodes:
    proj_of_top[n["project"]].append(n)
proj_order = sorted(proj_of_top.keys(),
                     key=lambda p: (-max((n.get("urgency") or 0) for n in proj_of_top[p]), p.lower()))
for p in proj_order:
    proj_of_top[p].sort(key=lambda n: (-(n.get("urgency") or 0), n["ref"]))

repo_set = sorted({it.get("repo") for it in items if it.get("repo")})
project_set = proj_order

internal_edges = [e for e in edges if e.get("kind") in ("stacked", "apex")]

GRAPH_DATA = {
    "nodes": nodes_out,
    "topNodes": top_nodes,
    "projOrder": proj_order,
    "projGroups": {p: [n["ref"] for n in proj_of_top[p]] for p in proj_order},
    "groupMembers": group_members,
    "internalEdges": internal_edges,
    "blocksEdges": [{"parent": p, "child": c} for p, c in blocks_pairs],
    "topBlocks": top_blocks,
    "repoSet": repo_set,
    "projectSet": project_set,
    "projectHue": {p: project_hue(p) for p in project_set},
    "repoHue": {r: repo_hue(r) for r in repo_set},
}

repos_n = len(meta.get("repos", []))

CSS = """
:root{
  --bg:#0d1117; --panel:#161b22; --panel2:#0f141a; --bd:#30363d; --tx:#c9d1d9;
  --muted:#8b949e; --merged:#6e7681; --draft:#58a6ff; --wip:#d29922; --red:#f85149;
  --green:#3fb950; --you:#e3b341; --acc:#1f6feb;
}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--tx);
  font:13px/1.4 ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;padding:0 0 40px}
a{color:inherit;text-decoration:none}
a:hover{text-decoration:underline}
header{position:sticky;top:0;z-index:30;background:linear-gradient(180deg,#0d1117,#0d1117f0);
  border-bottom:1px solid var(--bd);padding:12px 20px 8px;backdrop-filter:blur(4px)}
h1{font-size:15px;margin:0 0 4px;letter-spacing:.5px}
h1 .sub{color:var(--muted);font-weight:400;font-size:11px;margin-left:10px}
.crumbs{font-size:12px;color:var(--muted);margin:4px 0}
.crumbs span{cursor:pointer;color:var(--acc)}
.crumbs span:hover{text-decoration:underline}
.bar{display:flex;flex-wrap:wrap;gap:14px;align-items:flex-start;margin-top:6px}
.grp{display:flex;flex-wrap:wrap;gap:4px;align-items:center;max-width:520px}
.grp b{color:var(--muted);font-weight:400;margin-right:4px;font-size:11px}
.chip-f{cursor:pointer;padding:2px 8px;border-radius:10px;border:1px solid var(--bd);
  background:var(--panel);color:var(--muted);font-size:11px}
.chip-f.on{background:var(--acc);color:#fff;border-color:var(--acc)}
.fbtn{cursor:pointer;padding:3px 12px;border-radius:6px;border:1px solid var(--bd);
  background:var(--panel);color:var(--muted);font-size:12px}
.fbtn.on{background:var(--you);color:#000;border-color:var(--you)}
.legend{display:flex;gap:12px;flex-wrap:wrap;color:var(--muted);font-size:11px;margin-top:6px}
.legend span{white-space:nowrap;display:inline-flex;align-items:center;gap:4px}
.dot{display:inline-block;width:9px;height:9px;border-radius:50%}
.lineseg{display:inline-block;width:18px;height:0;border-top:2px solid var(--tx);vertical-align:middle}
.lineseg.dash{border-top:2px dashed var(--red)}
.lineseg.apex{border-top:2px dotted var(--green)}
#stage{position:relative;margin:10px 20px;border:1px solid var(--bd);border-radius:8px;
  background:var(--panel2);overflow:auto;max-height:74vh}
svg{display:block}
.node rect{stroke:var(--bd);stroke-width:1.5;fill:var(--panel)}
.node.merged rect{opacity:.5}
.node.blocked rect{stroke:var(--red)}
.node.entry rect{stroke:var(--green);stroke-width:2}
.node.dim{opacity:.15}
.node.ext rect{fill:var(--panel2);stroke-dasharray:3,2}
.node text{fill:var(--tx);font:12px ui-monospace,Menlo,Consolas,monospace}
.node .ref{font-weight:700;fill:var(--acc)}
.node .repo{fill:var(--muted);font-size:10px}
.node .badge{fill:var(--you);font-size:10px}
.node{cursor:pointer}
.node:hover rect{stroke:var(--acc);stroke-width:2}
.edge{fill:none;stroke:var(--tx);stroke-width:1.6;opacity:.8}
.edge.stacked{stroke:var(--tx)}
.edge.apex{stroke:var(--green);stroke-dasharray:1,4;stroke-linecap:round}
.edge.blocks{stroke:var(--red);stroke-dasharray:5,3}
.edge.dim{opacity:.08}
#panel{position:fixed;top:0;right:0;bottom:0;width:380px;max-width:92vw;background:var(--panel);
  border-left:1px solid var(--bd);z-index:50;overflow-y:auto;padding:16px;transform:translateX(100%);
  transition:transform .15s ease}
#panel.open{transform:translateX(0)}
#panel h3{margin:0 0 8px;font-size:14px}
#panel .close{position:absolute;top:10px;right:14px;cursor:pointer;color:var(--muted);font-size:16px}
#panel .row{margin:8px 0;font-size:12px}
#panel .row b{color:var(--muted);display:block;font-size:10px;text-transform:uppercase;letter-spacing:.4px}
#panel .cmd{margin-top:4px;background:#0d1117;border:1px solid var(--bd);border-radius:5px;padding:6px 8px;
  font-size:11px;cursor:copy;word-break:break-all}
#panel .cmd .cls{display:inline-block;margin-bottom:4px;font-size:9px;text-transform:uppercase;
  border-radius:8px;padding:1px 6px;border:1px solid}
#panel .cmd.readonly .cls{color:var(--green);border-color:#1f3a26}
#panel .cmd.confirm .cls{color:var(--you);border-color:var(--you)}
#overlay{position:fixed;inset:0;background:#000a;z-index:40;display:none}
#overlay.open{display:block}
footer{color:var(--muted);font-size:11px;text-align:center;margin-top:14px}
"""


def node_svg_group(n, x, y, w=200, h=44, ext=False):
    st = (n.get("state") or "").upper()
    cls = ["node"]
    if st in ("MERGED", "CLOSED") or st == "DONE":
        cls.append("merged")
    if n.get("blocked"):
        cls.append("blocked")
    if n.get("is_entrypoint"):
        cls.append("entry")
    if ext:
        cls.append("ext")
    hue = project_hue(n.get("project"))
    badge = ""
    grp = n.get("group") or []
    if grp:
        badge = f'<text class="badge" x="{w - 8}" y="14" text-anchor="end">+{len(grp)}</text>'
    repo_txt = esc(n.get("repo") or "")
    title_txt = esc((n.get("title") or "")[:34])
    return (f'<g class="{" ".join(cls)}" data-ref="{esc(n["ref"])}" transform="translate({x},{y})">'
            f'<rect width="{w}" height="{h}" rx="6" style="border-left-color:hsl({hue},55%,50%)" '
            f'stroke-width="1.5" fill="var(--panel)"/>'
            f'<rect x="0" y="0" width="4" height="{h}" fill="hsl({hue},55%,50%)"/>'
            f'<text class="ref" x="10" y="16">{esc(n["ref"])}</text>'
            f'{badge}'
            f'<text class="repo" x="10" y="30">{repo_txt}</text>'
            f'<text x="10" y="42" font-size="10" fill="var(--muted)">{title_txt}</text>'
            f'</g>')


html_doc = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>PR Control Hub - Dependency Graph</title>
<style>{CSS}</style></head><body>
<header>
  <h1>DEPENDENCY GRAPH <span class="sub">{len(items)} items across {repos_n} repos &middot;
    {len(top_nodes)} top-level &middot; <a href="index.html">&larr; List view</a></span></h1>
  <div class="crumbs" id="crumbs"></div>
  <div class="bar">
    <div class="grp" id="projFilter"><b>project</b></div>
    <div class="grp" id="repoFilter"><b>repo</b></div>
    <div class="grp">
      <button class="fbtn" id="isolateBtn">Isolate chain</button>
      <button class="fbtn" id="clearBtn">Clear</button>
    </div>
  </div>
  <div class="legend">
    <span><span class="dot" style="background:var(--green)"></span>entrypoint</span>
    <span><span class="dot" style="background:var(--red)"></span>blocked</span>
    <span><span class="dot" style="background:var(--merged);opacity:.6"></span>merged/closed (faded)</span>
    <span><span class="lineseg"></span>stacked</span>
    <span><span class="lineseg apex"></span>apex group</span>
    <span><span class="lineseg dash"></span>blocks (dependency)</span>
    <span>click a node: drill in / open info &middot; click empty space to go up</span>
  </div>
</header>
<div id="stage"><svg id="canvas" xmlns="http://www.w3.org/2000/svg"></svg></div>
<div id="overlay"></div>
<div id="panel">
  <span class="close" id="panelClose">&#10005;</span>
  <div id="panelBody"></div>
</div>
<footer>generated from data.json &middot; source: merge-tree/render_graph.py</footer>
<script>
const DATA = {json.dumps(GRAPH_DATA)};
const NODE_W = 200, NODE_H = 44, COL_W = 230, ROW_H = 56, PAD = 30;

let state = {{level:0, group:null, filterProj:new Set(), filterRepo:new Set(), isolate:null, isolateMode:false}};

function esc(s){{
  const d = document.createElement('div'); d.textContent = s==null? '': String(s); return d.innerHTML;
}}

function buildFilterChips(){{
  const pf = document.getElementById('projFilter');
  DATA.projectSet.forEach(p=>{{
    const c = document.createElement('span');
    c.className='chip-f'; c.textContent=p; c.dataset.p=p;
    c.addEventListener('click',()=>{{
      if(state.filterProj.has(p)) state.filterProj.delete(p); else state.filterProj.add(p);
      c.classList.toggle('on'); render();
    }});
    pf.appendChild(c);
  }});
  const rf = document.getElementById('repoFilter');
  DATA.repoSet.forEach(r=>{{
    const c = document.createElement('span');
    c.className='chip-f'; c.textContent=r; c.dataset.r=r;
    c.addEventListener('click',()=>{{
      if(state.filterRepo.has(r)) state.filterRepo.delete(r); else state.filterRepo.add(r);
      c.classList.toggle('on'); render();
    }});
    rf.appendChild(c);
  }});
}}

function passesFilter(n){{
  if(state.filterProj.size && !state.filterProj.has(n.project)) return false;
  if(state.filterRepo.size && !state.filterRepo.has(n.repo)) return false;
  return true;
}}

function nodeGroup(n, x, y, ext){{
  const cls = ['node'];
  const st = (n.state||'').toUpperCase();
  if(st==='MERGED'||st==='CLOSED'||st==='DONE') cls.push('merged');
  if(n.blocked) cls.push('blocked');
  if(n.is_entrypoint) cls.push('entry');
  if(ext) cls.push('ext');
  const hue = DATA.projectHue[n.project] || 0;
  const g = document.createElementNS('http://www.w3.org/2000/svg','g');
  g.setAttribute('class', cls.join(' '));
  g.setAttribute('transform', `translate(${{x}},${{y}})`);
  g.dataset.ref = n.ref;
  g.innerHTML = `
    <rect width="${{NODE_W}}" height="${{NODE_H}}" rx="6"></rect>
    <rect x="0" y="0" width="4" height="${{NODE_H}}" fill="hsl(${{hue}},55%,50%)"></rect>
    <text class="ref" x="10" y="16">${{esc(n.ref)}}</text>
    ${{ (n.group && n.group.length) ? `<text class="badge" x="${{NODE_W-8}}" y="14" text-anchor="end">+${{n.group.length}} stacked</text>` : '' }}
    <text class="repo" x="10" y="30">${{esc(n.repo||'')}}</text>
    <text x="10" y="42" font-size="10" fill="var(--muted)">${{esc((n.title||'').slice(0,32))}}</text>
  `;
  g.addEventListener('click',(ev)=>{{
    ev.stopPropagation();
    if(state.isolateMode){{ doIsolate(n.ref); return; }}
    onNodeClick(n);
  }});
  return g;
}}

function edgePath(x1,y1,x2,y2,kind){{
  const p = document.createElementNS('http://www.w3.org/2000/svg','path');
  const mx = (x1+x2)/2;
  p.setAttribute('d', `M${{x1}},${{y1}} C${{mx}},${{y1}} ${{mx}},${{y2}} ${{x2}},${{y2}}`);
  p.setAttribute('class', 'edge ' + kind);
  return p;
}}

function onNodeClick(n){{
  if(n.group && n.group.length){{
    state.level = 1; state.group = n.ref; render();
  }} else {{
    openPanel(n.ref);
  }}
}}

function crumbTo(level){{
  state.level = level; if(level===0) state.group=null;
  render();
}}

function renderCrumbs(){{
  const c = document.getElementById('crumbs');
  let bits = ['<span data-lvl="0">field of play</span>'];
  if(state.level>=1 && state.group) bits.push(' &raquo; <span data-lvl="1">'+esc(state.group)+' stack</span>');
  c.innerHTML = bits.join('');
  [...c.querySelectorAll('span')].forEach(s=>s.addEventListener('click',()=>crumbTo(parseInt(s.dataset.lvl))));
}}

function doIsolate(ref){{
  state.isolate = ref; state.isolateMode = false;
  document.getElementById('isolateBtn').classList.remove('on');
  render();
}}

function connectedSet(ref){{
  // upstream+downstream over stacked + blocks edges, both directions
  const adj = {{}};
  function link(a,b){{ (adj[a] = adj[a]||new Set()).add(b); (adj[b]=adj[b]||new Set()).add(a); }}
  DATA.internalEdges.forEach(e=>{{ if(e.kind==='stacked') link(e.parent, e.child); }});
  DATA.blocksEdges.forEach(e=>link(e.parent, e.child));
  const seen = new Set([ref]); const q=[ref];
  while(q.length){{
    const cur = q.shift();
    (adj[cur]||new Set()).forEach(nb=>{{ if(!seen.has(nb)){{ seen.add(nb); q.push(nb); }} }});
  }}
  return seen;
}}

function render(){{
  renderCrumbs();
  const svg = document.getElementById('canvas');
  while(svg.firstChild) svg.removeChild(svg.firstChild);
  const isoSet = state.isolate ? connectedSet(state.isolate) : null;

  if(state.level===0){{
    let x = PAD;
    const cols = [];
    DATA.projOrder.forEach(p=>{{
      const refs = DATA.projGroups[p].map(r=>DATA.nodes[r]).filter(passesFilter);
      if(!refs.length) return;
      cols.push({{p, refs, x}});
      x += COL_W;
    }});
    const maxRows = Math.max(1, ...cols.map(c=>c.refs.length));
    const height = PAD*2 + maxRows*ROW_H + 20;
    svg.setAttribute('width', Math.max(400, x+PAD));
    svg.setAttribute('height', height);
    const posByRef = {{}};
    cols.forEach(col=>{{
      const label = document.createElementNS('http://www.w3.org/2000/svg','text');
      label.setAttribute('x', col.x); label.setAttribute('y', 18);
      label.setAttribute('fill', 'var(--muted)'); label.setAttribute('font-size','11');
      label.textContent = col.p;
      svg.appendChild(label);
      col.refs.forEach((n,i)=>{{
        const y = PAD + i*ROW_H + 10;
        posByRef[n.ref] = {{x:col.x, y, w:NODE_W, h:NODE_H}};
        svg.appendChild(nodeGroup(n, col.x, y, false));
      }});
    }});
    DATA.topBlocks.forEach(e=>{{
      const a = posByRef[e.parent], b = posByRef[e.child];
      if(!a || !b) return;
      const path = edgePath(a.x+a.w, a.y+a.h/2, b.x, b.y+b.h/2, 'blocks');
      path.setAttribute('title', e.detail);
      svg.insertBefore(path, svg.firstChild);
    }});
    if(isoSet){{
      [...svg.querySelectorAll('.node')].forEach(g=>{{
        const ref = g.dataset.ref;
        const inSet = isoSet.has(ref) || (DATA.nodes[ref] && DATA.nodes[ref].group||[]).some(d=>isoSet.has(d));
        g.classList.toggle('dim', !inSet);
      }});
      [...svg.querySelectorAll('.edge')].forEach(p=>p.classList.add('dim'));
    }}
  }} else if(state.level===1){{
    const rootRef = state.group;
    const root = DATA.nodes[rootRef];
    const members = DATA.groupMembers[rootRef] || [];
    const allRefs = [rootRef, ...members];
    const nodesHere = allRefs.map(r=>DATA.nodes[r]);
    let y = PAD;
    const posByRef = {{}};
    nodesHere.forEach(n=>{{
      posByRef[n.ref] = {{x:PAD, y, w:NODE_W, h:NODE_H}};
      y += ROW_H;
    }});
    // external blocks stubs
    const extRefs = new Set();
    DATA.blocksEdges.forEach(e=>{{
      if(allRefs.includes(e.parent) && !allRefs.includes(e.child)) extRefs.add(e.child);
      if(allRefs.includes(e.child) && !allRefs.includes(e.parent)) extRefs.add(e.parent);
    }});
    let ey = PAD;
    [...extRefs].forEach(r=>{{
      posByRef[r] = {{x:PAD + COL_W + 60, y:ey, w:NODE_W, h:NODE_H}};
      ey += ROW_H;
    }});
    const height = PAD*2 + Math.max(y, ey) + 10;
    svg.setAttribute('width', PAD*2 + COL_W + 60 + NODE_W);
    svg.setAttribute('height', height);
    nodesHere.forEach(n=>{{
      const pos = posByRef[n.ref];
      svg.appendChild(nodeGroup(n, pos.x, pos.y, false));
    }});
    [...extRefs].forEach(r=>{{
      const n = DATA.nodes[r] || {{ref:r, title:'', project:'', repo:''}};
      const pos = posByRef[r];
      svg.appendChild(nodeGroup(n, pos.x, pos.y, true));
    }});
    DATA.internalEdges.forEach(e=>{{
      if(!allRefs.includes(e.parent) || !allRefs.includes(e.child)) return;
      const a = posByRef[e.parent], b = posByRef[e.child];
      if(!a||!b) return;
      svg.insertBefore(edgePath(a.x+a.w/2, a.y+a.h, b.x+b.w/2, b.y, e.kind), svg.firstChild);
    }});
    DATA.blocksEdges.forEach(e=>{{
      if(!(allRefs.includes(e.parent) || allRefs.includes(e.child))) return;
      const a = posByRef[e.parent], b = posByRef[e.child];
      if(!a||!b) return;
      svg.insertBefore(edgePath(a.x+a.w, a.y+a.h/2, b.x, b.y+b.h/2, 'blocks'), svg.firstChild);
    }});
    if(isoSet){{
      [...svg.querySelectorAll('.node')].forEach(g=>g.classList.toggle('dim', !isoSet.has(g.dataset.ref)));
      [...svg.querySelectorAll('.edge')].forEach(p=>p.classList.add('dim'));
    }}
  }}
}}

function openPanel(ref){{
  const n = DATA.nodes[ref];
  if(!n) return;
  const body = document.getElementById('panelBody');
  let actionHtml = '';
  if(n.action && (n.action.label || n.action.command)){{
    actionHtml = `<div class="row"><b>action</b>${{esc(n.action.label)}}
      ${{ n.action.command ? `<div class="cmd ${{esc(n.action.class)}}"><span class="cls">${{esc(n.action.class)}}</span><br>${{esc(n.action.command)}}</div>` : '' }}
    </div>`;
  }}
  body.innerHTML = `
    <h3>${{esc(n.ref)}}</h3>
    <div class="row"><b>title</b>${{esc(n.title)}}</div>
    <div class="row"><b>repo / project</b>${{esc(n.repo)}} &middot; ${{esc(n.project)}}</div>
    <div class="row"><b>source</b>${{esc(n.source)}}</div>
    <div class="row"><b>state / bucket</b>${{esc(n.state)}} &middot; ${{esc(n.bucket)}}</div>
    <div class="row"><b>owner</b>${{esc(n.owner)}}</div>
    <div class="row"><b>url</b><a href="${{esc(n.url)}}" target="_blank" rel="noopener">${{esc(n.url)}}</a></div>
    <div class="row"><b>one_line</b>${{esc(n.one_line)}}</div>
    <div class="row"><b>action_needed</b>${{esc(n.action_needed)}}</div>
    <div class="row"><b>urgency</b>${{esc(n.urgency)}}</div>
    <div class="row"><b>blocked</b>${{n.blocked?'yes':'no'}}</div>
    ${{actionHtml}}
  `;
  [...body.querySelectorAll('.cmd')].forEach(c=>{{
    c.addEventListener('click',()=>{{ navigator.clipboard && navigator.clipboard.writeText(c.textContent); }});
  }});
  document.getElementById('panel').classList.add('open');
  document.getElementById('overlay').classList.add('open');
}}

document.getElementById('panelClose').addEventListener('click', ()=>{{
  document.getElementById('panel').classList.remove('open');
  document.getElementById('overlay').classList.remove('open');
}});
document.getElementById('overlay').addEventListener('click', ()=>{{
  document.getElementById('panel').classList.remove('open');
  document.getElementById('overlay').classList.remove('open');
}});
document.getElementById('stage').addEventListener('click', (ev)=>{{
  if(ev.target.id==='stage' || ev.target.id==='canvas'){{
    if(state.level>0) crumbTo(state.level-1);
  }}
}});
document.getElementById('isolateBtn').addEventListener('click', ()=>{{
  state.isolateMode = !state.isolateMode;
  document.getElementById('isolateBtn').classList.toggle('on', state.isolateMode);
}});
document.getElementById('clearBtn').addEventListener('click', ()=>{{
  state.isolate = null; state.isolateMode = false;
  document.getElementById('isolateBtn').classList.remove('on');
  render();
}});

buildFilterChips();
render();
</script>
</body></html>"""

with open(OUT, "w") as f:
    f.write(html_doc)

print("wrote", OUT)
print("top-level nodes:", len(top_nodes), "projects:", len(proj_order), "repos:", len(repo_set))
print("internal edges (stacked/apex):", len(internal_edges), "blocks edges:", len(blocks_pairs),
      "top-level blocks:", len(top_blocks))
print("bytes:", os.path.getsize(OUT))
