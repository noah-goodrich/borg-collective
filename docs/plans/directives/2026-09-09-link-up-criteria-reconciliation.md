# Directive: Link-up criteria reconciliation — flip checkboxes from evidence already in hand

*Filed: 2026-09-09 · Status: Active · Amended: 2026-09-10*

## Why this exists

The 2026-08-20 completion audit measured ingle's `PROJECT_PLAN.md` at 0/7 criteria met while the checkpoint
claims Phase 1 is "effectively complete" and AC1 is done. This is not an ingle problem — it is the same
volunteered-capture rot the completion audit measured at scale: 27% of criteria checked against roughly double
real completion, 47% of directives shipped but never recorded.

The chained-auto-promotion directive (`2026-08-12`) names the root cause: *"build capture that derives from an
artifact the agent already produces; never build capture that asks the agent to volunteer."* Link-up is the
artifact that already carries both halves of the reconciliation:

1. It reads `PROJECT_PLAN.md` to understand the session's scope.
2. It builds an "Accomplished" list of concrete deliverables.

It then writes a checkpoint and walks away. The comparison — "which criteria does the Accomplished list
satisfy?" — is never performed. The gap between "work done" and "criteria recorded as met" grows silently
until someone manually triggers `/borg-assimilate`, which is designed for the shipping moment, not mid-plan
bookkeeping.

The directive-state-deriver (`2026-08-20`) addresses directive-level status via git history. This is
complementary: it addresses `PROJECT_PLAN.md` criteria during the session flush, using same-session evidence,
not git archaeology.

## The mechanism

Extend `skills/borg-link-up/SKILL.md` with a criteria reconciliation step between "build the checkpoint" and
"write to disk":

1. **Read `PROJECT_PLAN.md`** from the project root. If absent, skip silently (no plan = nothing to reconcile).
2. **Parse unmet criteria** — lines matching `- [ ] ` under the acceptance criteria heading.
3. **Compare each unmet criterion against the Accomplished list** the skill just built. For each criterion,
   determine whether the session's deliverables constitute evidence of completion. Apply the same standard
   `borg-assimilate` Step 2 uses: grep/glob/read verification against the codebase, not vibes.
4. **For criteria with clear evidence: flip the checkbox** (`- [ ]` → `- [x]`) in `PROJECT_PLAN.md` and
   append a one-line evidence annotation (e.g., `- [x] AC1 — ... *(flipped by link-up: PR #368 merged,
   runner deployed)*`).
5. **For criteria without clear evidence: leave unchanged.** No partial credit, no "probably met." The
   standard is the same as assimilate — if you cannot point to a file, a merged PR, or a passing test, it
   stays unchecked.
6. **Report in the checkpoint.** Add a `## Criteria Reconciled` section to the checkpoint listing which
   criteria were flipped and why. This makes the reconciliation auditable without reading the plan diff.

The annotation format (`*(flipped by link-up: <evidence>)*`) is machine-greppable and distinguishes
link-up flips from manual edits and assimilate flips, so the completion audit can measure whether this
mechanism actually closes the gap.

## What this does NOT change

- **`borg-assimilate` remains the shipping gate.** It still evaluates all criteria independently at ship time.
  Link-up flips are bookkeeping, not authorization. Assimilate can disagree and un-flip if evidence has
  regressed.
- **No new CLI verb.** This rides on an action (`/borg-link-up`) that is already the standard session-end
  discipline.
- **No auto-archiving.** Flipping criteria is not shipping. A plan with 7/7 met still requires
  `/borg-assimilate` to archive.
- **No directive-level status changes.** That is the directive-state-deriver's job.

## Amendment — 2026-09-10: the evidence gate is mechanical, not judged

Ratified by Noah 2026-09-10, choosing "evidence-gated write" over "propose only" and over "write on session
judgment". This **tightens step 3 of The mechanism** above and supersedes it where they disagree. The rest of
the directive stands.

