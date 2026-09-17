# Project Plan: The Shim Layer Made Real — Adapter-Driven Reconcile
*Established: 2026-09-17*

- Plan-slug: `2026-09-17-shim-layer-adapter-reconcile`

*The slug is DECLARED here, never re-derived from the Objective line. One writer (`/borg-plan` at
`02-output`); `borg_core.manifest.cli resolve` and `/borg-assimilate` Step 0.75 read it. Computing it
from prose is what produced a gate that certified while measuring nothing — see
`docs/plans/assimilated/2026-09-15-assimilate-step-075-derives-an-underivable-slug.md`.*

## Objective

Make borg's two existing shim sockets — executable recon adapters and prose skill extensions — a
named, documented, exercised mechanism, and give the chain layer an adapter-driven `borg reconcile`
so a row's live state comes from whichever adapters a machine has rather than from a hardcoded
GitHub call.

## Acceptance Criteria

- [ ] **AC1 — The shim pattern is named once, with its two tiers and the one-directional rule.**
      CLAUDE.md gains one section: executable adapters fire by construction, prose extensions shape
      judgment and are model-discretionary; borg reaches down for employer shims and the employer
      plugin never reaches up for borg.
    - Verify: `bats tests/prose_contracts.bats` gains a case asserting CLAUDE.md names both tier
      words and the directional rule, and that the case FAILS when any one of the three is removed
      (mutation, run and pasted into the PR body). A prose AC with no mechanical check is the
      `AC1 -> cli_contract.bats` coarseness problem one level worse, so this one gets a real gate.
    - Evidence: `bats:tests/prose_contracts.bats`

