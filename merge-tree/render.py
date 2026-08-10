#!/usr/bin/env python3
"""render.py - cross-repo PR/issue/Jira control hub renderer (graduated schema).

Reads  <STATE>/data.json               (curated recon artifact: meta + items + edges + actions)
Reads  <STATE>/annotations.local.json  (OPTIONAL, machine-local; joined at render time)
Writes <STATE>/index.html              (self-contained dark-mode view; no external deps)

STATE defaults to ~/.local/state/borg/merge-tree but is overridable via the
BORG_MERGE_TREE_DIR env var, so this file is machine-agnostic once graduated
into the repo. --data/--out CLI flags override the individual paths.

Re-run with:  python3 merge-tree/render.py

RATIFIED SCHEMA (v2, four-bucket) -- see SCHEMA.md for the full contract:
  meta    : {gathered_at, machine, today, repos[], health[]}
  items[] : {ref, project, repo, source, title, state, changed, owner, url,
             one_line, bucket, urgency, action_needed, is_entrypoint, blocked}
  edges[] : {parent, child, kind}   kind in {stacked, apex, blocks}
  actions : { ref: {label, command, class} }   class in {readonly, confirm}

Buckets (section ids): needs-you, active-chains, standalone, collapsed-noise.

Annotations (machine-local, OPTIONAL, never committed) are a flat
{ ref: {when, text, source, ...} } map. If present, per-ref keys are merged
onto the matching item (shallow update) before rendering, and if a "history"
list is present it renders as a per-item expandable why/history trail. The
page MUST render fully with this file absent -- python3 stdlib only.
"""
import argparse
import datetime
import html
import json
import os
import sys
from collections import defaultdict

STATE = os.environ.get("BORG_MERGE_TREE_DIR", os.path.expanduser("~/.local/state/borg/merge-tree"))


def parse_args():
    p = argparse.ArgumentParser(description="Render the PR control hub index.html from data.json.")
    p.add_argument("--data", default=os.path.join(STATE, "data.json"), help="path to data.json")
    p.add_argument("--out", default=os.path.join(STATE, "index.html"), help="path to write index.html")
    p.add_argument("--annotations", default=os.path.join(STATE, "annotations.local.json"),
                   help="path to the optional machine-local annotations file")
    return p.parse_args()


ARGS = parse_args()
DATA = ARGS.data
ANNOT = ARGS.annotations
OUT = ARGS.out

# Annotation fields that may shallow-override an Item. Deliberately a WHITELIST:
# the raw annotation payload also carries bookkeeping keys (when/text/source/
# history), and a provenance "source" would otherwise clobber the item's own
# source ("github-pr"/"jira" -> the source badge). Only these curation-safe
# keys may be merged; identity keys (ref/source/repo/project/url/state) never.
ANNOTATION_MERGE_KEYS = {
    "note", "one_line", "action_needed", "blocked", "urgency", "owner",
    "title", "changed", "bucket", "is_entrypoint",
}


def load_annotations(path):
    """Return the machine-local annotations map, or {} on any failure.

    Isolated so a future external annotation export can be unioned in here (one merged map is
    handed to apply_annotations). The render MUST succeed with this file absent,
    empty, or malformed -- see SCHEMA.md; stdlib only.
    """
    ann = {}
    if os.path.exists(path):
        try:
            with open(path) as f:
                ann = json.load(f) or {}
        except (ValueError, OSError):
            ann = {}
    return ann if isinstance(ann, dict) else {}


def apply_annotations(rows, ann):
    """Shallow-merge whitelisted annotation keys onto each item and stash the raw
    payload under _annotation for the expandable why/history trail."""
    for it in rows:
        ov = ann.get(it.get("ref"))
        if isinstance(ov, dict):
            it["_annotation"] = ov
            it.update({k: v for k, v in ov.items() if k in ANNOTATION_MERGE_KEYS})


try:
    with open(DATA) as f:
        D = json.load(f)
except (ValueError, OSError) as exc:
    sys.exit(f"render.py: cannot read data.json at {DATA}: {exc}")

meta = D.get("meta", {})
# Skip ref-less items up front: ref is the canonical join key, and a single item
# missing one used to crash the whole render (KeyError) in both the by_ref build
# and node_html. Guard once, here, so every downstream consumer is safe.
items = [it for it in D.get("items", []) if it.get("ref")]
edges = D.get("edges", [])
actions = D.get("actions", {})