**What changes.** Step 3 asks the model to "determine whether the session's deliverables constitute evidence",
applying assimilate's grep/glob/read standard. That is still a judgment call made in a prompt, and the Risks
section already concedes the consequence: *"whether Claude actually executes the reconciliation step on a
given run cannot be mechanically tested."* The amendment splits the criteria in two and treats them
differently:

- **Mechanically checkable -> flipped.** A criterion carrying a machine-readable evidence annotation whose
  check passes is flipped by code, not by judgment.
- **Everything else -> proposed, never flipped.** Written into the checkpoint with its evidence line and the
  command that would apply it. "No partial credit, no probably-met" from step 5 is preserved and hardened: a
  criterion resting on the session's own belief that it finished is never written.

**The annotation (expand phase).** An indented sub-bullet beside the existing prose `- Verify:` line, which is
untouched. Unannotated criteria remain valid and simply resolve to "propose":

```
- [ ] **AC6 — <name>.** <prose>
  - Verify: <the existing prose clause, unchanged>
  - Evidence: `bats:tests/eval_harness.bats`
```

Four kinds, resolving to `pass` / `fail` / `unknown`: `pr:<owner/repo#N>` (merged), `path:<repo-relative
path>` (exists), `bats:<path>`, `pytest:<path>`.

**The annotation never carries a shell string.** It supplies a ref or a path; the runner is selected in code.
A plan file is a document a human edits and a nanoprobe writes, so treating it as a source of commands to
execute would make every checkpoint an arbitrary-code-execution surface.

**`unknown` is not `fail`.** A missing path means the pin rotted, not that the work regressed — the same
defect class as `reference_line_pins_rot_anchor_instead`. `unknown` resolves to "propose"; it never flips and
never reports a regression. Likewise a `pr:` annotation resolves through the provenance `borg link` already
applies, and a degraded source yields `unknown`, matching how `.ready` refuses to answer from declared state.

**This moves the Ship Definition.** "The link-up skill file is the only changed file" no longer holds: a
mechanical gate cannot live in a skill prompt, and the house architecture rule puts logic in a testable core
with the shell as a wrapper. The work is now `borg_core/planstate/` (parser, resolvers, atomic writer, tests)
plus a `--json` / `--apply` CLI, with `skills/borg-link-up/SKILL.md` as its consumer. "No new CLI verb" still
holds — `borg` gains no verb; the skill calls the module.

The annotation format from step 4 (`*(flipped by link-up: <evidence>)*`) is unchanged and still the audit
trail.

## Acceptance Criteria

- [ ] AC1 — `skills/borg-link-up/SKILL.md` gains a criteria reconciliation step that reads `PROJECT_PLAN.md`,
      compares unmet criteria against the session's Accomplished list, and flips checkboxes with evidence
      annotations.
    - Verify: `grep -c 'Criteria Reconcil' skills/borg-link-up/SKILL.md` returns 1 or more.
- [x] AC2 — Flipped criteria carry a machine-greppable annotation distinguishing link-up flips from manual
      edits and assimilate flips. **The engine writes it, in the same atomic write as the flip** (see AC8).
    - Verify (RESTATED 2026-09-11): a fixture plan with one passing annotated criterion is run through
      `--apply`, and the resulting FILE carries `flipped by link-up` on exactly that criterion's line. The
      original clause greppped `skills/borg-link-up/SKILL.md` for the format string — it checked that the
      skill *describes* an annotation, never that one ever reaches a plan file, so it would have stayed green
      through total failure of the behaviour it names. Same shape as
      `reference_test_supplies_derived_value`: the assertion never touched the artifact it was about.
- [ ] AC3 — The checkpoint template gains a `## Criteria Reconciled` section that lists flipped criteria and
      evidence.
    - Verify: `grep -c 'Criteria Reconciled' skills/borg-link-up/SKILL.md` returns 1 or more.
- [ ] AC4 — When `PROJECT_PLAN.md` is absent, the step is a silent no-op — no error, no empty section in the
      checkpoint.
    - Verify: the skill text contains an explicit "If absent, skip" guard.
