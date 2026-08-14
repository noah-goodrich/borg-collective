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
| `story.json` **skeleton** | `spine.py`, from the gather | Disposable | Grouping, membership, `blocked_by`, state. |
| `story.json` **judgment** (`story.overlay.json`) | hand-maintained | Durable | `priority`, `summary`, `title`. |
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
directly (e.g. `PROJ-1881`) since Jira has no repo/number pair.

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
  colleague it's waiting on" and prod-action outcomes) — committing them here would publish employer-internal
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

## The spine (`story.json`) — provenance

**This section exists because the answer used to be "nobody knows".** `story.json` had no generator: nothing in
the repo wrote it, `render_graph.py` only read it, and neither this file nor `PROTOCOL.md` said where it came
from. It was authored by hand in a session on **2026-07-28T16:15Z** and froze there. Thirteen days later it had
never heard of `infrastructure#2564`/`#2566` — the exact PRs an orchestrator session then spent 51 seconds of
model time reconstructing by hand. A stale spine is worse than no spine, because it looks authoritative.

    gather.raw.json ──> spine.py ──> story.json
                            ^
                  story.overlay.json (judgment)

Refresh it with **`make spine`** (or `python3 merge-tree/spine.py`).

### What is derived vs. what a human writes

| Derived every run (skeleton) | Persisted in the overlay (judgment) |
|---|---|
| project `id` (slug of the gather's project name) | project `name`, `priority`, `summary` |
| workstream membership, from `stacked`/`apex` edges | workstream `title`, `next_action` |
| workstream `state`, from member item states | project/workstream `owner` |
| `blocked_by`, from `blocks` edges | |

**Chain edges group; blocking edges do not.** `stacked`/`apex` mean "these items are one unit of work", so they
merge into a workstream. `blocks` is a dependency *between* workstreams — merging on it would collapse a blocker
into its own victim and lose the dependency. Items in no chain become single-item workstreams, which is a real
answer: a standalone PR is a workstream of one.

### The overlay's stable keys

Projects key on the **slug** of the gather's project name (`"WHP - Keypair migration"` → `sfp-keypair-migration`);
`slugify` is idempotent so re-slugging never drifts. Workstreams key on their **lexicographically smallest member
ref**.

That workstream key has a **known limit, stated rather than hidden**: if the anchor item leaves the workstream,
the key changes and that workstream's judgment is orphaned rather than migrated. Hashing the full member set
would be worse — it changes whenever *any* member joins or leaves, which happens constantly. Anchoring on one ref
means judgment survives the common case (a PR joins an existing chain) and is lost only in the rarer one.
Orphaned judgment is **reported**, never silently dropped.

### Two timestamps, on purpose

`meta.generated_at` ages the **skeleton**; each project's `summary_authored_at` ages its **prose** independently.
The summary is simultaneously the highest-value and the most perishable content in the spine, so a fresh skeleton
wrapped around two-week-old prose must be detectable as exactly that rather than reading as current.

### Orphan reporting

Every run reports four categories, because they fail differently:

- `unknown_projects` / `unknown_workstreams` — **new** structure the overlay has never seen. Rendering these
  silently with blank prose is how `infrastructure#2564` stayed invisible.
- `stale_projects` / `stale_workstreams` — judgment whose anchor is gone. Prose someone wrote that no longer
  attaches to anything, surfaced before it is lost.

### Regenerating will not reproduce today's hand-authored spine

Expected, not a bug. The 2026-07-28 spine grouped work with human insight the gather cannot express — its ids
(`keypair-migration`, `sme-self-service-pat`) do not correspond to the gather's project names, and its
granularity differs. The overlay is how that judgment is carried forward deliberately, project by project,
instead of being silently approximated.
