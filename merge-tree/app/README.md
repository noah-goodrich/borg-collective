# hub story lens (v0.1)

Dual-pane hub graph tool for the PR control hub. Left rail = the curated story spine (8 projects,
34 workstreams, prose blockers as first-class text). Right pane = a "focus lens": a small,
deterministically laid-out flat sub-DAG extracted fresh per request. The full 426-item / 72-edge
graph is never rendered as one picture — it lives only in memory as the extraction substrate.

## Why Option C (one-liner)

Option E ("Frozen Atlas, Living Lens") passed its build-time legibility gate but failed the
perturbation-drift test hard (14.6% node stability vs. a 90% bar, plus spine reordering) — see
`docs/research/2026-07-28-dependency-graph-tool/recommendation.md` and
`../spike/VERDICT.md`. Option C ("Story Rail + Focus Lens") is the pre-committed fallback: no
global frozen geometry anywhere, every lens laid out fresh and deterministically per-request, so
there is no state of the app that can display a hairball or drift out from under you.

## Running it

```
BORG_MERGE_TREE_DIR=/path/to/merge-tree-data ./serve.sh
```

Defaults to `~/.local/state/borg/merge-tree` if `BORG_MERGE_TREE_DIR` is unset. Binds
`127.0.0.1:8877`. If `.venv/` exists in this directory it is used automatically; otherwise falls
back to the system `python3 -m uvicorn`.

Setup (one-time):

```
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
```

Then open `http://127.0.0.1:8877/`.

## Data contract

Reads two files at startup from `$BORG_MERGE_TREE_DIR` (never committed, never leaves the box):

- `story.json` — curated projects/workstreams, prose `blocked_by`, `parallel_group`, `next_action`,
  `items` (refs).
- `data.json` — `items` (per-ref state/url/bucket/etc.), `edges` (`{parent, child, kind}` where
  `kind` is `stacked` | `apex` | `blocks`), `actions` (ref -> click-to-copy command).

The code is fully generic over these two files; nothing project-specific is hardcoded.

## Endpoints

- `GET /` — the single-page client.
- `GET /api/story` — story.json enriched with per-workstream item-state rollups from data.json.
- `GET /api/lens/{ref}?radius=1&direction=both` — extracted flat sub-DAG: `ref`'s neighborhood
  (bounded by `radius`) over all edge kinds, plus its full transitive `blocks`-edge closure in both
  directions, capped at ~40 nodes (with a `truncated` count). Special ref `portfolio` returns the
  8-project DAG, with edges derived from cross-project `blocks` edges and cross-project matches in
  curated `blocked_by` prose.
- `GET /api/unblocks` — top 15 refs ranked by transitive out-degree over `blocks` edges ("what
  unblocks the most").

## Client

Vanilla JS, no CDN, no vendored layout library — lens graphs are capped at ~40 nodes, so a small
hand-rolled layered layout (longest-path ranking + barycenter ordering, in `static/app.js`) renders
cleanly without a dependency. Dark theme, per-project hue tags, state-colored dots
(ready/in-flight/blocked/pending/done), `blocks`-kind edges in red with arrowheads. URL hash encodes
`{lens, radius, selected}` so a saved link restores the exact view.

## Scope (v0.1)

In scope: story rail, one-click blocking-chain lens, "what unblocks most" ranked list, URL-state
restore. Out of scope for v0.1 (per the ratified MVP line): Cmd-K fuzzy search, minimap.
