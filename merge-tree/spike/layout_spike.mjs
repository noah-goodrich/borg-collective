// SESSION-1 KILL-TEST: graph-v3 "Frozen Atlas, Living Lens" -- full-scale one-shot ELK layout.
// Builds the compound graph (project -> workstream -> item) from the REAL story.json + data.json,
// runs ELK layered/INCLUDE_CHILDREN at BOTH altitudes (expanded, collapsed-default), renders static
// dark-theme SVG+HTML, and measures the legibility envelope from the recommendation doc.
//
// Usage: node layout_spike.mjs
import ELK from "elkjs/lib/elk.bundled.js";
import { readFileSync, writeFileSync, mkdirSync } from "fs";
import { fileURLToPath } from "url";
import path from "path";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DATA_DIR = "/Users/noahgoodrich/.local/state/borg/merge-tree";
const OUT_DIR = __dirname;

const story = JSON.parse(readFileSync(path.join(DATA_DIR, "story.json"), "utf8"));
const data = JSON.parse(readFileSync(path.join(DATA_DIR, "data.json"), "utf8"));

const elk = new ELK();

// ---------- project hue palette (8 distinguishable dark-theme hues) ----------
const PROJECT_HUES = [200, 30, 320, 140, 260, 0, 170, 60];

// ---------- 1. index data.json items by ref ----------
const itemByRef = new Map();
for (const it of data.items) itemByRef.set(it.ref, it);

// ---------- 2. build ref -> workstream-node-id map from story.json (first pass) ----------
const refToWsId = new Map();
const refPrefixToProjectIdx = new Map();

