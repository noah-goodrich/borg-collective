# Directive: Viz 2 — Give the Spine a Generator
*Filed: 2026-08-11*

Independent project. Second of three decomposed viz directives. Depends on nothing, but is the **root cause** of
the 2026-08-10 failure — viz 1 treats the symptom, this removes the cause.

## Objective
Make `story.json` — the cross-repo project/workstream spine — **derivable and refreshable** instead of
hand-authored. Split it into a machine-derived skeleton that regenerates from every recon gather, and a small
persisted judgment overlay that survives regeneration.

## Why

`story.json` has **no generator**. Nothing in the repo writes it: `render_graph.py` only reads it, and neither
`SCHEMA.md` nor `PROTOCOL.md` documents where it comes from. It was authored by hand in a session on
**2026-07-28T16:15Z** and froze at that moment. Thirteen days later it had never heard of `infrastructure#2564`
or `#2566` — the exact PRs the orchestrator spent 51 seconds of model time reconstructing by hand.

Two compounding facts made this worse than a plain staleness bug:

1. **A stale spine looks authoritative.** It carries eight projects, 34 workstreams, ~426 items, 72 typed edges,
   and confident prose. Nothing in the rendering says "this is a picture of two weeks ago."
2. **The gather half was also dead.** `borg recon` had been inert since #95 (fixed 2026-08-11 in #113), so even
   if something had wanted to refresh the spine, its input was empty.

The capture principle from the cairn decommission applies directly (CLAUDE.md, Learned): *build capture that
derives from an artifact the agent already produces; never build capture that asks the agent to volunteer.* A
hand-authored spine is volunteered capture — and four prior shipped attempts at volunteered capture produced one
real row in five months.

**The raw gather already carries the graph.** Per `curate.py`'s documented input shape:

```
items:  [ {ref, project, repo, source, title, state, changed, owner, url,
           one_line, urgency, action_needed, is_entrypoint, blocked} ]
edges:  [ {parent, child, kind} ]
```

`project` groups items into projects. `edges` with a `kind` are the dependency graph. `blocked` is per-item. So
the *skeleton* is derivable. What is not derivable is judgment: project `priority`, human-readable `name`,
workstream `title`, and the `summary` prose that made `sme-self-service-pat` legible.

## Acceptance Criteria

- [ ] S1 — A generator produces the spine skeleton from a recon gather: projects grouped from `items[].project`,
      workstreams derived from `edges`/`parallel_group`, `blocked_by` derived from `edges` of blocking kind.
  - Verify: running it against `merge-tree/fixtures/gather.raw.json` produces a spine that validates against
    `SCHEMA.md` and contains every project present in the fixture.
- [ ] S2 — Judgment persists across regeneration in a **separate overlay file**, keyed by stable ids
      (`project.id`, and a stable workstream key). Regenerating never destroys `priority`, `name`, `title`, or
      `summary`.
  - Verify: generate → hand-edit a `summary` in the overlay → regenerate → the edited summary survives, and a
    round-trip test asserts it.
- [ ] S3 — **Structured state and narrative summaries are aged separately.** Each carries its own timestamp,
      because the summary is simultaneously the highest-value and most perishable field in the spine.
  - Verify: the spine has both a `generated_at` for the skeleton and a per-summary `authored_at`; a summary older
    than its skeleton is detectable programmatically.
- [ ] S4 — Staleness is surfaced loudly and refuses to masquerade as current. Beyond a threshold, `borg link` and
      the renderer both state the spine's age and print the refresh command rather than presenting chains as fact.
  - Verify: with a spine older than the threshold, both surfaces carry an explicit staleness warning; with a
    fresh one, neither does.
- [ ] S5 — Orphan detection: items present in the gather but absent from the spine are reported, not silently
      dropped. `infrastructure#2564` was exactly this case.
  - Verify: a fixture with an item whose project is unknown to the overlay produces a named orphan report.
- [ ] S6 — One documented command refreshes everything end to end, and `SCHEMA.md`/`PROTOCOL.md` finally state
      the spine's provenance (the gap that let it look hand-maintained-by-design).
  - Verify: the command exists, is documented, and `grep -i 'story.json' merge-tree/SCHEMA.md` describes how it
    is produced.
- [ ] S7 — Regression: full bats suite and macOS contract leg green; existing renderer output unchanged when run
      against an unchanged spine.

## Scope Boundaries
- NOT mining the orchestrator's session transcripts to auto-write summaries. Tempting — that analysis *is* an
  artifact the agent already produces — but it is a separate, harder directive and depends on this one landing
  first. Record it as follow-on, do not attempt it here.
- NOT adding ranking (viz 3) or the awaiting-you tier (viz 1).
- NOT changing the renderer's visual design.
- NOT auto-refreshing on a timer. Refresh is explicit and visible until it is proven trustworthy.
- If done early: ship, don't expand.

## Ship Definition
PR against main, CI green, a round-trip test proving judgment survives regeneration, and a real refresh run
recorded in the PR body showing the spine's `generated_at` moving forward and any orphans named.

## Timeline
Two sessions. S1–S2 is the substance; S3–S6 are small once the split exists.

## Risks
- **The overlay's stable keys are the whole design.** If a workstream key is derived from a mutable field
  (title, ordering), regeneration silently loses judgment and this directive makes things worse than
  hand-authoring. Decide the key scheme before writing the generator, and test key stability against a
  perturbed gather explicitly.
- **The derived skeleton may be worse than the hand-authored one at first.** A human grouped 426 items into 34
  workstreams with real insight. Naive grouping from `edges` will not match that. Accept a worse-but-fresh spine
  over a better-but-frozen one only if S4's staleness warning is genuinely prominent — otherwise this trades a
  known problem for a subtler one.
- **`curate.py` and this generator could drift into two sources of truth.** `curate.py` already turns a gather
  into `data.json`. Decide explicitly whether the spine generator is a sibling stage or a new stage *inside*
  curate, and write it down. Two independent gather-consumers is how the `render.py`/`render_graph.py`
  divergence happened — that split is precisely why the awaiting-you tier ended up in a dead file.
