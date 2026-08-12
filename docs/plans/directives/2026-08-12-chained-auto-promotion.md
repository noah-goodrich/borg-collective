# Directive: Chained Auto-Promotion for `borg-assimilate`

*Filed: 2026-08-12*

Independent project. Derived from a same-day retro across all registered projects, a 4-candidate design panel
(each candidate designed blind by a separate agent), 3 independent judges (unanimous on the winning mechanism),
a 6-voice Collective adversarial review, and The Adult's final synthesis.

## Why this exists

A retro across every registered project found the `directive -> PROJECT_PLAN.md -> assimilated` lifecycle has
quietly stopped being used for most real work, everywhere it was checked:

- **ingle**: 31 pending directives, 104 assimilated. The gate was used rigorously for ~3.5 months (34-38
  promote/ship cycles, essentially 1:1 with PR batches), then went idle on 2026-07-24 while filing continued.
  `write-path-unification` shipped across 6+ merged PRs and still sits in `directives/` marked `Status: ACTIVE`,
  never assimilated. The **current** `PROJECT_PLAN.md` is itself stale — its criteria shipped the same day it
  opened, never checked off.
- **reveal** (28 pending, plan stalled since 2026-06-14), **reveal-data-consistency** (19, duplicating reveal's
  own backlog), **stillpoint** (3 pending, zero ships ever despite an active plan since inception).
- **troth** is the exception that disproves a uniform fix: 18 pending directives but ships continuously (41
  lifetime `PROJECT_PLAN.md` touches, the heaviest use of the gate of any project audited). This looks like a
  throughput mismatch, not neglect.
- **borg-collective itself, this week**: 5 directives filed 2026-08-10/11 (the link-unification split into
  viz-1/viz-2/viz-3/attention-routing) — **zero promoted**. Meanwhile ~10 PRs merged straight to `main` with no
  directive or `PROJECT_PLAN.md` involved at all. One exception (`testing-posture B+D`) touched
  `PROJECT_PLAN.md` for 3 minutes — created and deleted in the same breath, a rubber stamp, not a real
  lock-then-execute cycle.

**The root cause**: filing a directive is a single, rewarded, voluntary action. Promoting it to
`PROJECT_PLAN.md` is a *second*, separate, effortful, unrewarded action with no automatic trigger — the same
shape of failure this repo already diagnosed and wrote down for cairn (CLAUDE.md, Learned): *"build capture
that derives from an artifact the agent already produces; never build capture that asks the agent to
volunteer."*

**The natural experiment that governs this directive's design**: on 2026-08-11, a single overloaded directive
was manually decomposed into 4 smaller, independently-shippable files (viz-1 through attention-routing) — the
exact "break it into small parts" instinct. It did not solve the shipping problem. ~24 hours later, all four
still sit unpromoted. **Smaller files alone do not fix this.** The missing piece is still the unrewarded
promotion step, at any granularity. A fully-specified version of file-level decomposition (directory-as-
directive, one part per file) was one of the four candidates the design panel considered; all three judges
independently ranked it below a mechanism that closes the promotion gap directly, precisely because of this
evidence. It is not being adopted here — not because the idea was bad, but because this repo's own data this
week falsifies it as a *sufficient* fix on its own.

## The mechanism

Extend `skills/borg-assimilate/SKILL.md` Step 4b (currently ends at "remove `PROJECT_PLAN.md` from project
root") with a mandatory **Step 5**, reusing the exact scan idiom Step 0.75 already ships in production (it
already greps `docs/plans/directives/*.md` for `*Parent plan:*` lines to block on unresolved children — this
is the same grep, running after archival instead of before it):

- Scan `docs/plans/directives/*.md` for top-level candidates (no `*Parent plan:*` line).
- **Zero candidates**: silent no-op.
- **Exactly one candidate, or one carrying a `*Next: <slug>*` line pointing back from the plan that just
  shipped**: run `borg start <slug>` immediately, report `✓ Auto-promoted <slug>`.
- **Two or more, no `*Next:*` signal**: ask one bounded question, stop.
- **A `*Next:*` pointer to a nonexistent slug**: falls through to the multi-candidate branch rather than
  crashing.

This rides on an action (`borg-assimilate`) that is already mandatory and disciplined, so promotion stops
being a second thing anyone has to remember. It adds exactly one new thing for Noah to notice: a line after
`borg-assimilate` finishes, either the auto-promote confirmation or one bounded question — not a new
interrupt channel, not a new CLI verb, not a new background process.

## Acceptance Criteria

- [ ] **AC1** — `skills/borg-assimilate/SKILL.md` gets a new Step 4c, between "Archive `PROJECT_PLAN.md`" and
      the end of Step 4b, written in Step 0.75's own style: literal grep patterns embedded in the prose.
  - Verify: `grep -n "Step 4c" skills/borg-assimilate/SKILL.md` matches; the step text contains both literal
    patterns `^\*Parent plan:` and `^\*Next: `.
- [ ] **AC2** — The `*Parent plan:*` and `*Next:*` line conventions are documented once, outside the skill
      file (`*Parent plan:*` has been live since `borg-plan`'s "Follow-Up Directives" section but was never
      written down anywhere central).
  - Verify: `docs/plans/directives/README.md` exists; `grep -c '\*Next:\|\*Parent plan:' docs/plans/directives/README.md` returns 2 or more.
