# PR Control Hub — `data.json` schema (v2, ratified)

Ratified in [borg#97](https://github.com/noah-goodrich/borg-collective/issues/97) through a joint design thread
between the work-machine and personal-machine orchestrators. This document is the contract; `render.py` is a pure
consumer of it.

## Three-layer model

The hub is built from three layers with different owners and lifetimes. Keeping them separate is the whole point —
it lets adapters stay dumb, curation stay re-runnable, and durable reasoning survive a `data.json` rebuild.

| Layer | Owner | Lifetime | Notes |
|---|---|---|---|
| PR / issue / Jira state | GitHub, Jira (via the recon fan-out, [borg#95](https://github.com/noah-goodrich/borg-collective/issues/95)) | Ephemeral — re-gathered every run | Source of truth for *what is true right now*. |
| `data.json` | The gather + a curation pass | Disposable — rebuildable from scratch anytime | A curated **projection**, not a database. Never hand-edited. |
| Annotations (`annotations.local.json`) | hand- and tool-maintained, machine-local | Durable, machine-scoped | The *why* — rationale, decisions, action-outcome history. See "Annotations" below. |

`bucket` and `urgency` are **curation-derived**, not adapter-emitted — the recon adapters that populate `items[]`
stay source-agnostic and dumb; all judgment about what's urgent or which bucket an item belongs in concentrates in
one re-runnable curation pass. This keeps `data.json` reproducible: rerun curation and the assignments update
without re-gathering.

## Top-level shape

```
data.json = {
  meta:    { gathered_at, machine, today, repos[], health[] },
  items:   [ Item, ... ],
  edges:   [ Edge, ... ],
  actions: { "<ref>": Action, ... }
}
```

### `meta`

| field | type | description |
|---|---|---|
| `gathered_at` | ISO8601 string | when the gather ran |
| `machine` | string | which machine produced this `data.json` |
| `today` | ISO8601 date string | render's reference date, for age calculations |
| `repos[]` | string[] | repos swept by the gather |
| `health[]` | `HealthCheck[]` | environment-health panel data, see below |

`HealthCheck = { check, machine, status: "ok"|"warn"|"down", detail, checked_at }`. The health panel exists so
outages (container/VM clock skew, source-adapter/auth failures) are visible at a glance rather than
silently degrading the render — see [borg#98](https://github.com/noah-goodrich/borg-collective/issues/98) and
[borg#99](https://github.com/noah-goodrich/borg-collective/issues/99).

### `Item`

```
{
  ref:            "repo#num" | "JIRA-KEY",   # canonical join key, see below
  project:        string,
  repo:           string,
  source:         "github-pr" | "github-issue" | "jira",
  title:          string,
  state:          string,                    # "OPEN" | "MERGED" | "CLOSED" | ...
  changed:        ISO8601 string,
  owner:          string,
  url:            string,
  one_line:       string,
  bucket:         "needs-you" | "active-chains" | "standalone" | "collapsed-noise",
  urgency:        number,
  action_needed:  string,
  is_entrypoint:  bool,
  blocked:        bool
}
```

`ref` is the **one canonical key** used everywhere — `items[]`, `edges[]`, the `actions` map, and the annotation
join all key off the same string. GitHub items use `repo#num` (e.g. `dbt#1145`); Jira items use the Jira key
directly (e.g. `DE-1881`) since Jira has no repo/number pair.

### `Edge`

```
{ parent: "<ref>", child: "<ref>", kind: "stacked" | "blocks" | "apex" }
```

Bare `{parent, child}` was rejected during ratification — it flattens semantics the renderer needs: `stacked` edges
draw as a dependency rail, `apex` marks the grouping header for a chain, `blocks` renders as a cross-reference
rather than a rail. Keep the flat edge list; keep `kind`.

### `Action`

```
{ "<ref>": { label: string, command: string, class: "readonly" | "confirm" } }
```

`class` **reuses the existing bash-guard readonly-vs-confirm classification** — it is not a new classifier. See
PROTOCOL.md for the dispatch contract.

## Annotations (`annotations.local.json`) — machine-local, v1

Annotations are the durable *why* layer: why a PR is parked, what a previous session already tried, what the
decision was and its rationale. (An earlier draft of this schema named cairn as their source; cairn was
decommissioned in 2026-08, so annotations are maintained locally with no service behind them.) The v1 substrate
decision keeps them **strictly machine-local**:

- **No committed file.** `annotations.local.json` is never checked into git — see the `.gitignore` note below.
- **No cross-machine sync in v1.** Each machine's hub renders only its own annotations. A committed
  `annotations.<machine>.json` per-machine-file scheme was proposed and then blocked: `borg-collective` is
  **public**, and annotations are strictly more sensitive than `data.json` (they carry rationale like "which
  colleague it's waiting on" and prod-action outcomes) — committing them here would publish Ontra-internal
  reasoning to the open internet.
- **Cross-machine is deferred, not abandoned.** When both machines' annotations need to appear in one view, the
  answer is a **shared database both machines phone home to** (e.g. a schema in the shared stillpoint Postgres)
  — explicitly **not** a git repo. Git-repo-as-mutable-data-store is out; git stays the
  substrate for *code* only.
- **Never a precondition.** The render must succeed with `annotations.local.json` absent, empty, or malformed.
  `render.py` treats any read/parse failure as "no annotations" and continues.

### Annotations shape

A flat map keyed by `ref`:

```
{ "<ref>": { when, text, source, history: [ {when, text, source}, ... ], ... } }
```

Per-ref fields shallow-update the matching `Item` at render time (so an annotation can, e.g., override `note` or
add fields the gather didn't produce). A `history[]` list, if present, renders as a per-item expandable
"why / history" trail rather than being flattened onto the node.

## What's out of scope for v1

- No cross-machine annotation merge/union (deferred to v2, DB-backed).
- No GitHub Project mirroring logic lives in `render.py` — that's a separate, optional push path
  (hub-as-source, board-as-mirror) discussed in borg#97 but not part of this schema.