apply_annotations(items, load_annotations(ANNOT))

GEN = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S %Z").strip()
try:
    TODAY = datetime.datetime.strptime(meta.get("today", "")[:10], "%Y-%m-%d").date()
except (ValueError, TypeError):
    TODAY = datetime.date.today()

BUCKETS = ["needs-you", "active-chains", "standalone", "collapsed-noise"]
REVIEW_BUCKET = "review-queue"  # Awaiting-Noah review queue -> its own labeled tier
NOAH = {"noah-goodrich", "noah goodrich", "noahgoodrich", "noah", "ngoodrich"}


# ---------------------------------------------------------------- helpers
def esc(s):
    return html.escape(str(s if s is not None else ""))


def safe_url(url):
    """Return the url only if it uses an http/https scheme, else "".

    html.escape() neutralizes quotes/brackets but NOT the scheme, so an
    ``esc("javascript:alert(1)")`` still executes when dropped into an href.
    Allow-list the scheme before any URL reaches an anchor.
    """
    u = (url or "").strip()
    low = u.lower()
    return u if low.startswith("http://") or low.startswith("https://") else ""


def is_mine(it):
    return (it.get("owner") or "").strip().lower() in NOAH


def short_date(s):
    return (s or "")[:10]


def age_str(s):
    try:
        dt = datetime.datetime.strptime((s or "")[:10], "%Y-%m-%d").date()
    except (ValueError, TypeError):
        return short_date(s)
    d = (TODAY - dt).days
    if d <= 0:
        return "today"
    return f"{d}d"


def chip_for(it):
    """Return (css-suffix, label) for the state chip."""
    st = (it.get("state") or "").strip()
    up = st.upper()
    if it.get("blocked") and up == "OPEN":
        return ("blocked", "blocked")
    if up == "OPEN":
        return ("open", "open")
    if up == "MERGED":
        return ("merged", "merged")
    if up == "CLOSED":
        return ("merged", "closed")
    low = st.lower()
    if low in ("in review", "in progress"):
        return ("wip", st or "wip")
    if low == "done":
        return ("merged", "done")
    return ("open", st or "open")


def state_word(it):
    return ((it.get("state") or "open").split() or ["open"])[0].lower()


# edge maps
parents = defaultdict(list)      # child -> [(parent, kind)] for stacked/apex
blocks_map = defaultdict(list)   # parent -> [child] for blocks
apex_of = {}                     # child -> apex parent
for e in edges:
    k = e.get("kind")
    p, c = e.get("parent"), e.get("child")
    if not p or not c:
        continue
    if k in ("stacked", "apex"):
        parents[c].append((p, k))
        if k == "apex":
            apex_of.setdefault(c, p)
    elif k == "blocks":
        blocks_map[p].append(c)


def project_hue(project):
    """Stable hash -> hue (0-359) so the same project always gets the same color."""
    h = 0
    for ch in project or "":
        h = (h * 31 + ord(ch)) & 0xFFFFFFFF
    return h % 360


def repo_hue(repo):
    h = 0
    for ch in (repo or "")[::-1]:
        h = (h * 37 + ord(ch)) & 0xFFFFFFFF
    return h % 360


def repo_badge(it):
    label = it.get("repo") or it.get("source") or ""
    hue = repo_hue(label)
    style = f"border-color:hsl({hue},45%,40%);color:hsl({hue},60%,72%)"
    return f'<span class="badge" style="{style}">{esc(label)}</span>'


def source_badge(it):
    src = it.get("source") or ""
    kind = {"github-pr": "PR", "github-issue": "issue", "jira": "jira"}.get(src, src)
    if not kind:
        return ""
    return f'<span class="badge src src-{esc(src)}">{esc(kind)}</span>'


def data_attrs(it):
    needs_you = it.get("bucket") in ("needs-you", REVIEW_BUCKET)
    in_chain = it.get("bucket") == "active-chains"
    return (
        f'data-mine="{str(is_mine(it)).lower()}" '
        f'data-blocked="{str(bool(it.get("blocked"))).lower()}" '
        f'data-needsyou="{str(needs_you).lower()}" '
        f'data-chain="{str(in_chain).lower()}" '
        f'data-state="{esc(state_word(it))}"'
    )


