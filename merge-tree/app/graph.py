"""Graph algebra over the merge-tree data contracts (story.json + data.json).

Option C - "Story Rail + Focus Lens": the full graph is never rendered. This module only ever
produces small, deterministic, flat sub-DAG extractions for a single lens request. All functions
are pure (no I/O beyond load_dataset) and operate over plain dict/set/list structures — the whole
corpus is 426 items / 72 edges, trivial for in-memory closure walks.

Kinds observed in data.json edges: "stacked" (PR-stack base -> top), "apex" (apex PR -> each
stacked PR it umbrellas), "blocks" (parent must land before child; the true dependency edge used
for blocking-chain / unblock-ranking algebra).
"""

from __future__ import annotations

import json
import os
from collections import defaultdict, deque
from pathlib import Path

BLOCKING_KIND = "blocks"


def merge_tree_dir() -> Path:
    return Path(os.environ.get("BORG_MERGE_TREE_DIR", str(Path.home() / ".local/state/borg/merge-tree")))


def load_json(name: str) -> dict:
    path = merge_tree_dir() / name
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


class Dataset:
    """In-memory index over story.json + data.json. Rebuilt fresh per process start."""

    def __init__(self, story: dict, data: dict):
        self.story = story
        self.data = data
        self.items_by_ref: dict[str, dict] = {item["ref"]: item for item in data.get("items", [])}
        self.edges: list[dict] = data.get("edges", [])
        self.actions: dict = data.get("actions", {})

        # ref -> (project_id, project_name, workstream_title) via the curated story spine.
        self.ref_home: dict[str, tuple[str, str, str]] = {}
        for project in story.get("projects", []):
            for ws in project.get("workstreams", []):
                for ref in ws.get("items", []):
                    self.ref_home[ref] = (project["id"], project["name"], ws["title"])

        # forward/back adjacency over ALL edges (any kind), used for neighborhood radius walks.
        self.fwd_any: dict[str, list[tuple[str, str]]] = defaultdict(list)
        self.back_any: dict[str, list[tuple[str, str]]] = defaultdict(list)
        # forward/back adjacency restricted to "blocks" edges, used for blocking-closure walks.
        self.fwd_blocks: dict[str, list[str]] = defaultdict(list)
        self.back_blocks: dict[str, list[str]] = defaultdict(list)

        for e in self.edges:
            p, c, k = e["parent"], e["child"], e["kind"]
            self.fwd_any[p].append((c, k))
            self.back_any[c].append((p, k))
            if k == BLOCKING_KIND:
                self.fwd_blocks[p].append(c)
                self.back_blocks[c].append(p)

    # -- node decoration -------------------------------------------------

    def node_for_ref(self, ref: str) -> dict:
        item = self.items_by_ref.get(ref)
        proj_id, proj_name, ws_title = self.ref_home.get(ref, ("", "", ""))
        if item:
            title = item.get("title", ref)
            state = _state_bucket(item)
            repo = item.get("repo", "")
            url = item.get("url", "")
            action_needed = item.get("action_needed", "")
        else:
            title = ref
            state = "unknown"
            repo = ref.split("#")[0] if "#" in ref else ""
            url = ""
            action_needed = ""
        return {
            "ref": ref,
            "title": title,
            "state": state,
            "bucket": item.get("bucket", "") if item else "",
            "project": proj_name or (item.get("project", "") if item else ""),
            "repo": repo,
            "url": url,
            "blocked": bool(item.get("blocked")) if item else False,
            "action_needed": action_needed,
            "containment_badge": f"{proj_name} / {ws_title}" if proj_name and ws_title else "",
            "has_action": ref in self.actions,
        }

    # -- lens extraction ---------------------------------------------------

    def lens(self, ref: str, radius: int = 1, direction: str = "both") -> dict:
        if ref == "portfolio":
            return self.portfolio_lens()

        nodes: set[str] = {ref}
        edges: list[dict] = []
        seen_edges: set[tuple[str, str, str]] = set()

        # 1. bounded neighborhood over ALL edge kinds, up to `radius` hops.
        frontier = {ref}
        for _ in range(max(radius, 0)):
            next_frontier: set[str] = set()
            for n in frontier:
                if direction in ("out", "both"):
                    for c, k in self.fwd_any.get(n, []):
                        key = (n, c, k)
                        if key not in seen_edges:
                            seen_edges.add(key)
                            edges.append({"source": n, "target": c, "kind": k})
                        if c not in nodes:
                            nodes.add(c)
                            next_frontier.add(c)
                if direction in ("in", "both"):
                    for p, k in self.back_any.get(n, []):
                        key = (p, n, k)
                        if key not in seen_edges:
                            seen_edges.add(key)
                            edges.append({"source": p, "target": n, "kind": k})
                        if p not in nodes:
                            nodes.add(p)
                            next_frontier.add(p)
            frontier = next_frontier

        # 2. full transitive blocking closure, both directions, regardless of radius.
        closure_nodes = self._blocking_closure(ref)
        nodes |= closure_nodes
        for n in list(nodes):
            for c in self.fwd_blocks.get(n, []):
                if c in nodes:
                    key = (n, c, BLOCKING_KIND)
                    if key not in seen_edges:
                        seen_edges.add(key)
                        edges.append({"source": n, "target": c, "kind": BLOCKING_KIND})

        capped, truncated = self._cap(nodes, ref)
        edges = [e for e in edges if e["source"] in capped and e["target"] in capped]
        return {
            "root": ref,
            "nodes": [self.node_for_ref(n) for n in sorted(capped)],
            "edges": edges,
            "truncated": truncated,
        }

    def _blocking_closure(self, ref: str) -> set[str]:
        seen = {ref}
        dq = deque([ref])
        while dq:
            n = dq.popleft()
            for c in self.fwd_blocks.get(n, []):
                if c not in seen:
                    seen.add(c)
                    dq.append(c)
            for p in self.back_blocks.get(n, []):
                if p not in seen:
                    seen.add(p)
                    dq.append(p)
        return seen

    @staticmethod
    def _cap(nodes: set[str], root: str, limit: int = 40) -> tuple[set[str], int]:
        if len(nodes) <= limit:
            return nodes, 0
        ordered = [root] + sorted(n for n in nodes if n != root)
        capped = set(ordered[:limit])
        return capped, len(nodes) - limit

    # -- portfolio lens: 8-project DAG --------------------------------------

    def portfolio_lens(self) -> dict:
        projects = self.story.get("projects", [])
        proj_ids = {p["id"] for p in projects}
        proj_edges: set[tuple[str, str]] = set()

        # cross-project blocking edges, derived from data.json "blocks" edges whose two refs
        # resolve to different projects via the curated story spine.
        for e in self.edges:
            if e["kind"] != BLOCKING_KIND:
                continue
            p_home = self.ref_home.get(e["parent"])
            c_home = self.ref_home.get(e["child"])
            if p_home and c_home and p_home[0] != c_home[0]:
                proj_edges.add((p_home[0], c_home[0]))

        # cross-project blocking derived from curated blocked_by prose: match any other project's
        # id or name as a substring of the prose text (best-effort, curated data is prose not refs).
        name_by_id = {p["id"]: p["name"] for p in projects}
        for project in projects:
            for ws in project.get("workstreams", []):
                for prose in ws.get("blocked_by", []):
                    for other_id, other_name in name_by_id.items():
                        if other_id == project["id"]:
                            continue
                        if other_id in prose or other_name in prose:
                            proj_edges.add((other_id, project["id"]))

        nodes = []
        for p in projects:
            states = []
            for ws in p.get("workstreams", []):
                states.append(ws.get("state", "pending"))
            nodes.append(
                {
                    "ref": p["id"],
                    "title": p["name"],
                    "state": _rollup_state(states),
                    "bucket": "",
                    "project": p["name"],
                    "repo": "",
                    "url": "",
                    "blocked": "blocked" in states,
                    "action_needed": "",
                    "containment_badge": "",
                    "has_action": False,
                }
            )
        edges = [{"source": a, "target": b, "kind": BLOCKING_KIND} for a, b in sorted(proj_edges)]
        return {"root": "portfolio", "nodes": nodes, "edges": edges, "truncated": 0}

    # -- unblock ranking -----------------------------------------------------

    def unblocks(self, top: int = 15) -> list[dict]:
        all_refs = set(self.fwd_blocks) | set(self.back_blocks)
        scored = []
        for ref in all_refs:
            downstream = self._transitive(ref, self.fwd_blocks)
            if downstream:
                node = self.node_for_ref(ref)
                scored.append({**node, "unblock_count": len(downstream)})
        scored.sort(key=lambda r: (-r["unblock_count"], r["ref"]))
        return scored[:top]

    @staticmethod
    def _transitive(ref: str, adj: dict[str, list[str]]) -> set[str]:
        seen: set[str] = set()
        dq = deque(adj.get(ref, []))
        while dq:
            n = dq.popleft()
            if n in seen:
                continue
            seen.add(n)
            dq.extend(adj.get(n, []))
        return seen

    # -- enriched story rail --------------------------------------------------

    def enriched_story(self) -> dict:
        projects = []
        for p in self.story.get("projects", []):
            workstreams = []
            for ws in p.get("workstreams", []):
                item_states = [self.items_by_ref.get(r, {}) for r in ws.get("items", [])]
                workstreams.append(
                    {
                        **ws,
                        "item_count": len(ws.get("items", [])),
                        "open_count": sum(1 for it in item_states if it.get("state") == "OPEN"),
                        "blocked_count": sum(1 for it in item_states if it.get("blocked")),
                    }
                )
            projects.append({**p, "workstreams": workstreams})
        return {"meta": self.story.get("meta", {}), "projects": projects}


def _state_bucket(item: dict) -> str:
    if item.get("state") in ("MERGED", "CLOSED", "Done", "done"):
        return "done"
    if item.get("blocked"):
        return "blocked"
    if item.get("bucket") == "needs-you":
        return "in-flight"
    return "pending"


def _rollup_state(states: list[str]) -> str:
    if not states:
        return "pending"
    if any(s == "blocked" for s in states):
        return "blocked"
    if any(s == "in-flight" for s in states):
        return "in-flight"
    if all(s == "done" for s in states):
        return "done"
    if any(s == "ready" for s in states):
        return "ready"
    return "pending"


def load_dataset() -> Dataset:
    return Dataset(load_json("story.json"), load_json("data.json"))
