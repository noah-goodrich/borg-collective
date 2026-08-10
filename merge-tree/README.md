# merge-tree — PR control hub

A cross-repo, cross-machine "control hub": one self-contained HTML page that surfaces every in-flight PR / issue /
Jira item across all repos and projects, curated into four buckets (needs-you, active-chains, standalone,
collapsed-noise) and paired with a recommended next action the orchestrator can dispatch. `data.json` is the
source of truth; `render.py` is a pure `data.json → index.html` view with no external dependencies (python3
stdlib only: `json`/`os`/`html`/`datetime`/`argparse`/`collections`). The gather that produces `data.json` is the
recon fan-out primitive ([borg#95](https://github.com/noah-goodrich/borg-collective/issues/95)); this repo owns
only the shared renderer + protocol so every machine runs the same code against its own local data
([borg#97](https://github.com/noah-goodrich/borg-collective/issues/97)).

## Run it

```
python3 merge-tree/render.py
```

By default this reads `<STATE>/data.json` and the optional `<STATE>/annotations.local.json`, and writes
`<STATE>/index.html`, where `<STATE>` is `$BORG_MERGE_TREE_DIR` if set, else
`~/.local/state/borg/merge-tree`. Per-machine data (`data.json`, `annotations.local.json`, the rendered
`index.html`) lives at that state path, not in this repo — only the renderer + protocol are shared code.

Override individual paths without touching the env var:

```
python3 merge-tree/render.py --data /path/to/data.json --out /path/to/index.html
```

The render succeeds with `annotations.local.json` absent, empty, or malformed — annotations are optional and
machine-local by design (see SCHEMA.md).

## Graph view

```
python3 merge-tree/render_graph.py
```

Reads the same `data.json` (+ optional `annotations.local.json`) and writes `<STATE>/graph.html`: an interactive,
self-contained (inline SVG + vanilla JS, no CDN) node-link dependency graph with three drill-down levels (project
field-of-play → stack sub-graph → full per-item info panel), project/repo filters, and a chain-isolation control.
`index.html` links to it ("Graph view →") and it links back ("← List view").

## Files

- `render.py` — the list/bucket renderer.
- `render_graph.py` — the interactive dependency-graph renderer.
- `SCHEMA.md` — the ratified `data.json` contract and the three-layer model (source state / disposable projection
  / durable machine-local annotations).
- `PROTOCOL.md` — the action-dispatch contract (`actions[ref] = {label, command, class}`) and the
  readonly-vs-confirm guardrail, which reuses the existing bash-guard classification rather than inventing a new
  one.

## Further reading

- [borg#97](https://github.com/noah-goodrich/borg-collective/issues/97) — the design thread that ratified this
  schema and protocol.
- [borg#95](https://github.com/noah-goodrich/borg-collective/issues/95) — the recon fan-out primitive that gathers
  and normalizes the raw items this hub curates (merged/closed).