- [ ] **AC2 — `borg reconcile` ships READ-ONLY, and writes nothing at all.**
      A new `borg_core/reconcile/` package reporting every row whose declared `status` disagrees with
      its resolved state, plus every `decision` gate on an already-merged ref (the #158 class). It
      writes no file, creates no file, and forks no adapter of its own.
    - **The first slice writes nothing, and that is the Collective's finding, not my plan's.** I had
      planned the writer first. The review's case is better and I verified all of it: the
      derived-vs-declared join ALREADY EXISTS and is already pure — `grid.resolve_state`
      (`borg_core/link/grid.py:267`) returns `(state, state_source)` down the
      `swept > fetched > declared > unknown` ladder, `borg link` already performs the adapter sweep
      on every invocation, and a contradiction-report shape to mirror exists at
      `recon/core.py:289`'s `project_contradictions`. So the valuable half is a pure function over a
      grid that is already built, and it needs none of the blocked prerequisites.
    - **The writing half is explicitly NOT in this plan.** It is the item the review sized as its own
      plan, against a writer whose owning directive lists four silent-dataloss paths.
    - Verify: pytest — (a) the report names a contradicting row on a fixture that has one; (b) it
      names nothing on a fixture that agrees; (c) **no file under the fixture repository changes
      bytes or mtime**, asserted over every file, for both fixtures; (d) an AST import walk pinning
      `core.py` pure. Mutation: deleting the disagreement predicate turns (a) red while (b) stays
      green.
    - Evidence: `pytest:borg_core/reconcile/test_core.py`

- [ ] **AC3 — Resolution is adapter-driven, with no hardcoded source name on the path.**
      The report resolves state through the same `recon-adapter-<source>` discovery
      `borg_core/recon/shell.py` already uses, so a machine that drops in `recon-adapter-jira`
      resolves jira rows with no code change.
    - Verify: pytest — with only a stub `recon-adapter-github` on `BORG_RECON_ADAPTER_PATH`, a
      github ref resolves and a jira ref reports unresolved; with a stub `recon-adapter-jira` ALSO
      discoverable, the SAME jira ref resolves. The second arm proves discovery is a predicate
      rather than an allow-list, and it is the work machine's future stated as a test.
    - Evidence: `pytest:borg_core/reconcile/test_shell.py`

- [ ] **AC4 — The employer leak is closed as an absence, and the grep that missed it can fail.**
      In `~/dev/ai-data-engineer`: the `/borg-plan` reference leaves `plugins/` entirely and lives
      only as a work-machine extension file; the portability grep widens from two paths to the whole
      `plugins/` tree.
    - Verify: `bash tests/run-tests.sh` green in that repo; then reintroduce a `borg` string
      anywhere under `plugins/` and confirm the grep FAILS. Presence of a widened path proves
      nothing — the mutation is the evidence, and today the narrow grep prints
      `ok zero borg coupling` while the leak ships.

- [ ] **AC5 — Nothing breaks.** `make test` at its coverage floor, `make lint` 10.00/10,
      `bats tests/` green, `shellcheck` clean over anything new.
    - Verify: all four commands, run and pasted.

## Scope Boundaries

Every exclusion below is a live collision or a measured trap, not a preference.

- **NOT touching any AC5 surface.** The other machine is working AC5 of the One Front Door plan
  right now. Measured: all three lifecycle `SKILL.md` files and `borg_core/manifest/cli.py` carry
  `manifest.cli` invocations from AC5.2. That rules out three things I would otherwise want:
  the shim directive's `allowed-tools` AC (edits `borg-assimilate`), the `cli load` verb deferred
  from #206 (rewires all three skills' prose), and any edit to the manifest write verbs.
  **The `allowed-tools` item is worse than a collision — it CONTRADICTS shipped AC5 text.**
  `skills/borg-assimilate/SKILL.md:196` instructs that the ref is "the one just merged — read it
  from the `gh pr merge` you executed, never from memory." Making `gh pr merge` unreachable deletes
  the only provenance the AC5 `close` step is permitted to use. Whoever does that item must rewrite
  the close-step provenance in the same commit, or two of the three changes ship a silent break.
- **NOT merging the two manifest validators, and that AC should be STRUCK from the shim directive
  rather than re-sequenced.** Its own Notes already say the work is AC7's. The review found the
  sharper reason and I verified it: the shim's verify clause asks only for "a round-trip test
  asserts what the writer emits, the reader accepts", and a borg_core reader→writer round trip
  ALREADY PASSES today — `borg_core/manifest/test_shell.py`'s
  `test_the_writer_persists_no_derived_key`. So the shim AC is satisfiable **without touching the
  cross-implementation asymmetry it names**, while the owning directive
  (`2026-08-31-retire-merge-tree-programs-into-borg-core`) carries five ACs including "no sync can
  delete a declared row". A weaker duplicate of a claim whose real version guards dataloss is worse
  than no claim.
- **NOT growing a personal-machine PR stamper.** The largest item in the shim directive, and the one
  its own Notes warn against on co-authority grounds: the stamper is employer work product derived
  from a colleague's format. Deferred, not dropped.
- **NOT escalating `prefer-tool` to a PreToolUse warning.** #206 shipped the advisory plus its
  bypass oracle deliberately, so that escalation is a decision to make on DATA. Current measurement:
  **1** bypass logged. That is not yet evidence of anything.
- **If done early: ship, don't expand.**

## Ship Definition

PR against `main` from `plan/employer-shim-and-adapter-layer`. CI green on all five lanes. Both
machines' stamps per the #159 protocol (comment stamp at a SHA — self-approval is blocked).
`borg help` updated if a verb is user-facing. One manual `borg reconcile` smoke run against this
repository's own `viz-program` manifest, output pasted into the PR body.

**This plan does NOT merge until the One Front Door plan ships.** Replacing `PROJECT_PLAN.md` on
`main` while AC5 is in flight would break three live readers of the old file: `resolve` rule 3, the
`planstate` reconciliation in `/borg-link-up`, and the nine child directives parented to the old
slug.

## Timeline

Target: 2 sessions. AC1 and AC5 are each under a session and independent of everything else. AC2–AC4
are one sitting for the pure core and one for the adapter fan-out plus its oracles.

## Risks

- **The nine orphans.** Replacing `PROJECT_PLAN.md` leaves nine directives parented to a slug no
  plan declares. Step 0.75 then finds zero children for the new plan and stops blocking on work
  that is genuinely open — a gate going quiet because its subject moved, which is this repository's
  signature failure. Needs a ruling before merge, not after.
- **AC5 requires work in a private repo from a public one.** The plan describes it; the diff cannot
  live here. `borg-collective` was history-scrubbed once already for employer references.
- ~~**Declared fields may be empty in practice.**~~ **MEASURED, and the cairn lesson was half
  right.** `lane` and `order` are 24/24 and `why` is 14/24 — those are not empty and the guard is
  load-bearing. But `apex`, `blocked_by` and `resolved_by` are **0/24**, exactly as the
  voluntary-write lesson predicts. AC2 and AC4 are narrowed accordingly rather than built against a
  population of zero. The general shape holds: the fields a human must volunteer unprompted are the
  empty ones, and the two that are universal (`lane`, `order`) are both written by tooling.
- **Idempotence is trivially true on an empty manifest.** AC2's verify clause names this explicitly
  because the easy version of that test passes without the feature working.