- [ ] AC6 — (2026-09-10) `borg_core/planstate/` parses criteria and evidence annotations out of a real
      `PROJECT_PLAN.md` and returns `pass`/`fail`/`unknown` per criterion with an evidence line each.
    - Verify: pytest over the parser against fixtures including an unannotated criterion, a malformed
      annotation, a criterion already `[x]`, and a missing path resolving to `unknown` rather than `fail`.
    - Evidence: `pytest:borg_core/planstate/`
- [ ] AC7 — (2026-09-10) Tests drive the production evidence path — a real git/gh/filesystem read — never a
      fixture-supplied verdict, per `reference_test_supplies_derived_value`. Asserted by mutation: break the
      resolver, the test goes red.
- [x] AC8 — (2026-09-10, RESTATED 2026-09-11) `--apply` flips only `pass` criteria and writes atomically. The
      only changes to the file are the checkbox character and, appended to that same line, an annotation
      matching the fixed `*(flipped by link-up: <evidence>)*` pattern. Every other byte is unchanged. A `fail`
      and an `unknown` in the same file survive a run that flips something else.
    - Verify: byte-compare before and after; for each changed line assert the delta is exactly the checkbox
      plus a pattern-matching suffix, and that no other line moved.
    - Evidence: `pytest:borg_core/planstate/test_write.py`
    - **WHY IT WIDENED.** As first written, AC8 said "the only byte that changes is the checkbox character",
      which left AC2's annotation with no writer. Satisfying both then forced a SECOND writer — the skill
      editing the plan file again after the engine's atomic write — and that reintroduced exactly what the
      mechanical gate exists to remove: a model performing a free-form markdown edit on a 120-wrapped
      document, outside the atomicity AC8 promises, once per flipped criterion. A crash between the two
      writes leaves a flipped box with no attribution, which is indistinguishable from a hand edit and
      therefore strictly worse than an unflipped one. The guarantee AC8 is actually for is *bounded,
      provable, non-destructive* — not *one byte* — so the letter widened to keep the guarantee and give the
      annotation a single owner. AC2's property is unchanged; it now has somewhere to come from.
- [ ] AC9 — (2026-09-10) An evidence annotation can never cause command execution from file content: a
      crafted annotation carrying `;`, backticks or `$(...)` is rejected rather than resolved, and no
      subprocess runs.
- [ ] AC5 — `borg-assimilate` remains authoritative. The skill text does not weaken assimilate's independent
      evaluation or treat a link-up flip as sufficient evidence at ship time.
    - Verify: `skills/borg-assimilate/SKILL.md` is unchanged by this directive.

## Scope Boundaries

- **NOT** the directive-state-deriver — that derives directive status from git history; this reconciles plan
  criteria from same-session evidence. Complementary, not overlapping.
- **NOT** a change to `borg-assimilate` — assimilate's criteria evaluation is untouched.
- **NOT** a change to `borg link` or `borg link --json` — the engine reads `PROJECT_PLAN.md` and reports
  `met`/`total`; if link-up flips checkboxes, the engine picks up the new count on the next read
  automatically.
- **NOT** retroactive reconciliation of existing stale plans. This fires prospectively on each link-up. The
  completion audit's 36-item backlog is the directive-state-deriver's problem.

## Ship Definition

PR against `main`. The link-up skill file is the only changed file. Dogfooded on the next real `/borg-link-up`
in a project with an active `PROJECT_PLAN.md` — the checkpoint's `## Criteria Reconciled` section, or its
absence, is the proof.

## Risks

- **False positives.** Link-up flips a criterion the session didn't actually satisfy. Mitigated by requiring
  the same grep/glob/read evidence standard as assimilate, and by assimilate's independent re-evaluation at
  ship time. A false flip is correctable; a stale plan is invisible.
- **Annotation noise.** Every flipped criterion gets an annotation line. If a plan has many criteria flipped
  across many sessions, the plan file gets verbose. Acceptable — the alternative is silent staleness, and
  the annotations are the audit trail.
- **Unverifiable trigger.** Same limitation as chained-auto-promotion: whether Claude actually executes the
  reconciliation step on a given run cannot be mechanically tested. Failure mode is "nothing happens" —
  identical to today, not a regression.
