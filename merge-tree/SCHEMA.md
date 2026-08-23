# PR Control Hub — `data.json` schema (v2, ratified)

Ratified in [borg#97](https://github.com/noah-goodrich/borg-collective/issues/97) through a joint design thread
between the work-machine and personal-machine orchestrators. This document is the contract; `render.py` is a pure
consumer of it.

## Three-layer model

The hub is built from three layers with different owners and lifetimes. Keeping them separate is the whole point —
it lets adapters stay dumb, curation stay re-runnable, and durable reasoning survive a `data.json` rebuild.

| Layer | Owner | Lifetime | Notes |
|---|---|---|---|
| PR / issue / Jira state | GitHub, Jira via recon | Ephemeral — re-gathered per run | Source of truth for *now*. |
| `data.json` | Gather + curation pass | Disposable, rebuildable | A curated **projection**, never hand-edited. |
| `story.json` **skeleton** | `spine.py`, from the gather | Disposable | Grouping, membership, `blocked_by`, state. |
| `story.json` **judgment** | hand-maintained (`story.overlay.json`) | Durable | `priority`, `summary`, `title`. |
| Annotations | hand/tool-maintained, machine-local | Durable, machine-scoped | The *why*. See "Annotations" below. |

(Recon fan-out reference: [borg#95](https://github.com/noah-goodrich/borg-collective/issues/95).
Annotations file: `annotations.local.json`.)

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

Projects key on the **slug** of the gather's project name (`"SFP - Keypair migration"` → `sfp-keypair-migration`);
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

## Program manifests (`<project>/.borg/programs/*.json`) — borg's declared edges

**This is borg's own contract, owned here.** It is not derived from, validated against, or dependent on any other
tool's file format; borg must behave identically on a machine that has no other plugin installed.

### Why it exists

`gather.derive_stacked_edges` recovers `stacked` edges from branch topology — a stacked PR's base branch is its
parent's head branch. But **a base branch is a repo-local name**, so every derived edge is repo-local by
construction. The cross-*repo* case, which is the entire point of the graph, is not derivable from any mechanical
signal: nothing in git or the GitHub API says `platform#834` must merge before `warehouse#302`. That ordering exists
only in the head of whoever planned the program, so it has to be **declared**.

### Shape

```json
{
  "program": "auth-hardening",
  "apex":    {"ref": "owner/repo#900", "label": "optional program name"},
  "note":    "optional",
  "rows": [
    {"order": "I1", "ref": "owner/repo#834", "lane": "ingest", "ticket": "OPS-11",
     "status": "stacked", "next": false, "why": "",
     "gate": {"blocked_by": "what is holding it", "kind": "decision | verification",
              "resolved_by": "the thing that settles it", "outcomes": ["optional"]}}
  ]
}
```

**Rows key on `ref`, not repo + number.** `ref` is already the one canonical key used everywhere in this schema, so
keying rows the same way means declared edges need **no ref normalization** — which removes a silent-failure class:
a wrong `Owner/repo` → `repo#num` transform yields edges whose endpoints match no item, so they vanish from the
graph without raising. Any translation to an external system's field names belongs in that system's adapter, not
here.

| field | required | meaning |
|---|---|---|
| `rows[].ref` | yes | canonical item ref; must be unique within the manifest |
| `rows[].order` | yes | declared merge position — `–` for a merged prerequisite, else `E1`/`I2`/`1` |
| `rows[].lane` | no | parallel track; omit on every row for single-stack mode |
| `rows[].gate` | no | why a row is parked; `kind` is closed to `decision` or `verification` |
| `apex` | no | the program's tracker; omit entirely on a small single-ticket program |
| `desc` | no | ONE plain sentence, rendered under the program heading in chain views; `note` stays unrendered |

### Derivation rules

- **Consecutive rows within a lane** → a `stacked` edge. This is the only construct here that can span repos.
- **Every row** → an `apex` edge to `apex.ref`, when an apex exists. `apex` groups (chain edges group, blocking
  edges do not), so a multi-lane program stays one workstream.
- **Separate lanes never link.** Lane ids are prefixed precisely so cross-lane rows imply no total order.
- **`gate.blocked_by` is never turned into an edge.** It is prose — *"waiting on a colleague's review"* names a real
  blocker with no ref to point at. String-matching it would invent a dependency. These are counted and reported as
  `unmapped_gates` instead.
- **`gate.blocked_by_ref`** (optional) → a `blocks` edge. This is the machine-readable companion to the prose field,
  for when the blocker *is* a tracked item. It must contain `#`, because its only job is to be an edge endpoint;
  prose here would produce an edge pointing at nothing, which is precisely what keeping `blocked_by` prose avoids.
  `blocks` does **not** group — it is a dependency *between* workstreams, so merging on it would collapse a blocker
  into its own victim and lose the dependency.

Without `blocked_by_ref` the schema could express no dependency at all. The backfill made that concrete: **14 of the
72 recorded historical edges are `blocks`**, and they are the least recoverable kind, since `stacked` can be
re-derived from branch topology for anything still open while a dependency is pure judgment.

### Planned: row-level `after: [refs]` (not yet implemented)

Lanes express linear tracks only. The approved chain-map rendering treats every program as a topological
grid (a linear chain is a one-column DAG), and true forks — one PR unblocking several that all go ready
simultaneously — need declared parents: a row-level `after: [refs]` list. Derivation rule when it lands:
explicit `after` overrides consecutive-row inference within the lane; READY = open AND every parent
merged; all READY nodes are next simultaneously. Recorded here so a review of this contract evaluates the
shape the consuming program needs, not just today's fields.

### `decision` vs `verification`

`kind` is closed to two values because they route differently. A `decision` means a **human must choose**, so it is
a blocker on a person. A `verification` means **someone must run something** — anyone can, so it is *never* a
blocker on a person and must not be routed to the awaiting-you tier. Both `blocked_by` and `resolved_by` are
mandatory: a blocker naming nothing that would unpark it is the defect the field exists to prevent.

### Edge provenance

Every edge in the gather now carries `source: "derived" | "declared"`, and `meta.edge_provenance` reports the
counts plus two things that would otherwise fail silently:

- **`conflicts`** — declared says A → B while topology says B → A. Usually a rebase moved a base branch out from
  under the plan. Surfaced as a `warn` row in the existing health panel, never auto-resolved: picking a winner
  would hide the drift.
- **`dangling_endpoints`** — edge endpoints matching no gathered item. These render as *nothing at all*, so silent
  disappearance is the failure mode and a count is the guard.

On a duplicate, **declared wins**: topology is an inference, a manifest row is stated intent.

### Validation

`validate()` reports **every** problem in one pass, so a manifest is fixed in one edit rather than N runs, and
callers must treat a non-empty result as fatal **before writing anything**. Discovery is non-fatal by contrast: a
missing directory, malformed JSON, non-manifest JSON, or invalid manifest is skipped with a **named** warning —
one bad file must never blank the spine, and an unnamed skip is indistinguishable from a file that was never there.

### Regenerating will not reproduce today's hand-authored spine

Expected, not a bug. The 2026-07-28 spine grouped work with human insight the gather cannot express — its ids
(`keypair-migration`, `sme-self-service-pat`) do not correspond to the gather's project names, and its
granularity differs. The overlay is how that judgment is carried forward deliberately, project by project,
instead of being silently approximated.
