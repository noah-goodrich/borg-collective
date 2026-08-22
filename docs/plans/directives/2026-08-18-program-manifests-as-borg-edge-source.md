# Directive: Borg-Native Program Manifests + Sync Coordinator

*Filed: 2026-08-18*

Independent project. **Unblocks `viz-3`** (`2026-08-11-viz-3-cross-repo-chains.md`), which cannot start without
`blocks`/`apex` edges.

**borg does not read, import, or path into `ai-data-engineer` anywhere in this design.** borg owns its own program
manifest, in its own schema, under its own `.borg/` convention. A separate coordinator keeps borg's copy and the
employer stacked-PR copy in agreement by writing each through its **own** native skill.

**Sequencing:** PM1–PM10 depend only on `gather.py` (PR #149) and can ship immediately. **PM11's hook wiring is
gated on `2026-08-11-attention-routing.md`** — its output must use that non-interrupting channel rather than adding
another Stop-time nudge. Split the work at that seam rather than blocking the whole directive on it.

## Objective

Give borg a filesystem-native, borg-owned source of cross-repo dependency edges, and a `borg program` command that
acts as supervisor / coordinator / auditor / negotiator between borg's copy and any external system tracking the
same programs — **delegating every write, reimplementing neither side's write path.**

## Two copies, on purpose

There are genuinely two systems tracking the same programs, and they stay separate:

| | borg | employer stacked-PR program |
|---|---|---|
| artifact | `<project>/.borg/programs/<name>.json` | `docs/plans/directives/<program>-stack.json` |
| owner | borg | `ai-data-engineer` |
| written by | borg's native program skill | `stamp_stack.py` |
| consumed by | `gather.py` → `spine.py` → viz, `borg link` | PR bodies + apex issue |
| row key | `ref` (`repo#num`) | `repo` + `number` |

Duplication is the accepted cost of independence. borg must work on a machine that has never heard of
`ai-data-engineer` — which is the personal machine, today. And borg-collective is **public** while the employer plugin
is internal; a public tool whose core view depends on an internal plugin's file format is broken by construction.

**What keeps them honest is the coordinator, not a shared file.**

## Mirrored shape, borg-native key

The stacked-PR format's shape is worth mirroring, because it already expresses what viz-3 needs: `lane` + `order`
declares a merge sequence, and per-row repo makes cross-repo chains first-class. Mirroring it keeps translation
mechanical. borg adopts the shape and three of its principles — **declared, never derived**; `gate.kind` closed to
`decision | verification`; **validate-all-then-fail before writing anything**.

One deliberate divergence: **borg rows key on `ref`**, not `repo` + `number`.

```json
{
  "program": "de1365-strong-auth",
  "apex":    {"ref": "owner/repo#321", "label": "optional program name"},
  "note":    "optional",
  "rows": [
    {"order": "I1", "ref": "owner/repo#2334", "lane": "ingest", "ticket": "",
     "status": "stacked", "next": false, "why": "",
     "gate": {"blocked_by": "what is holding it", "kind": "decision | verification",
              "resolved_by": "the thing that settles it", "outcomes": ["optional"]}}
  ]
}
```

`ref` is already *"the **one canonical key** used everywhere"* per `SCHEMA.md` — `items[]`, `edges[]`, the actions
map, and the annotation join all key off it. Using it here means **edges need no normalization at all**, which
deletes an entire silent-failure class: a bad `Owner/repo` → `repo#num` transform produces edges whose endpoints
match no item, so they vanish without erroring.

Translation between borg's `ref` and the external system's `repo` + `number` happens **in the shim**, which is
where cross-system knowledge belongs and the only place it is allowed to live.

## Architecture

```
                        intent ──> borg program  (coordinator: writes NOTHING itself)
                                        │
                    ┌───────────────────┴────────────────────┐
                    ▼                                        ▼
        borg's native program skill              discovered sync target
        writes .borg/programs/<n>.json           borg-sync-target-<name> (machine-local shim)
                    │                                        │
                    ▼                                        ▼
        gather.py ─> edges[] ─> spine.py         wraps stamp_stack.py ─> PR bodies + apex
                    │                                        │
                    └──────────> borg program plan <─────────┘
                                 audits all three against recon reality
```

The coordinator holds no rendering, no `gh` call, no manifest template, and no knowledge of any external schema.
It resolves intent, dispatches to writers, and reports disagreement.

### Independence, concretely

- borg reads program manifests **only** from `<registered project>/.borg/programs/`. Never any other path.
- No import of, or absolute path into, `ai-data-engineer` — asserted by a test (**PM8**).
- No fixture copied from that repo. borg's fixtures are borg-authored.
- The external writer is **discovered, never hardcoded** — `borg-sync-target-<name>` on `BORG_SYNC_TARGET_PATH`,
  the same rule recon already applies to adapters (*"Sources are NEVER hardcoded"*). The shim is machine-local in
  the config dir, committed to **neither** repo, and is the only component aware both systems exist.
- Target absent → borg operates on its own copy alone, successfully and silently.

## Acceptance Criteria

**PM1 — borg's schema is borg's, documented and validated independently.** The shape above is specified in
`merge-tree/SCHEMA.md` as a borg contract, with no reference to any external format as its authority. Validation
reports **every** offending row in one pass and exits non-zero **before writing anything** — `gate` requires
`blocked_by` and `resolved_by`, and `kind` is closed to `decision` | `verification`. A malformed manifest can never
half-write.

**PM2 — Discovery is scoped to borg's own convention.** `<project>/.borg/programs/*.json` across registered
projects, config dir shadowing the repo dir per `BORG_RECON_ADAPTER_PATH` semantics. A missing directory,
unreadable file, or malformed JSON is skipped with a **named** warning on stderr, never fatal — one bad manifest
must not blank the spine. A test asserts no path outside a registered project's `.borg/` is ever opened.

**PM3 — Edge derivation, with cross-repo proven.** Rows group by `lane`, sort by `order` (numeric suffix within
the lane prefix; `–` prerequisites first); consecutive rows yield a `stacked` edge. Every row yields an `apex` edge
to `apex.ref` when `apex` is present, and none when absent. A **borg-authored** fixture must express a three-repo
program and assert that one lane produces a chain spanning three distinct repos landing in **one workstream**. A
test that passes without a genuine cross-repo edge does not satisfy this.

**PM4 — Prose gates are unmapped, not drift.** `gate.blocked_by` is prose, so it must **never** be string-matched
into an edge. Unmappable gates are counted and reported as `unmapped_gates`, distinct from drift and from errors. A
gate reading *"waiting on Kelly's review"* is correct input, not a defect.

**PM5 — Every edge carries provenance.** `source: "derived" | "declared"` — `derived` for branch-topology edges
from `gather.derive_stacked_edges`, `declared` for manifest edges. Satisfies viz-3's **X6**. On a duplicate
parent/child pair, `declared` wins and the collision is counted: the owner's stated order outranks inferred
topology.

**PM6 — The coordinator delegates every write.** `borg program list | plan | sync`. `plan` is a dry run reporting
what would change on **both** sides, exiting non-zero only on malformed input. `sync` dispatches to borg's native
writer and to the discovered target. Grep-level tests assert the coordinator contains no `gh` invocation, no
PR-body template, and no external-schema field names.

**PM7 — The audit is three-way and never auto-resolves.** Compare borg's copy, the sync target's copy (via its
dry-run output), and **reality** from recon. Report: rows present in one copy and not the other; status
disagreements between copies; and rows either copy marks `merged` that recon reports `OPEN`. Surface all of it in
recon's existing contradiction idiom — **never silently reconcile.** Drift is a finding for a human; auto-fixing it
would recreate exactly the failure this program exists to prevent. Negotiation means proposing a resolution and
naming which side it would change, not applying one.

**PM8 — Independence asserted mechanically.** A test greps the new code and fixtures for any import of, or absolute
path into, `ai-data-engineer` and fails on a hit. The full suite must pass on a machine where that repo does not
exist — verified by running it with the path renamed, not by inspection.

**PM9 — Personal-machine parity is tested.** With an empty `BORG_SYNC_TARGET_PATH`, `list`/`plan`/`sync` all
succeed against borg's copy alone and state plainly that no publish target was found.

**PM10 — Tests drive the real path.** borg-authored fixtures under `merge-tree/fixtures/programs/`. New modules
join the `--fail-under=85` coverage floor in the `Makefile`. Per `2026-08-13-recon-untested-branches.md`, tests
exercise the real branch rather than asserting a fallback.

**PM11 — Triggering: audit automatically, never publish automatically.** The audit runs unprompted; the write path
never does.

- **Session end (`Stop`)** runs the audit in its **local-only** form — borg's copy against recon state, no network.
  It must **never** invoke `sync`, and never invoke the external target's dry-run: that costs a `gh pr view` per row
  and would put N network round-trips on every session end. The full three-way comparison happens only on an
  explicit `borg program plan`.
- **`sync` is human-invoked, always.** It mutates PR bodies and apex issues on GitHub; no hook may trigger it. A
  test asserts no hook path can reach the write dispatch.
- **Mid-session detection is mechanical, not judgment.** A cross-project reference is detected by matching
  ref-shaped tokens (`owner/repo#num`) whose repo differs from the current project — not by an agent deciding it
  noticed one. Judgment-based capture is the shape that produced one real row in five months across four surfaces
  (CLAUDE.md, Learned: cairn). Detection feeds the **audit** only, never the writer. `UserPromptSubmit` is not
  currently a registered event and would have to be added.
- **Output routes through the attention-routing channel** (`2026-08-11-attention-routing.md`), not a new Stop-time
  interrupt. That directive exists because advisory hooks interrupt sessions they cannot inform; a fresh nudge here
  would deepen the problem it is meant to fix. **Sequencing consequence: PM11's hook wiring is gated on
  attention-routing landing.** Everything else in this directive is independent of it and can ship first.
- **Fail-open, like every other borg hook.** A missing manifest, absent target, or audit error exits 0 and prints
  nothing that blocks a session.

## Scope Boundaries

**In scope:** borg's manifest schema + validator, discovery, edge derivation with provenance, `borg program`, the
three-way audit, the discovered-target interface, borg-authored fixtures and tests.

**Out of scope:**

- Reading, importing, validating, or depending on any external plugin's artifact or schema.
- Writing PR bodies or apex issues from borg. Delegated through the shim, always.
- The shim itself (`borg-sync-target-stacked-pr`) — machine-local, work machine, committed nowhere. This directive
  defines the interface it satisfies, not the file.
- Migrating existing external manifests into borg's format. A one-off import is a separate, optional task.
- Jira as an edge source. `ticket` is display-only.
- viz-3's ranking. This supplies edges; viz-3 consumes them.

## Ship Definition

`borg recon --json | python3 merge-tree/gather.py --programs-dir <project>...` emits cross-repo `declared`
edges from `.borg/programs/*.json` on live data (`borg program` is the registry-resolving caller; gather's
own registry wiring lands with `borg chains`, per comms-delivery-surfaces S2); `make spine` groups a
three-repo lane into **one workstream**;
`borg program plan` reports drift across both copies and reality without writing; `borg program sync` writes borg's
copy and dispatches the external one through the discovered target on the work machine, and cleanly skips that half
on the personal machine; the suite passes with `ai-data-engineer` renamed off the filesystem.

## Risks

**Two copies can diverge — that is inherent, not a bug to design away.** The coordinator is the entire mitigation,
so PM7 is load-bearing and not optional. Collapsing to one shared copy would trade this risk for a dependency on an
external plugin, which is the worse trade and is explicitly rejected.

**borg's manifest is hand-maintained, which is the cairn failure shape.** Voluntary-write surfaces have a bad
record here: four shipped, one real row in five months. The mitigation is that `borg program sync` writes borg's
copy **as a side effect of an action the owner already takes** (re-stamping a program), rather than asking anyone to
maintain a second file by hand. If that dispatch path isn't used, this artifact will rot — and the honest fallback
is that cross-repo `blocks` edges don't exist and viz-3 ranks on within-repo stacks plus deadlines only.

**Manifest staleness becomes load-bearing on the viz.** Drifted rows make the spine confidently wrong — the exact
`story.json` failure mode. PM7's reality check against recon is the guard.

**Discovery could pick up unrelated JSON.** Require a positive shape check (`rows[]` present and a list) before
treating a file as a manifest, and name what was skipped.
