// hub story rail + focus lens client. Vanilla JS, no CDN. Layout is a small hand-rolled
// layered DAG layout (longest-path ranking + barycenter ordering) computed fresh per lens --
// deterministic per request, never a global frozen geometry (see VERDICT.md on why Option E died).

const STATE_ORDER = { blocked: 0, "in-flight": 1, ready: 2, pending: 3, done: 4, unknown: 5 };

const state = {
  story: null,
  unblocks: [],
  lensRoot: "portfolio",
  radius: 1,
  direction: "both",
  selectedRef: null,
  breadcrumb: [],
};

const PROJECT_HUES = {};
let hueCursor = 0;
function hueFor(key) {
  if (!(key in PROJECT_HUES)) {
    PROJECT_HUES[key] = (hueCursor * 47) % 360;
    hueCursor += 1;
  }
  return PROJECT_HUES[key];
}

async function fetchJSON(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${url} -> ${res.status}`);
  return res.json();
}

// ---------- URL state ----------

function encodeHash() {
  const params = new URLSearchParams();
  params.set("lens", state.lensRoot);
  params.set("radius", String(state.radius));
  if (state.selectedRef) params.set("selected", state.selectedRef);
  location.hash = params.toString();
}

function decodeHash() {
  if (!location.hash) return;
  const params = new URLSearchParams(location.hash.slice(1));
  if (params.has("lens")) state.lensRoot = params.get("lens");
  if (params.has("radius")) state.radius = parseInt(params.get("radius"), 10) || 1;
  if (params.has("selected")) state.selectedRef = params.get("selected");
}

window.addEventListener("hashchange", () => {
  decodeHash();
  loadLens(state.lensRoot, { pushHistory: false });
});

// ---------- rail: projects + workstreams ----------

function renderStory() {
  const list = document.getElementById("projects-list");
  list.innerHTML = "";
  for (const project of state.story.projects) {
    const row = document.createElement("div");
    row.className = "project-row";

    const header = document.createElement("div");
    header.className = "project-header";
    header.innerHTML = `<span class="project-chevron">&#9656;</span>
      <span class="project-hue-dot" style="background:hsl(${hueFor(project.id)},60%,55%)"></span>
      <span>${escapeHTML(project.name)}</span>`;

    const wsWrap = document.createElement("div");
    wsWrap.className = "workstreams";

    for (const ws of project.workstreams) {
      const wsRow = document.createElement("div");
      wsRow.className = "ws-row" + (ws.state === "done" ? " done-strike" : "");
      wsRow.dataset.ref = wsRootRef(project, ws);

      const titleLine = document.createElement("div");
      titleLine.className = "ws-title-line";
      titleLine.innerHTML = `<span class="state-dot ${ws.state}"></span>
        <span class="ws-title">${escapeHTML(ws.title)}</span>
        ${ws.parallel_group ? `<span class="ws-tag">${escapeHTML(ws.parallel_group)}</span>` : ""}`;
      wsRow.appendChild(titleLine);

      if (ws.blocked_by && ws.blocked_by.length) {
        for (const prose of ws.blocked_by) {
          const p = document.createElement("div");
          p.className = "ws-blocked-prose";
          p.textContent = `blocked by: ${prose}`;
          wsRow.appendChild(p);
        }
      }

      wsRow.addEventListener("click", () => {
        const ref = firstRealRef(ws);
        if (ref) {
          selectWorkstreamDetail(project, ws);
          loadLens(ref);
        }
      });

      wsWrap.appendChild(wsRow);
    }

    header.addEventListener("click", () => {
      header.classList.toggle("open");
      wsWrap.classList.toggle("open");
    });

    row.appendChild(header);
    row.appendChild(wsWrap);
    list.appendChild(row);
  }
}

function wsRootRef(project, ws) {
  return firstRealRef(ws) || `${project.id}::${ws.title}`;
}

function firstRealRef(ws) {
  return (ws.items && ws.items.length) ? ws.items[0] : null;
}

function selectWorkstreamDetail(project, ws) {
  const body = document.getElementById("detail-body");
  body.innerHTML = `
    <h3>${escapeHTML(ws.title)}</h3>
    <div class="detail-row"><b>project</b> ${escapeHTML(project.name)}</div>
    <div class="detail-row"><b>state</b> ${escapeHTML(ws.state)}</div>
    <div class="detail-row"><b>owner</b> ${escapeHTML(ws.owner || "-")}</div>
    <div class="detail-row"><b>next action</b> ${escapeHTML(ws.next_action || "-")}</div>
  `;
}

// ---------- rail: what unblocks most ----------

function renderUnblocks() {
  const list = document.getElementById("unblocks-list");
  list.innerHTML = "";
  state.unblocks.forEach((row, i) => {
    const li = document.createElement("li");
    li.className = "unblocks-item";
    li.dataset.ref = row.ref;
    li.innerHTML = `<span class="unblocks-rank">${i + 1}</span>
      <span class="unblocks-ref">${escapeHTML(row.ref)}</span>
      <span class="unblocks-count">${row.unblock_count}</span>`;
    li.addEventListener("click", () => {
      renderNodeDetail(row);
      loadLens(row.ref);
    });
    list.appendChild(li);
  });
}

// ---------- lens rendering ----------

async function loadLens(ref, opts = {}) {
  state.lensRoot = ref;
  document.getElementById("lens-root-label").textContent = ref;
  highlightActiveRailEntries(ref);
  try {
    const lens = await fetchJSON(`/api/lens/${encodeURIComponent(ref)}?radius=${state.radius}&direction=${state.direction}`);
    renderLensSVG(lens);
  } catch (err) {
    renderLensError(String(err));
  }
  if (opts.pushHistory !== false) encodeHash();
}

function highlightActiveRailEntries(ref) {
  document.querySelectorAll(".ws-row.active, .unblocks-item.active").forEach((el) => el.classList.remove("active"));
  document.querySelectorAll(`[data-ref="${cssEscape(ref)}"]`).forEach((el) => el.classList.add("active"));
}

function cssEscape(s) {
  return s.replace(/[^a-zA-Z0-9_-]/g, (c) => `\\${c}`);
}

function renderLensError(msg) {
  const svg = document.getElementById("lens-svg");
  svg.innerHTML = "";
  svg.setAttribute("viewBox", "0 0 600 200");
  const text = document.createElementNS("http://www.w3.org/2000/svg", "text");
  text.setAttribute("x", "20");
  text.setAttribute("y", "40");
  text.setAttribute("class", "lens-empty");
  text.textContent = `lens load failed: ${msg}`;
  svg.appendChild(text);
}

// Longest-path ranking + barycenter ordering: a small dependency-free layered layout, fine for
// the <=40-node caps this app enforces server-side.
function layoutLens(lens) {
  const nodeById = new Map(lens.nodes.map((n) => [n.ref, n]));
  const outAdj = new Map();
  const inAdj = new Map();
  for (const n of lens.nodes) {
    outAdj.set(n.ref, []);
    inAdj.set(n.ref, []);
  }
  for (const e of lens.edges) {
    if (!outAdj.has(e.source) || !inAdj.has(e.target)) continue;
    outAdj.get(e.source).push(e.target);
    inAdj.get(e.target).push(e.source);
  }

  // longest-path rank via topological-ish relaxation (graph is small; a few passes converge).
  const rank = new Map(lens.nodes.map((n) => [n.ref, 0]));
  for (let pass = 0; pass < lens.nodes.length + 1; pass++) {
    let changed = false;
    for (const e of lens.edges) {
      if (!rank.has(e.source) || !rank.has(e.target)) continue;
      const candidate = rank.get(e.source) + 1;
      if (candidate > rank.get(e.target)) {
        rank.set(e.target, candidate);
        changed = true;
      }
    }
    if (!changed) break;
  }

  const layers = new Map();
  for (const n of lens.nodes) {
    const r = rank.get(n.ref);
    if (!layers.has(r)) layers.set(r, []);
    layers.get(r).push(n.ref);
  }
  const sortedRanks = [...layers.keys()].sort((a, b) => a - b);

  // barycenter ordering within each layer, a couple of sweeps using neighbor positions.
  const orderIndex = new Map();
  sortedRanks.forEach((r) => layers.get(r).forEach((ref, i) => orderIndex.set(ref, i)));

  for (let sweep = 0; sweep < 3; sweep++) {
    for (const r of sortedRanks) {
      const refs = layers.get(r);
      refs.sort((a, b) => {
        const ba = barycenter(a, inAdj.get(a), orderIndex);
        const bb = barycenter(b, inAdj.get(b), orderIndex);
        return ba - bb;
      });
      refs.forEach((ref, i) => orderIndex.set(ref, i));
    }
  }

  const colWidth = 210;
  const rowHeight = 62;
  const marginX = 40;
  const marginY = 30;
  const positions = new Map();
  for (const r of sortedRanks) {
    const refs = layers.get(r);
    refs.forEach((ref, i) => {
      positions.set(ref, {
        x: marginX + r * colWidth,
        y: marginY + i * rowHeight,
      });
    });
  }

  const width = marginX * 2 + (sortedRanks.length - 1) * colWidth + 160;
  const maxRows = Math.max(...[...layers.values()].map((v) => v.length), 1);
  const height = marginY * 2 + (maxRows - 1) * rowHeight + 50;

  return { positions, width, height, nodeById };
}

function barycenter(_ref, neighbors, orderIndex) {
  if (!neighbors || !neighbors.length) return 0;
  const vals = neighbors.filter((n) => orderIndex.has(n)).map((n) => orderIndex.get(n));
  if (!vals.length) return 0;
  return vals.reduce((a, b) => a + b, 0) / vals.length;
}

function renderLensSVG(lens) {
  const svg = document.getElementById("lens-svg");
  svg.innerHTML = "";

  if (!lens.nodes.length) {
    svg.setAttribute("viewBox", "0 0 400 100");
    const text = document.createElementNS("http://www.w3.org/2000/svg", "text");
    text.setAttribute("x", "20");
    text.setAttribute("y", "40");
    text.setAttribute("class", "lens-empty");
    text.textContent = "no data for this lens";
    svg.appendChild(text);
    return;
  }

  const { positions, width, height } = layoutLens(lens);
  svg.setAttribute("viewBox", `0 0 ${width} ${Math.max(height, 200)}`);

  const defs = document.createElementNS("http://www.w3.org/2000/svg", "defs");
  defs.innerHTML = `
    <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M0,0 L10,5 L0,10 z" fill="var(--red)"></path>
    </marker>`;
  svg.appendChild(defs);

  const edgeLayer = document.createElementNS("http://www.w3.org/2000/svg", "g");
  const nodeLayer = document.createElementNS("http://www.w3.org/2000/svg", "g");

  for (const e of lens.edges) {
    const a = positions.get(e.source);
    const b = positions.get(e.target);
    if (!a || !b) continue;
    const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
    const x1 = a.x + 150;
    const y1 = a.y + 18;
    const x2 = b.x;
    const y2 = b.y + 18;
    const midX = (x1 + x2) / 2;
    path.setAttribute("d", `M${x1},${y1} C${midX},${y1} ${midX},${y2} ${x2},${y2}`);
    path.setAttribute("class", `lens-edge ${e.kind}`);
    if (e.kind === "blocks") path.setAttribute("marker-end", "url(#arrow)");
    edgeLayer.appendChild(path);
  }

  for (const n of lens.nodes) {
    const p = positions.get(n.ref);
    if (!p) continue;
    const g = document.createElementNS("http://www.w3.org/2000/svg", "g");
    g.setAttribute("class", "lens-node" + (n.ref === state.selectedRef ? " selected" : ""));
    g.setAttribute("transform", `translate(${p.x},${p.y})`);
    g.dataset.ref = n.ref;

    const rect = document.createElementNS("http://www.w3.org/2000/svg", "rect");
    rect.setAttribute("width", "150");
    rect.setAttribute("height", "36");
    rect.setAttribute("rx", "6");
    g.appendChild(rect);

    const dot = document.createElementNS("http://www.w3.org/2000/svg", "circle");
    dot.setAttribute("cx", "10");
    dot.setAttribute("cy", "12");
    dot.setAttribute("r", "4");
    dot.setAttribute("fill", stateColor(n.state));
    g.appendChild(dot);

    const label = document.createElementNS("http://www.w3.org/2000/svg", "text");
    label.setAttribute("x", "20");
    label.setAttribute("y", "16");
    label.textContent = truncate(n.title || n.ref, 20);
    g.appendChild(label);

    const refText = document.createElementNS("http://www.w3.org/2000/svg", "text");
    refText.setAttribute("x", "20");
    refText.setAttribute("y", "29");
    refText.setAttribute("class", "node-badge");
    refText.textContent = n.containment_badge || n.ref;
    g.appendChild(refText);

    g.addEventListener("click", () => {
      state.selectedRef = n.ref;
      renderNodeDetail(n);
      document.querySelectorAll(".lens-node.selected").forEach((el) => el.classList.remove("selected"));
      g.classList.add("selected");
      encodeHash();
    });

    nodeLayer.appendChild(g);
  }

  svg.appendChild(edgeLayer);
  svg.appendChild(nodeLayer);

  if (lens.truncated) {
    const note = document.createElementNS("http://www.w3.org/2000/svg", "text");
    note.setAttribute("x", "20");
    note.setAttribute("y", String(height - 10));
    note.setAttribute("class", "truncation-note");
    note.textContent = `+${lens.truncated} more (capped at 40 nodes)`;
    svg.appendChild(note);
  }
}

function stateColor(s) {
  switch (s) {
    case "blocked": return "var(--red)";
    case "in-flight": return "var(--blue)";
    case "ready": return "var(--green)";
    case "done": return "var(--text-2)";
    default: return "var(--grey)";
  }
}

function truncate(s, n) {
  return s.length > n ? s.slice(0, n - 1) + "…" : s;
}

// ---------- detail slot ----------

function renderNodeDetail(node) {
  const body = document.getElementById("detail-body");
  const rows = [
    ["ref", node.ref],
    ["project", node.project],
    ["state", node.state],
    ["bucket", node.bucket],
    ["action needed", node.action_needed],
  ].filter(([, v]) => v);

  let html = `<h3>${node.url ? `<a href="${escapeHTML(node.url)}" target="_blank" rel="noopener">${escapeHTML(node.title || node.ref)}</a>` : escapeHTML(node.title || node.ref)}</h3>`;
  for (const [k, v] of rows) {
    html += `<div class="detail-row"><b>${k}</b> ${escapeHTML(String(v))}</div>`;
  }
  body.innerHTML = html;

  const btn = document.createElement("button");
  btn.className = "action-cmd";
  const rerootLabel = document.createElement("div");
  rerootLabel.textContent = "re-root lens here →";
  btn.appendChild(rerootLabel);
  btn.addEventListener("click", () => loadLens(node.ref));
  body.appendChild(btn);
}

// ---------- boot ----------

function escapeHTML(s) {
  const div = document.createElement("div");
  div.textContent = s == null ? "" : s;
  return div.innerHTML;
}

async function boot() {
  decodeHash();
  const [story, unblocks] = await Promise.all([
    fetchJSON("/api/story"),
    fetchJSON("/api/unblocks"),
  ]);
  state.story = story;
  state.unblocks = unblocks;
  renderStory();
  renderUnblocks();

  document.getElementById("lens-reset").addEventListener("click", () => {
    state.selectedRef = null;
    loadLens("portfolio");
  });

  await loadLens(state.lensRoot);
}

boot().catch((err) => {
  console.error(err);
  renderLensError(String(err));
});