def history_html(it):
    ann = it.get("_annotation") or {}
    hist = ann.get("history")
    if not hist:
        return ""
    rows = []
    for h in hist:
        if isinstance(h, dict):
            when = esc(h.get("when", ""))
            text = esc(h.get("text", ""))
            src = esc(h.get("source", ""))
            rows.append(f'<div class="hrow"><span class="hwhen">{when}</span> '
                        f'<span class="htext">{text}</span> '
                        f'<span class="hsrc">{src}</span></div>')
        else:
            rows.append(f'<div class="hrow"><span class="htext">{esc(h)}</span></div>')
    return (f'<details class="why"><summary>why / history ({len(hist)})</summary>'
            f'<div class="why-body">{"".join(rows)}</div></details>')


def node_html(it):
    st = (it.get("state") or "").upper()
    cls = ["node"]
    if st in ("MERGED", "CLOSED", "DONE") or (it.get("state") or "").lower() == "done":
        cls.append("merged")
    if it.get("blocked"):
        cls.append("blocked")
    if it.get("bucket") == "needs-you":
        cls.append("needsyou")
    if it.get("is_entrypoint"):
        cls.append("entry")

    project_style = f'style="border-left-color:hsl({project_hue(it.get("project"))},55%,50%)"'

    arrow = ('<span class="arrow" title="entrypoint / next action">&#9656;</span>'
             if it.get("is_entrypoint") else '<span class="arrow-sp"></span>')
    flag = ('<span class="flag" title="needs you">&#9873;</span>'
            if it.get("bucket") == "needs-you" else "")
    chip_cls, chip_lbl = chip_for(it)
    chip = f'<span class="chip chip-{chip_cls}">{esc(chip_lbl)}</span>'
    owner = it.get("owner") or ""
    author = f'<span class="author">@{esc(owner)}</span>' if owner else ""
    urg = it.get("urgency")
    urgbadge = f'<span class="urg" title="urgency">{esc(urg)}</span>' if isinstance(urg, (int, float)) else ""

    # meta relations from edges
    ref = it["ref"]
    meta_bits = []
    if apex_of.get(ref):
        meta_bits.append(f'apex&nbsp;<span class="apexh">{esc(apex_of[ref])}</span>')
    deps = [p for (p, k) in parents.get(ref, []) if k == "stacked"]
    if deps:
        meta_bits.append("&larr;&nbsp;" + ", ".join(esc(d) for d in deps))
    if blocks_map.get(ref):
        meta_bits.append("blocks&nbsp;" + ", ".join(esc(b) for b in blocks_map[ref]))
    metaline = f'<div class="metaline">{" &middot; ".join(meta_bits)}</div>' if meta_bits else ""

    # action + command
    act = actions.get(ref) or {}
    label = act.get("label") or it.get("action_needed")
    action = f'<div class="action">{esc(label)}</div>' if label else ""
    cmd_html = ""
    if act.get("command"):
        acls = esc(act.get("class") or "readonly")
        cmd_html = (f'<div class="cmd cmd-{acls}" title="{acls} command">'
                    f'<span class="cmd-cls">{acls}</span>'
                    f'<code>{esc(act["command"])}</code></div>')

    note = ""
    one = it.get("one_line") or it.get("note")
    if one:
        note = f'<div class="note">{esc(one)}</div>'

    url = safe_url(it.get("url"))
    handle = (f'<a class="handle" href="{esc(url)}" target="_blank" rel="noopener">{esc(ref)}</a>'
              if url else f'<span class="handle">{esc(ref)}</span>')
    title = it.get("title") or ""
    title_html = (f'<a class="title" href="{esc(url)}" target="_blank" rel="noopener">{esc(title)}</a>'
                  if url else f'<span class="title">{esc(title)}</span>')

    return f"""
      <div class="{' '.join(cls)}" {project_style} {data_attrs(it)}>
        <div class="node-top">
          {arrow}{flag}
          {handle}
          {repo_badge(it)}{source_badge(it)}
          {chip}
          {urgbadge}
          {title_html}
          {author}
          <span class="upd">{esc(age_str(it.get("changed")))}</span>
        </div>
        {action}{cmd_html}{metaline}{note}{history_html(it)}
      </div>"""


# ---------------------------------------------------------------- bucketing
buckets = {b: [] for b in BUCKETS + [REVIEW_BUCKET]}
for it in items:
    b = it.get("bucket")
    if b in buckets:
        buckets[b].append(it)
    else:
        buckets["standalone"].append(it)

