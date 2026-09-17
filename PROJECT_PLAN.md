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

- [ ] **AC2 — `borg reconcile` ships, adapter-driven, idempotent, and never destructive.**
      A new `borg_core/reconcile/` package: pure core (field classification, contradiction
      detection) plus an impure shell (adapter fan-out, atomic write). Derived fields are
      overwritten every run; declared fields (`lane`, `why`, `after`, `apex`, cross-repo `order`)
      are never touched and never deleted; degraded mode writes nothing and says so.
    - **Measured before building, 2026-09-17, across 5 manifests / 24 rows:** `lane` 24/24,
      `order` 24/24, `why` 14/24, `after` 2/24, `gate` 4/24, and **`apex` 0/24, `blocked_by` 0/24,
      `resolved_by` 0/24**. So the declared-field guard protects `lane`/`order`/`why` — real
      populations — and is VACUOUS for `apex`. It is still written for `apex`, because the cost is
      one dict key and the alternative is a guard that silently stops covering a field the moment
      someone uses it; but it is named here as unexercised rather than claimed as tested.
    - **`state` is 0/24.** The field reconcile exists to DERIVE is absent from every manifest today,
      so the first run is purely additive and "overwritten every run" has no existing data to
      overwrite. Good news for migration, and a reason the idempotence test must build its own
      two-run fixture rather than leaning on repository data.
    - Verify: pytest — (a) two consecutive runs produce a BYTE-IDENTICAL file, asserted on a
      manifest that actually has rows and declared fields, not an empty one; (b) an unresolvable
      edge survives a run; (c) with no adapter discoverable, the file is unchanged and the exit
      says why; (d) an AST import walk pinning `core.py` pure. Plus mutation: deleting the
      declared-field guard turns (b) red.
    - Evidence: `pytest:borg_core/reconcile/test_core.py`

- [ ] **AC3 — Live state comes from adapters, with no hardcoded source name on the path.**
      `reconcile` resolves a row's state through the same `recon-adapter-<source>` discovery
      `borg_core/recon/shell.py` already uses. A machine with only `recon-adapter-github` resolves
      github rows; a machine that drops in `recon-adapter-jira` resolves jira rows with no code
      change.
    - Verify: pytest — with only a stub `recon-adapter-github` on `BORG_RECON_ADAPTER_PATH`, a
      github ref resolves and a jira ref reports unresolved; with a stub `recon-adapter-jira` ALSO
      discoverable, the SAME jira ref resolves. The second arm is the one that proves discovery is a
      predicate rather than an allow-list, and it is the work machine's future stated as a test.
    - Evidence: `pytest:borg_core/reconcile/test_shell.py`

- [ ] **AC4 — A contradiction is reported, never guessed.** A `decision` gate on an already-merged
      PR (the #158 class) is named in reconcile's output and changes no byte of the manifest.
      **Scoped to `gate` by measurement:** 4 of 24 rows carry a `gate`, so that class has a real
      population. `blocked_by` and `resolved_by` are 0/24, so their contradiction reporting is
      deferred rather than built against nothing — the shim directive's table lists all three
      together and the measurement splits them.
    - Verify: pytest with a fixture manifest carrying exactly that shape; assert the report names
      the row AND that the file's bytes and mtime are unchanged.
    - Evidence: `pytest:borg_core/reconcile/test_core.py`

- [ ] **AC5 — The employer leak is closed as an absence, and the grep that missed it can fail.**
      In `~/dev/ai-data-engineer`: the `/borg-plan` reference leaves `plugins/` entirely and lives
      only as a work-machine extension file; the portability grep widens from two paths to the whole
      `plugins/` tree.
    - Verify: `bash tests/run-tests.sh` green in that repo; then reintroduce a `borg` string
      anywhere under `plugins/` and confirm the grep FAILS. Presence of a widened path proves
      nothing — the mutation is the evidence, and today the narrow grep prints
      `ok zero borg coupling` while the leak ships.

- [ ] **AC6 — Nothing breaks.** `make test` at its coverage floor, `make lint` 10.00/10,
      `bats tests/` green, `shellcheck` clean over anything new.
    - Verify: all four commands, run and pasted.

## Scope Boundaries

Every exclusion below is a live collision or a measured trap, not a preference.

- **NOT touching any AC5 surface.** The other machine is working AC5 of the One Front Door plan
  right now. Measured: all three lifecycle `SKILL.md` files and `borg_core/manifest/cli.py` carry
  `manifest.cli` invocations from AC5.2. That rules out three things I would otherwise want:
  the shim directive's `allowed-tools` AC (edits `borg-assimilate`), the `cli load` verb deferred
  from #206 (rewires all three skills' prose), and any edit to the manifest write verbs.
- **NOT merging the two manifest validators.** The shim directive's own Notes say this is AC7's work
  under the One Front Door plan — *"do it there, not twice."* Two plans claiming one deliverable is
  how two machines implement it twice.
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