- [ ] **AC3** — Candidate-scan and next-slug logic is bats-tested against fixtures: zero top-level candidates
      (silent no-op), exactly one candidate (auto-promote), two-plus with no `*Next:*` (ask one bounded
      question, stop), a `*Next:*` pointer that resolves even when two-plus raw candidates exist (chain wins
      over count), and a dangling `*Next:*` pointer to a nonexistent slug (falls through to the count branch,
      does not crash).
  - Verify: `bats tests/promote_next.bats` exits 0 with at least 5 `@test` cases; `grep -c '@test.*dangling' tests/promote_next.bats` returns 1 or more.
- [ ] **AC4** — viz-1 -> viz-2 -> viz-3 is wired as a real, working chain, not just described.
  - Verify: `grep -c '^\*Next: viz-2-spine-generator\*' docs/plans/directives/2026-08-11-viz-1-awaiting-you-tier.md` = 1;
    `grep -c '^\*Next: viz-3-cross-repo-chains\*' docs/plans/directives/2026-08-11-viz-2-spine-generator.md` = 1.
    `attention-routing` gets no `*Next:*` — it's independent of the viz chain.
- [ ] **AC5** — Step 4c reports its outcome as one of two fixed strings so behavior is greppable and stable
      across future edits.
  - Verify: `grep -c '✓ Auto-promoted\|candidates, none chained' skills/borg-assimilate/SKILL.md` returns 2.
- [ ] **AC6** — Regression: this touches a markdown skill file with no executable surface of its own, so the
      guard is that nothing else broke.
  - Verify: `bats tests/*.bats` exits 0.

## Scope Boundaries — named, not silently dropped

The design panel's synthesis proposed considerably more (a `borg link` attention-pointer with a 4-tier
staleness table, per-project WIP limits, a `borg tidy` backlog-triage extension, PR-level plan-linkage
tagging). The Adult's final review cut all of it as gold-plating relative to what this pass actually needs to
prove. Each of these is a legitimate candidate for its **own** directive, filed only after this one ships and
only if the data from this one justifies it:

- **NOT** `lib/attention.sh` / a `borg link` staleness tier table — deferred until viz-1/viz-2 actually exist
  to feed it; building it now would sequence the consumer ahead of the producer (a real bug the Craftsperson
  caught in the fuller synthesis).
- **NOT** `borg wip-limit` or any per-project WIP machinery — troth's manual promotion already works (41
  lifetime touches, ships every ~15 days); do not add process to the one project that doesn't need it.
- **NOT** a `borg tidy` extension to triage ingle's 31 or reveal's 28+19 pending directives — a real problem,
  but a one-time cleanup pass, not new permanent CLI surface. Worth its own directive.
- **NOT** `pre-commit-remind` plan-linkage tagging, and **NOT** a CI/PR-merge gate on plan linkage — this is
  the correct fix for the larger problem named below (PRs merging with zero directive involvement) but is a
  bigger, cross-repo-touching design of its own.
- **NOT** cold-start: Step 5 never fires for a directive's *first* promotion, only for continuation after a
  ship already happened.
- **NOT** cycle detection on `*Next:*` chains (A -> B -> A). Unhandled by design in this pass — see Risks.
- If done early: ship, don't expand.

## Ship Definition

PR against `main`, full bats suite green including the new `promote_next.bats`, `*Next:*` lines present as
committed content in viz-1 and viz-2 (not merely described in this directive), `docs/plans/directives/README.md`
committed. Dogfooded on the next real assimilate: when the in-flight `python-core-and-toolchain` plan ships,
Step 4c's actual console output — not an assertion that it would work — gets pasted into that PR's description.

## Timeline

One session. A skill-file edit, one new short README, two one-line metadata additions to existing files, and
one new bats file exercising pure grep logic against fixtures. No new `lib/` module, no new CLI verb, no new
`registry.json` field.

## Risks

- **Unverifiable trigger.** Whether Claude actually executes Step 4c on a given run can't be bats-tested — the
  same limitation Step 0.75 already carries in production today. If it silently doesn't fire, the failure mode
  is "nothing happens," identical to today's status quo, not a regression — but also not proof of enforcement.
- **`*Next:*` only exists where someone hand-wires it at decomposition time.** For undifferentiated backlogs
  (ingle's 31, reveal's 28) Step 5 degrades to "ask one bounded question" on every assimilate. Accepted as a
  named floor: this directive's benefit concentrates on already-decomposed chains, not the bulk of either
  backlog. The backlog cleanup itself is out of scope here (see Scope Boundaries).
- **The upstream-bypass problem is the largest unresolved finding in the whole retro, and is explicitly not
  addressed here.** PRs merging to `main` with zero plan involvement is the *dominant* real path to shipped
  code in borg-collective this week (~10 of ~10 non-python-core PRs). This mechanism only fires inside a world
  where a directive or `PROJECT_PLAN.md` already exists — it does nothing for work that never enters the
  system at all. Track as a follow-up candidate directive once this one has a real data point to build on.
- **Dangling or cyclical `*Next:*` pointers fail safe** via `cmd_start`'s existing "already in-flight" guard
  rather than corrupting state, but surface an unhelpful raw error. Acceptable for a first pass; revisit the
  message only if it actually occurs.
- **troth needs the opposite of what most projects need.** This directive does not change troth's behavior at
  all (WIP-limit work was cut) — worth confirming after a few cycles that a mechanism tuned for ingle/reveal's
  failure mode isn't quietly adding friction to troth's, even though nothing here should touch it directly.