needs_you = sorted(buckets["needs-you"],
                   key=lambda it: (-(it.get("urgency") or 0), it.get("ref", "")))


def group_by_project(rows):
    order, groups = [], {}
    for it in rows:
        proj = it.get("project") or "misc / infra"
        if proj not in groups:
            groups[proj] = []
            order.append(proj)
        groups[proj].append(it)
    # order projects by max urgency desc, then name
    order.sort(key=lambda p: (-max((r.get("urgency") or 0) for r in groups[p]), p.lower()))
    for p in order:
        groups[p].sort(key=lambda it: (-(it.get("urgency") or 0), it.get("ref", "")))
    return order, groups


chain_order, chain_groups = group_by_project(buckets["active-chains"])
stand_order, stand_groups = group_by_project(buckets["standalone"])

noise = sorted(buckets["collapsed-noise"],
               key=lambda it: (it.get("repo", ""), it.get("ref", "")))


# ---------------------------------------------------------------- counts
def count(pred):
    return sum(1 for it in items if pred(it))


counts = {
    "open": count(lambda it: (it.get("state") or "").upper() == "OPEN"),
    "merged": count(lambda it: (it.get("state") or "").upper() == "MERGED"),
    "blocked": count(lambda it: bool(it.get("blocked"))),
    "jira": count(lambda it: it.get("source") == "jira"),
    "noise": len(buckets["collapsed-noise"]),
    "needs_you": len(buckets["needs-you"]),
}

# ---------------------------------------------------------------- HTML build
sections = []

# ---- needs-you hero
hero_nodes = "\n".join(node_html(it) for it in needs_you)
sections.append(f"""
  <section id="needs-you" class="hero">
    <h2><span class="tiernum">1</span> What needs you now <span class="cnt">{len(needs_you)}</span></h2>
    <div class="hero-body">{hero_nodes}</div>
  </section>""")

# ---- awaiting-noah review queue (its own labeled tier, right under the hero)
review_q = sorted(buckets[REVIEW_BUCKET],
                  key=lambda it: (-(it.get("urgency") or 0), it.get("ref", "")))
if review_q:
    review_nodes = "\n".join(node_html(it) for it in review_q)
    sections.append(f"""
  <section id="review-queue" class="reviewq">
    <h2><span class="tiernum tiernum-r">R</span> Awaiting Noah / review queue <span class="cnt">{len(review_q)}</span></h2>
    <div class="reviewq-sub">warehouse-permissions PRs to review before they go to Kelly &middot; + program apexes for nav</div>
    <div class="reviewq-body">{review_nodes}</div>
  </section>""")


def proj_details(order, groups, open_live=True):
    blocks = []
    for proj in order:
        rows = groups[proj]
        live = any((r.get("state") or "").upper() == "OPEN" for r in rows)
        openattr = " open" if (live and open_live) else ""
        hue = project_hue(proj)
        inner = "\n".join(node_html(r) for r in rows)
        blocks.append(f"""
    <details class="proj"{openattr}>
      <summary style="border-left:3px solid hsl({hue},55%,50%)">{esc(proj)} <span class="pcount">{len(rows)}</span></summary>
      {inner}
    </details>""")
    return "".join(blocks)


# ---- active-chains
sections.append(f"""
  <section id="active-chains">
    <h2><span class="tiernum">2</span> Active chains <span class="cnt">{len(buckets['active-chains'])}</span></h2>
    {proj_details(chain_order, chain_groups)}
  </section>""")

# ---- standalone
sections.append(f"""
  <section id="standalone">
    <h2><span class="tiernum">3</span> Standalone open <span class="cnt">{len(buckets['standalone'])}</span></h2>
    {proj_details(stand_order, stand_groups)}
  </section>""")

# ---- collapsed-noise
noise_rows = "\n".join(node_html(it) for it in noise)
sections.append(f"""
  <section id="collapsed-noise">
    <details class="noise">
      <summary><span class="tiernum">4</span> Noise &mdash; stale bots + merged/closed + low-signal <span class="cnt">{len(noise)}</span></summary>
      <div class="noise-body">{noise_rows}</div>
    </details>
  </section>""")