function refPrefix(ref) {
  const m = ref.match(/^([A-Za-z][\w.-]*)#/);
  if (m) return m[1];
  const m2 = ref.match(/^([A-Za-z]+)-\d+/);
  if (m2) return m2[1];
  return "OTHER";
}

story.projects.forEach((p, pi) => {
  p.workstreams.forEach((w, wi) => {
    const wsId = `ws:${pi}:${wi}`;
    for (const ref of w.items || []) {
      refToWsId.set(ref, wsId);
      const pre = refPrefix(ref);
      if (!refPrefixToProjectIdx.has(pre)) refPrefixToProjectIdx.set(pre, pi);
    }
  });
});

// ---------- 3. find orphan refs: appear in data.json edges but not in any workstream.items ----------
const allEdgeRefs = new Set();
for (const e of data.edges) {
  allEdgeRefs.add(e.parent);
  allEdgeRefs.add(e.child);
}
const orphanRefs = [...allEdgeRefs].filter((r) => !refToWsId.has(r));

// bucket orphans into a synthetic "unassigned" workstream per project (by prefix match), else a
// global orphan project.
const orphanWsIdByProject = new Map(); // pi -> wsId
const GLOBAL_ORPHAN_PROJECT_IDX = story.projects.length; // synthetic 9th container
let orphanCounter = 0;

function orphanHomeProjectIdx(ref) {
  const pre = refPrefix(ref);
  if (refPrefixToProjectIdx.has(pre)) return refPrefixToProjectIdx.get(pre);
  return GLOBAL_ORPHAN_PROJECT_IDX;
}

for (const ref of orphanRefs) {
  const pi = orphanHomeProjectIdx(ref);
  if (!orphanWsIdByProject.has(pi)) {
    orphanWsIdByProject.set(pi, `ws:${pi}:orphan`);
  }
  refToWsId.set(ref, orphanWsIdByProject.get(pi));
}

console.log(`[spike] orphan refs (in edges, not in any workstream.items): ${orphanRefs.length}`);
console.log(`[spike] orphan homes created: ${orphanWsIdByProject.size}`);

// ---------- 4. build the EXPANDED compound tree (project -> workstream -> item leaves) ----------
function projectLabel(pi) {
  if (pi === GLOBAL_ORPHAN_PROJECT_IDX) return "unassigned (orphan refs)";
  return story.projects[pi].name;
}
function projectId(pi) {
  if (pi === GLOBAL_ORPHAN_PROJECT_IDX) return "proj:orphan";
  return `proj:${story.projects[pi].id}`;
}

const LEAF_W = 170;
const LEAF_H = 40;
const WS_HEADER_H = 30;

function leafNode(ref) {
  const it = itemByRef.get(ref);
  const stub = !it;
  return {
    id: ref,
    width: LEAF_W,
    height: LEAF_H,
    labels: [{ text: stub ? `${ref} (stub)` : ref }],
    _meta: { stub, item: it || null },
  };
}

const expandedChildren = [];
const allProjectIdxs = [...story.projects.map((_, i) => i)];
if (orphanWsIdByProject.size > 0) allProjectIdxs.push(GLOBAL_ORPHAN_PROJECT_IDX);

for (const pi of allProjectIdxs) {
  const wsNodes = [];
  if (pi < story.projects.length) {
    story.projects[pi].workstreams.forEach((w, wi) => {
      const wsId = `ws:${pi}:${wi}`;
      const leaves = (w.items || []).map(leafNode);
      wsNodes.push({
        id: wsId,
        labels: [{ text: w.title }],
        layoutOptions: {
          "elk.padding": "[top=30,left=10,bottom=10,right=10]",
          "elk.algorithm": "layered",
          "elk.direction": "RIGHT",
        },
        children: leaves.length ? leaves : [leafNode(`${wsId}:__empty__`)],
        _meta: { kind: "workstream", state: w.state, title: w.title },
      });
    });
  }
  if (orphanWsIdByProject.has(pi)) {
    const wsId = orphanWsIdByProject.get(pi);
    const leaves = orphanRefs.filter((r) => refToWsId.get(r) === wsId).map(leafNode);
    wsNodes.push({
      id: wsId,
      labels: [{ text: "(unassigned refs)" }],
      layoutOptions: { "elk.padding": "[top=30,left=10,bottom=10,right=10]" },
      children: leaves,
      _meta: { kind: "workstream", state: "n/a", title: "(unassigned refs)" },
    });
  }
  expandedChildren.push({
    id: projectId(pi),
    labels: [{ text: projectLabel(pi) }],
    layoutOptions: {
      "elk.padding": "[top=40,left=15,bottom=15,right=15]",
    },
    children: wsNodes,
    _meta: { kind: "project", hue: PROJECT_HUES[pi % PROJECT_HUES.length], idx: pi },
  });
}

// ---------- 5. edges ----------
// 5a. the 72 typed data.json edges (item -> item)
const typedEdges = data.edges.map((e, i) => ({
  id: `edge:typed:${i}`,
  sources: [e.parent],
  targets: [e.child],
  _meta: { kind: e.kind, typed: true },
}));

// 5b. synthesized workstream-level blocked_by edges from story.json prose, where a ref is named
const REF_RE = /\b([A-Za-z][\w.-]*#\d+|DE-\d+)\b/g;
const synthEdges = [];
story.projects.forEach((p, pi) => {
  p.workstreams.forEach((w, wi) => {
    const srcWsId = `ws:${pi}:${wi}`;
    for (const prose of w.blocked_by || []) {
      const matches = [...prose.matchAll(REF_RE)].map((m) => m[1]);
      for (const ref of matches) {
        const targetWsId = refToWsId.get(ref);
        if (!targetWsId || targetWsId === srcWsId) continue;
        synthEdges.push({
          id: `edge:synth:${synthEdges.length}`,
          sources: [srcWsId],
          targets: [targetWsId],
          _meta: { kind: "blocks", typed: false, synthesized: true },
        });
      }
    }
  });
});

console.log(`[spike] typed edges: ${typedEdges.length}, synthesized ws blocked_by edges: ${synthEdges.length}`);

const expandedEdges = [...typedEdges, ...synthEdges];

// ---------- 6. run ELK: EXPANDED altitude ----------
const expandedGraph = {
  id: "root",
  layoutOptions: {
    "elk.algorithm": "layered",
    "elk.hierarchyHandling": "INCLUDE_CHILDREN",
    "elk.layered.mergeHierarchyEdges": "true",
    "elk.direction": "RIGHT",
    "elk.spacing.nodeNode": "20",
    "elk.layered.spacing.nodeNodeBetweenLayers": "60",
    "elk.spacing.edgeNode": "15",
  },
  children: expandedChildren,
  edges: expandedEdges,
};

async function run() {
  const t0 = Date.now();
  let expandedLayout;
  let expandedError = null;
  try {
    expandedLayout = await elk.layout(expandedGraph);
  } catch (e) {
    expandedError = String(e && e.stack ? e.stack : e);
  }
  const t1 = Date.now();
  const expandedBuildMs = t1 - t0;
  console.log(`[spike] EXPANDED layout build: ${expandedBuildMs}ms, error=${expandedError ? "YES" : "no"}`);
  if (expandedError) console.log(expandedError);

  // ---------- 7. build the COLLAPSED-DEFAULT altitude: workstreams collapsed to header nodes ----------
  const WS_COLLAPSED_W = 220;
  const WS_COLLAPSED_H = 46;

  // count cross-workstream typed edges lifted to their container ws ids
  function liftEndpoint(ref) {
    return refToWsId.get(ref) || ref;
  }
  const liftedCounts = new Map(); // "src->tgt:kind" -> count
  const liftedMeta = new Map();
  for (const e of typedEdges) {
    const s = liftEndpoint(e.sources[0]);
    const t = liftEndpoint(e.targets[0]);
    if (s === t) continue; // internal to a collapsed workstream, no longer visible
    const key = `${s}->${t}:${e._meta.kind}`;
    liftedCounts.set(key, (liftedCounts.get(key) || 0) + 1);
    liftedMeta.set(key, { s, t, kind: e._meta.kind });
  }
  // synthesized edges are already ws-level; fold in too (count 1 each, same key scheme)
  for (const e of synthEdges) {
    const s = e.sources[0];
    const t = e.targets[0];
    const key = `${s}->${t}:${e._meta.kind}`;
    liftedCounts.set(key, (liftedCounts.get(key) || 0) + 1);
    liftedMeta.set(key, { s, t, kind: e._meta.kind });
  }

  const collapsedEdges = [...liftedCounts.entries()].map(([key, count], i) => {
    const m = liftedMeta.get(key);
    return {
      id: `edge:collapsed:${i}`,
      sources: [m.s],
      targets: [m.t],
      labels: [{ text: count > 1 ? `${count}` : "" }],
      _meta: { kind: m.kind, stubCount: count },
    };
  });

  const collapsedChildren = [];
  for (const pi of allProjectIdxs) {
    const wsHeaders = [];
    if (pi < story.projects.length) {
      story.projects[pi].workstreams.forEach((w, wi) => {
        wsHeaders.push({
          id: `ws:${pi}:${wi}`,
          width: WS_COLLAPSED_W,
          height: WS_COLLAPSED_H,
          labels: [{ text: w.title }],
          _meta: { kind: "workstream-header", state: w.state, title: w.title },
        });
      });
    }
    if (orphanWsIdByProject.has(pi)) {
      const wsId = orphanWsIdByProject.get(pi);
      wsHeaders.push({
        id: wsId,
        width: WS_COLLAPSED_W,
        height: WS_COLLAPSED_H,
        labels: [{ text: "(unassigned refs)" }],
        _meta: { kind: "workstream-header", state: "n/a", title: "(unassigned refs)" },
      });
    }
    collapsedChildren.push({
      id: projectId(pi),
      labels: [{ text: projectLabel(pi) }],
      layoutOptions: { "elk.padding": "[top=40,left=15,bottom=15,right=15]" },
      children: wsHeaders,
      _meta: { kind: "project", hue: PROJECT_HUES[pi % PROJECT_HUES.length], idx: pi },
    });
  }

  const collapsedGraph = {
    id: "root",
    layoutOptions: {
      "elk.algorithm": "layered",
      "elk.hierarchyHandling": "INCLUDE_CHILDREN",
      "elk.layered.mergeHierarchyEdges": "true",
      "elk.direction": "RIGHT",
      "elk.spacing.nodeNode": "30",
      "elk.layered.spacing.nodeNodeBetweenLayers": "80",
      "elk.spacing.edgeNode": "20",
    },
    children: collapsedChildren,
    edges: collapsedEdges,
  };

  const t2 = Date.now();
  let collapsedLayout;
  let collapsedError = null;
  try {
    collapsedLayout = await elk.layout(collapsedGraph);
  } catch (e) {
    collapsedError = String(e && e.stack ? e.stack : e);
  }
  const t3 = Date.now();
  const collapsedBuildMs = t3 - t2;
  console.log(`[spike] COLLAPSED layout build: ${collapsedBuildMs}ms, error=${collapsedError ? "YES" : "no"}`);
  if (collapsedError) console.log(collapsedError);

  // ---------- 8. measurements + SVG rendering ----------
  const results = {
    expanded: {
      buildMs: expandedBuildMs,
      error: expandedError,
      edgeCount: expandedEdges.length,
      layout: expandedLayout,
    },
    collapsed: {
      buildMs: collapsedBuildMs,
      error: collapsedError,
      edgeCount: collapsedEdges.length,
      layout: collapsedLayout,
    },
  };

  for (const [name, r] of Object.entries(results)) {
    if (r.error || !r.layout) {
      console.log(`[spike] ${name}: SKIPPING render, layout failed`);
      continue;
    }
    const { svg, metrics } = renderSvg(r.layout, name);
    writeFileSync(path.join(OUT_DIR, `${name}.svg`), svg);
    writeFileSync(path.join(OUT_DIR, `${name}.html`), wrapHtml(svg, name, metrics));
    r.metrics = metrics;
    console.log(`[spike] ${name}: canvas ${metrics.canvasW}x${metrics.canvasH}, zoomSpan=${metrics.zoomSpan.toFixed(2)}x`);
  }

  // ---------- STEP 3: perturbation drift at full scale, both altitudes ----------
  // Simulate daily churn: remove 5 random real items, add 5 new stub items, flip 6 workstream
  // states. Re-run with previous-position anchoring: elk.interactive=true (position hints from
  // run 1) + org.eclipse.elk.layered.considerModelOrder.strategy=NODES_AND_EDGES (elkjs supports
  // both as plain string layoutOptions; documented here since the recommendation asks what we used).
  function absPositionMap(layout) {
    const acc = [];
    collectAllNodes(layout, acc, 0, 0, 0);
    const m = new Map();
    for (const { node, absX, absY } of acc) m.set(node.id, { x: absX, y: absY, w: node.width, h: node.height });
    return m;
  }

  function driftTest(baselineLayout, baseChildren, baseEdges, label) {
    if (!baselineLayout) return { label, skipped: true, reason: "baseline layout failed" };
    const basePos = absPositionMap(baselineLayout);

    // collect all leaf refs present in the baseline (real items only, exclude workstream/project containers)
    const realLeafRefs = [];
    (function walk(nodes) {
      for (const n of nodes || []) {
        if (n._meta && n._meta.kind === undefined && !n._meta.stub) realLeafRefs.push(n.id);
        if (n.children) walk(n.children);
      }
    })(baseChildren);

    const rng = mulberry32(42); // fixed seed, reproducible churn
    function pick(arr, n) {
      const copy = [...arr];
      const out = [];
      for (let i = 0; i < n && copy.length; i++) {
        const idx = Math.floor(rng() * copy.length);
        out.push(copy.splice(idx, 1)[0]);
      }
      return out;
    }

    const toRemove = new Set(pick(realLeafRefs, 5));
    const toAdd = ["CHURN-STUB-1", "CHURN-STUB-2", "CHURN-STUB-3", "CHURN-STUB-4", "CHURN-STUB-5"];
    const flippableWs = [];
    (function walk(nodes) {
      for (const n of nodes || []) {
        if (n._meta && (n._meta.kind === "workstream" || n._meta.kind === "workstream-header")) flippableWs.push(n);
        if (n.children) walk(n.children);
      }
    })(baseChildren);
    const toFlip = pick(flippableWs, 6);
    const states = ["done", "in-flight", "blocked"];
    for (const wsNode of toFlip) {
      const cur = wsNode._meta.state;
      wsNode._meta.state = states.find((s) => s !== cur) || "in-flight";
    }

    // clone children deep enough to mutate leaf lists, dropping removed + appending added under
    // the first non-empty workstream container we encounter (churn lands somewhere real).
    let addedTarget = null;
    function mutate(nodes) {
      const out = [];
      for (const n of nodes) {
        if (toRemove.has(n.id)) continue; // dropped
        const clone = { ...n };
        if (n.children) clone.children = mutate(n.children);
        if (!addedTarget && clone.children && clone._meta && clone._meta.kind === "workstream") {
          addedTarget = clone;
        }
        out.push(clone);
      }
      return out;
    }
    const mutatedChildren = mutate(baseChildren);
    if (addedTarget) {
      for (const ref of toAdd) {
        addedTarget.children.push({
          id: ref,
          width: LEAF_W,
          height: LEAF_H,
          labels: [{ text: `${ref} (new)` }],
          _meta: { stub: true, item: null },
        });
      }
    }

    // drop edges touching removed refs
    const mutatedEdges = baseEdges.filter((e) => !toRemove.has(e.sources[0]) && !toRemove.has(e.targets[0]));

    // apply position hints (anchoring) to every surviving node: set x/y from baseline, mark interactive
    function applyHints(nodes) {
      for (const n of nodes) {
        const pos = basePos.get(n.id);
        if (pos) {
          n.x = pos.x;
          n.y = pos.y;
        }
        if (n.children) applyHints(n.children);
      }
    }
    applyHints(mutatedChildren);

    return { mutatedChildren, mutatedEdges, toRemove: [...toRemove], toAdd, flippedCount: toFlip.length };
  }

  function mulberry32(seed) {
    let a = seed;
    return function () {
      a |= 0;
      a = (a + 0x6d2b79f5) | 0;
      let t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  async function runDrift(baselineLayout, baseChildren, baseEdges, baseLayoutOptions, label) {
    const prep = driftTest(baselineLayout, baseChildren, baseEdges, label);
    if (prep.skipped) return prep;
    const graph = {
      id: "root",
      layoutOptions: {
        ...baseLayoutOptions,
        "elk.interactive": "true",
        "org.eclipse.elk.layered.considerModelOrder.strategy": "NODES_AND_EDGES",
      },
      children: prep.mutatedChildren,
      edges: prep.mutatedEdges,
    };
    const t0 = Date.now();
    let layout2;
    let error = null;
    try {
      layout2 = await elk.layout(graph);
    } catch (e) {
      error = String(e && e.stack ? e.stack : e);
    }
    const buildMs = Date.now() - t0;
    if (error) return { label, error, buildMs };

    const basePos = absPositionMap(baselineLayout);
    const newPos = absPositionMap(layout2);
    const projectContainerW = 400; // rough project-container-width unit for the "one container width" threshold

    let unchangedCount = 0;
    let movedLess = 0;
    const moves = [];
    for (const [id, p0] of basePos.entries()) {
      if (prep.toRemove.includes(id)) continue;
      const p1 = newPos.get(id);
      if (!p1) continue;
      unchangedCount++;
      const dist = Math.hypot(p1.x - p0.x, p1.y - p0.y);
      moves.push(dist);
      if (dist < projectContainerW) movedLess++;
    }
    const pctStable = unchangedCount ? (100 * movedLess) / unchangedCount : 0;

    // spine-order check: compare left-to-right order of project containers by x, run1 vs run2
    function projectOrder(layout) {
      return (layout.children || [])
        .filter((c) => c._meta && c._meta.kind === "project")
        .map((c) => ({ id: c.id, x: c.x }))
        .sort((a, b) => a.x - b.x)
        .map((c) => c.id);
    }
    const order0 = projectOrder(baselineLayout);
    const order1 = projectOrder(layout2);
    const spineOrderPreserved = JSON.stringify(order0) === JSON.stringify(order1);

    return {
      label,
      buildMs,
      removed: prep.toRemove,
      added: prep.toAdd,
      flippedCount: prep.flippedCount,
      unchangedNodeCount: unchangedCount,
      pctMovedLessThanOneContainerWidth: pctStable,
      spineOrderPreserved,
      order0,
      order1,
      gatePass: pctStable >= 90 && spineOrderPreserved,
    };
  }

  const driftExpanded = await runDrift(results.expanded.layout, expandedChildren, expandedEdges, expandedGraph.layoutOptions, "expanded");
  const driftCollapsed = await runDrift(results.collapsed.layout, collapsedChildren, collapsedEdges, collapsedGraph.layoutOptions, "collapsed");

  console.log(`[spike] DRIFT expanded: ${JSON.stringify({ pct: driftExpanded.pctMovedLessThanOneContainerWidth, spine: driftExpanded.spineOrderPreserved, gate: driftExpanded.gatePass })}`);
  console.log(`[spike] DRIFT collapsed: ${JSON.stringify({ pct: driftCollapsed.pctMovedLessThanOneContainerWidth, spine: driftCollapsed.spineOrderPreserved, gate: driftCollapsed.gatePass })}`);

  writeFileSync(
    path.join(OUT_DIR, "raw_measurements.json"),
    JSON.stringify(
      {
        expanded: {
          buildMs: results.expanded.buildMs,
          error: results.expanded.error,
          edgeCount: results.expanded.edgeCount,
          metrics: results.expanded.metrics || null,
        },
        collapsed: {
          buildMs: results.collapsed.buildMs,
          error: results.collapsed.error,
          edgeCount: results.collapsed.edgeCount,
          metrics: results.collapsed.metrics || null,
        },
        orphanRefCount: orphanRefs.length,
        drift: {
          expanded: driftExpanded,
          collapsed: driftCollapsed,
        },
      },
      null,
      2
    )
  );

  console.log("[spike] done. See raw_measurements.json for full numbers.");
}

// ---------- SVG rendering + edge-routing-error detection + zoom-span measurement ----------
function collectAllNodes(node, acc, offX, offY, depth) {
  const x = (node.x || 0) + offX;
  const y = (node.y || 0) + offY;
  acc.push({ node, absX: x, absY: y, depth });
  for (const c of node.children || []) collectAllNodes(c, acc, x, y, depth + 1);
}

function renderSvg(layout, name) {
  const nodes = [];
  collectAllNodes(layout, nodes, 0, 0, 0);
  const canvasW = layout.width || 4000;
  const canvasH = layout.height || 2000;

  const VIEWPORT_W = 3200;
  const VIEWPORT_H = 1800;
  const fitScale = Math.min(VIEWPORT_W / canvasW, VIEWPORT_H / canvasH, 1);
  // leaf label size at native scale is 12px (we draw text at 12px); at fit zoom it renders at
  // 12*fitScale px. zoomSpan = how many times smaller than 12px the labels appear at fit, i.e.
  // the factor you'd need to zoom IN from fit to read a 12px label at native 12px again.
  const labelAtFit = 12 * fitScale;
  const zoomSpan = labelAtFit > 0 ? 12 / labelAtFit : Infinity;

  let svgBody = "";
  let leafCount = 0;
  let projectCount = 0;
  let wsCount = 0;
  const projectRects = [];

  for (const { node, absX, absY, depth } of nodes) {
    const w = node.width || 0;
    const h = node.height || 0;
    const meta = node._meta || {};
    if (meta.kind === "project") {
      projectCount++;
      const hue = meta.hue || 200;
      projectRects.push({ id: node.id, absX, absY, w, h });
      svgBody += `<rect x="${absX}" y="${absY}" width="${w}" height="${h}" fill="hsla(${hue},55%,22%,0.55)" stroke="hsl(${hue},65%,55%)" stroke-width="2" rx="6"/>`;
      svgBody += `<text x="${absX + 8}" y="${absY + 22}" fill="hsl(${hue},80%,80%)" font-size="16" font-family="monospace" font-weight="bold">${escapeXml(node.labels?.[0]?.text || node.id)}</text>`;
    } else if (meta.kind === "workstream" || meta.kind === "workstream-header") {
      wsCount++;
      const stateColor = { done: "#4caf50", "in-flight": "#2196f3", blocked: "#f44336" }[meta.state] || "#888";
      svgBody += `<rect x="${absX}" y="${absY}" width="${w}" height="${h}" fill="rgba(255,255,255,0.06)" stroke="${stateColor}" stroke-width="1.5" rx="4"/>`;
      svgBody += `<text x="${absX + 6}" y="${absY + 16}" fill="#ddd" font-size="11" font-family="monospace">${escapeXml(truncate(node.labels?.[0]?.text || node.id, 34))}</text>`;
    } else {
      // leaf item
      leafCount++;
      const stub = meta.stub;
      svgBody += `<rect x="${absX}" y="${absY}" width="${w}" height="${h}" fill="${stub ? "#332222" : "#1e2a3a"}" stroke="${stub ? "#aa5555" : "#5588aa"}" stroke-width="1" rx="3"/>`;
      svgBody += `<text x="${absX + 4}" y="${absY + h / 2 + 4}" fill="#cfcfcf" font-size="12" font-family="monospace">${escapeXml(truncate(node.labels?.[0]?.text || node.id, 24))}</text>`;
    }
  }

  // edges
  let edgeErrorCount = 0;
  for (const edge of layout.edges || []) {
    const kind = edge._meta?.kind;
    const color = kind === "blocks" ? "#e05555" : kind === "apex" ? "#e0c060" : "#66c2a5";
    const dash = kind === "blocks" ? ' stroke-dasharray="6,4"' : "";
    const sections = edge.sections || [];
    if (!sections.length) {
      edgeErrorCount++;
      continue;
    }
    for (const sec of sections) {
      const pts = [sec.startPoint, ...(sec.bendPoints || []), sec.endPoint];
      const d = pts.map((p, i) => `${i === 0 ? "M" : "L"}${p.x},${p.y}`).join(" ");
      svgBody += `<path d="${d}" fill="none" stroke="${color}" stroke-width="1.5"${dash} opacity="0.75"/>`;
    }
    const lbl = edge.labels?.[0]?.text;
    if (lbl) {
      const lp = edge.sections?.[0]?.endPoint;
      if (lp) svgBody += `<text x="${lp.x}" y="${lp.y}" fill="#e0c060" font-size="11" font-family="monospace">${escapeXml(lbl)}</text>`;
    }
  }

  const svg =
    `<svg xmlns="http://www.w3.org/2000/svg" width="${canvasW}" height="${canvasH}" ` +
    `viewBox="0 0 ${canvasW} ${canvasH}" style="background:#0d0f14">` +
    svgBody +
    `</svg>`;

  return {
    svg,
    metrics: {
      canvasW,
      canvasH,
      leafCount,
      projectCount,
      wsCount,
      edgeCount: (layout.edges || []).length,
      edgeErrorCount,
      fitScale,
      zoomSpan,
      projectRects: projectRects.map((p) => ({
        id: p.id,
        fitW: p.w * fitScale,
        fitH: p.h * fitScale,
      })),
    },
  };
}

function wrapHtml(svg, name, metrics) {
  return `<!doctype html>
<html><head><meta charset="utf-8"><title>graph-v3 spike: ${name}</title>
<style>body{background:#0d0f14;margin:0;padding:20px;font-family:monospace;color:#ccc}
.wrap{overflow:auto;border:1px solid #333}
h1{font-size:16px}</style></head>
<body>
<h1>graph-v3 kill-test -- ${name} altitude</h1>
<p>canvas ${metrics.canvasW.toFixed(0)}x${metrics.canvasH.toFixed(0)} | fitScale=${metrics.fitScale.toFixed(4)} | zoomSpan=${metrics.zoomSpan.toFixed(2)}x | leaves=${metrics.leafCount} projects=${metrics.projectCount} workstreams=${metrics.wsCount} edges=${metrics.edgeCount} edgeErrors=${metrics.edgeErrorCount}</p>
<div class="wrap">${svg}</div>
</body></html>`;
}

function escapeXml(s) {
  return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}
function truncate(s, n) {
  s = String(s);
  return s.length > n ? s.slice(0, n - 1) + "…" : s;
}

run();