# ---- health strip (tri-state: ok=green / warn=amber / down=red, + machine + when)
HEALTH_DOT = {"ok": "var(--green)", "warn": "var(--wip)", "down": "var(--red)"}
health_bits = []
for h in meta.get("health", []):
    status = (h.get("status") or "down").lower()
    dot = HEALTH_DOT.get(status, "var(--wip)")
    where = esc(h.get("machine") or "")
    when = short_date(h.get("checked_at"))
    stamp = " &middot; ".join(x for x in (where, when) if x)
    stamp_html = f' <span class="hstamp">({stamp})</span>' if stamp else ""
    health_bits.append(
        f'<span class="hchk" title="{esc(status)}"><span class="dot" style="background:{dot}"></span>'
        f'{esc(h.get("check"))}: {esc(h.get("detail"))}{stamp_html}</span>')
health_html = " ".join(health_bits)

# ---- project + repo legend (color-coding key)
legend_projects = sorted({it.get("project") for it in items if it.get("project")})
legend_repos = sorted({it.get("repo") for it in items if it.get("repo")})
proj_legend_bits = "".join(
    f'<span><span class="dot" style="background:hsl({project_hue(p)},55%,50%)"></span>{esc(p)}</span>'
    for p in legend_projects)
repo_legend_bits = "".join(
    f'<span class="badge" style="border-color:hsl({repo_hue(r)},45%,40%);color:hsl({repo_hue(r)},60%,72%)">{esc(r)}</span>'
    for r in legend_repos)

pills = f"""
    <span class="pill p-open">{counts['open']} open</span>
    <span class="pill p-wip">{counts['jira']} jira</span>
    <span class="pill p-blocked">{counts['blocked']} blocked</span>
    <span class="pill p-merged">{counts['merged']} merged</span>
    <span class="pill p-noise">{counts['noise']} noise</span>
    <span class="pill p-you">{counts['needs_you']} needs&nbsp;you &#9873;</span>"""

CSS = """
:root{
  --bg:#0d1117; --panel:#161b22; --panel2:#0f141a; --bd:#30363d; --tx:#c9d1d9;
  --muted:#8b949e; --merged:#6e7681; --draft:#58a6ff; --wip:#d29922; --red:#f85149;
  --green:#3fb950; --you:#e3b341; --acc:#1f6feb;
}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--tx);
  font:14px/1.45 ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;padding:0 0 60px}
a{color:inherit;text-decoration:none}
a:hover{text-decoration:underline}
header{position:sticky;top:0;z-index:20;background:linear-gradient(180deg,#0d1117,#0d1117f0);
  border-bottom:1px solid var(--bd);padding:14px 20px 10px;backdrop-filter:blur(4px)}
h1{font-size:16px;margin:0 0 4px;letter-spacing:.5px}
h1 .sub{color:var(--muted);font-weight:400;font-size:12px;margin-left:10px}
.pills{margin:8px 0 6px;display:flex;flex-wrap:wrap;gap:6px}
.pill{padding:2px 9px;border-radius:12px;font-size:12px;border:1px solid var(--bd);background:var(--panel)}
.p-open{color:var(--tx)} .p-draft{color:var(--draft)} .p-wip{color:var(--wip)}
.p-blocked{color:var(--red)} .p-merged{color:var(--merged)} .p-noise{color:var(--muted)}
.p-you{color:var(--you);border-color:var(--you)}
.bar{display:flex;flex-wrap:wrap;gap:6px;align-items:center;margin-top:6px}
.fbtn{cursor:pointer;padding:3px 12px;border-radius:6px;border:1px solid var(--bd);
  background:var(--panel);color:var(--muted);font-size:12px}
.fbtn.on{background:var(--acc);color:#fff;border-color:var(--acc)}
.legend{margin-left:auto;display:flex;gap:12px;flex-wrap:wrap;color:var(--muted);font-size:11px}
.legend span{white-space:nowrap}
.dot{display:inline-block;width:9px;height:9px;border-radius:50%;margin-right:3px;vertical-align:middle}
.health{margin-top:6px;display:flex;flex-wrap:wrap;gap:14px;color:var(--muted);font-size:11px}
.hchk{white-space:nowrap;max-width:100%;overflow:hidden;text-overflow:ellipsis}
.hstamp{opacity:.6}
.projlegend,.repolegend{margin-top:6px;display:flex;flex-wrap:wrap;gap:8px;color:var(--muted);font-size:11px;align-items:center}
main{padding:16px 20px;max-width:1200px;margin:0 auto}
section{margin-bottom:26px}
h2{font-size:14px;border-bottom:1px solid var(--bd);padding-bottom:5px;
  display:flex;align-items:center;gap:8px}
.tiernum{background:var(--acc);color:#fff;border-radius:5px;width:20px;height:20px;
  display:inline-flex;align-items:center;justify-content:center;font-size:12px}
.cnt{color:var(--muted);font-weight:400;font-size:12px}
.hero{background:var(--panel);border:1px solid var(--you);border-radius:8px;padding:6px 14px 12px}
.hero h2{border-color:#2b2a1f}
.hero .tiernum{background:var(--you);color:#000}
.reviewq{background:var(--panel);border:1px solid var(--acc);border-radius:8px;padding:6px 14px 12px}
.reviewq h2{border-color:#1c2a44}
.reviewq .tiernum-r{background:var(--you);color:#000}
.reviewq-sub{color:var(--muted);font-size:11px;margin:4px 0 8px}
.node{border:1px solid var(--bd);border-left:3px solid var(--bd);border-radius:6px;padding:7px 10px;margin:6px 0;background:var(--panel)}
.node.merged{opacity:.5;background:var(--panel2)}
.node.merged .title,.node.merged .handle{text-decoration:line-through;color:var(--merged)}
.node.blocked{border-left:3px solid var(--red)!important}
.node.needsyou{background:#1a1710}
.node.entry{box-shadow:0 0 0 1px var(--green) inset}
.node.ext{opacity:.4}
.node-top{display:flex;align-items:center;gap:8px;flex-wrap:wrap}
.arrow{color:var(--green);font-weight:700} .arrow-sp{display:inline-block;width:9px}
.flag{color:var(--you)}
.handle{font-weight:700;color:var(--acc);background:#0d1117;border:1px solid var(--bd);
  border-radius:5px;padding:1px 6px;font-size:12px}
.badge{font-size:10px;color:var(--muted);border:1px solid var(--bd);border-radius:4px;padding:0 5px;text-transform:lowercase}
.badge.src{color:var(--acc);border-color:#1f3a5a}
.badge.src-jira{color:var(--green);border-color:#1f3a26}
.badge.src-github-issue{color:var(--wip);border-color:#3a2f14}
.chip{font-size:10px;text-transform:uppercase;letter-spacing:.4px;padding:1px 6px;border-radius:10px;border:1px solid}
.chip-open{color:var(--tx);border-color:var(--bd)}
.chip-draft{color:var(--draft);border-color:var(--draft)}
.chip-wip{color:var(--wip);border-color:var(--wip)}
.chip-blocked{color:var(--red);border-color:var(--red)}
.chip-merged{color:var(--merged);border-color:var(--merged)}
.urg{font-size:10px;color:var(--muted);border:1px solid var(--bd);border-radius:8px;padding:0 5px}
.title{flex:1;min-width:220px}
.author{color:var(--muted);font-size:11px}
.upd{color:var(--muted);font-size:11px}
.action{color:var(--you);font-size:12px;margin:5px 0 0 26px;padding-left:8px;border-left:2px solid var(--you)}
.cmd{margin:4px 0 0 26px;display:flex;align-items:center;gap:8px;font-size:11px}
.cmd code{background:#0d1117;border:1px solid var(--bd);border-radius:5px;padding:2px 7px;color:var(--tx);
  white-space:pre-wrap;word-break:break-all}
.cmd-cls{font-size:9px;text-transform:uppercase;letter-spacing:.4px;border-radius:8px;padding:1px 6px;border:1px solid}
.cmd-readonly .cmd-cls{color:var(--green);border-color:#1f3a26}
.cmd-confirm .cmd-cls{color:var(--you);border-color:var(--you)}
.metaline{color:var(--muted);font-size:11px;margin:3px 0 0 26px}
.note{color:var(--muted);font-size:11px;font-style:italic;margin:3px 0 0 26px}
.apexh{color:var(--green)}
.why{margin:4px 0 0 26px;font-size:11px}
.why>summary{cursor:pointer;color:var(--muted);list-style:none}
.why>summary::-webkit-details-marker{display:none}
.why>summary:before{content:"\\25B8 ";}
.why[open]>summary:before{content:"\\25BE ";}
.why-body{margin-top:4px;padding-left:10px;border-left:2px solid var(--bd)}
.hrow{color:var(--muted);margin:2px 0}
.hwhen{color:var(--tx);font-weight:600;margin-right:6px}
.hsrc{opacity:.6;margin-left:6px}
details.proj{border:1px solid var(--bd);border-radius:8px;margin:10px 0;background:var(--panel2);overflow:hidden}
details.proj>summary{cursor:pointer;padding:9px 12px;font-weight:700;list-style:none;background:var(--panel)}
details.proj>summary::-webkit-details-marker{display:none}
details.proj>summary:before{content:"\\25B8 ";color:var(--muted)}
details.proj[open]>summary:before{content:"\\25BE "}
.pcount{color:var(--muted);font-weight:400;font-size:11px;margin-left:6px}
details.noise{border:1px solid var(--bd);border-radius:8px;background:var(--panel2)}
details.noise>summary{cursor:pointer;padding:10px 12px;color:var(--muted)}
.noise-body{padding:0 12px 10px}
.node.hide{display:none}
details.hide,section.hide{display:none}
footer{color:var(--muted);font-size:11px;text-align:center;margin-top:30px}
"""

JS = """
const btns=[...document.querySelectorAll('.fbtn')];
function apply(f){
  btns.forEach(b=>b.classList.toggle('on',b.dataset.f===f));
  document.querySelectorAll('.node').forEach(n=>{
    let show=true;
    if(f==='mine')        show=n.dataset.mine==='true';
    else if(f==='you')    show=n.dataset.needsyou==='true';
    else if(f==='blocked')show=n.dataset.blocked==='true';
    else if(f==='chains') show=n.dataset.chain==='true' && n.dataset.state==='open';
    n.classList.toggle('hide',!show);
  });
  document.querySelectorAll('details.proj, details.noise').forEach(d=>{
    const any=[...d.querySelectorAll('.node')].some(n=>!n.classList.contains('hide'));
    d.classList.toggle('hide',!any);
    if(f!=='all'&&any)d.open=true;
  });
  document.querySelectorAll('section').forEach(s=>{
    const any=[...s.querySelectorAll('.node')].some(n=>!n.classList.contains('hide'));
    s.classList.toggle('hide',!any);
  });
}
btns.forEach(b=>b.addEventListener('click',()=>apply(b.dataset.f)));
document.querySelectorAll('.cmd code').forEach(c=>{
  c.style.cursor='copy';
  c.title='click to copy';
  c.addEventListener('click',()=>{navigator.clipboard&&navigator.clipboard.writeText(c.textContent);});
});
apply('all');
"""

repos_n = len(meta.get("repos", []))
html_doc = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>PR Control Hub</title>
<style>{CSS}</style></head><body>
<header>
  <h1>PR CONTROL HUB <span class="sub">cross-repo merge tree &middot; {len(items)} items across {repos_n} repos &middot; {esc(meta.get('machine',''))} &middot; <a href="graph.html">Graph view &rarr;</a></span></h1>
  <div class="pills">{pills}</div>
  <div class="bar">
    <button class="fbtn on" data-f="all">All</button>
    <button class="fbtn" data-f="mine">Mine</button>
    <button class="fbtn" data-f="you">Needs you</button>
    <button class="fbtn" data-f="blocked">Blocked</button>
    <button class="fbtn" data-f="chains">Active-chains</button>
    <div class="legend">
      <span><span class="dot" style="background:var(--you)"></span>needs you &#9873;</span>
      <span><span class="dot" style="background:var(--green)"></span>&#9656; entrypoint/next</span>
      <span><span class="dot" style="background:var(--wip)"></span>wip / in-review</span>
      <span><span class="dot" style="background:var(--red)"></span>blocked / changes-req</span>
      <span><span class="dot" style="background:var(--merged)"></span>merged (struck)</span>
      <span>gen {esc(GEN)}</span>
    </div>
  </div>
  <div class="health">{health_html}</div>
  <div class="projlegend"><span>project:</span>{proj_legend_bits}</div>
  <div class="repolegend"><span>repo:</span>{repo_legend_bits}</div>
</header>
<main>
{''.join(sections)}
<footer>generated {esc(GEN)} &middot; data gathered {esc(meta.get('gathered_at',''))}
&middot; machine {esc(meta.get('machine',''))} &middot; source: data.json (curated recon artifact)</footer>
</main>
<script>{JS}</script>
</body></html>"""

with open(OUT, "w") as f:
    f.write(html_doc)

print("wrote", OUT)
print("per-bucket rows:", {b: len(buckets[b]) for b in BUCKETS})
print("bytes:", os.path.getsize(OUT))
