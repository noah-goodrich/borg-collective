---
name: borg-assimilate
description: >
  Shipping checklist + execution. Evaluates current state against PROJECT_PLAN.md acceptance
  criteria, then executes shipping (merge PR, archive plan) with confirmation. Use when you
  think you might be done, or when you're tempted to add "one more thing."
user-invocable: true
---

# Borg Assimilate — You Will Be Assimilated

You are evaluating whether this project is ready to ship. Be rigorous. Do not rubber-stamp.
Do not add new requirements. Check exactly what the plan says, nothing more.

## Local Extensions: 01-context

Before Step 0, check for local extension files. Read each file below that exists and treat its
contents as additional instructions for this phase (e.g. fetching ticket state, running
project-specific pre-ship checks). Read in order; later files extend or override earlier ones.

1. `~/.config/borg/extensions/skill-extensions/borg-assimilate/01-context.md`
2. `<project root>/.borg/skill-extensions/borg-assimilate/01-context.md`

If neither exists, skip silently — do not mention extensions, do not warn, do not change behavior.

## Step 0: Run /simplify First

Before anything else, run `/simplify` on the files changed this session. Do not skip this step.
The goal is to catch reuse opportunities, dead code, and unnecessary complexity before they ship.

If `/simplify` is not available or cannot be auto-invoked, say:
"**Run `/simplify` on the changed files before we ship. List the files here, then continue
shipping once you've confirmed simplify has run.**" Do not proceed past this step until the
developer confirms `/simplify` has run.

## Step 0.5: Run Tests and Linting

After `/simplify`, run the project's test suite and linters. Auto-detect what's available:

1. Check `.github/workflows/*.yml` for test/lint commands (bats, shellcheck, pytest, npm test, etc.)
2. Check for common test runners: `bats tests/*.bats`, `pytest`, `npm test`, `make test`
3. Check for linters: `shellcheck hooks/*.sh`, `eslint`, `ruff`, etc.

Run whatever you find. Report results as part of the checklist regardless of whether a plan exists.
If tests or linting fail, that's a blocker — the project is not ready to ship.

## Step 0.75: Check for Un-Resolved Child Directives

Before evaluating acceptance criteria, check whether any directives in `docs/plans/directives/`
carry a `*Parent plan:*` line whose slug matches this plan.

**Do not compute the slug.** Run the helper; it reads the slug the plan declares about itself:

```
source lib/promote-next.sh
slug=$(_borg_plan_declared_slug PROJECT_PLAN.md) || {
    echo "cannot check for child directives: PROJECT_PLAN.md declares no \`- Plan-slug:\` annotation."
    echo "Add one (see /borg-plan's Output section) and re-run. Do NOT proceed: this is 'I could not"
    echo "tell', not 'there is nothing to find'."
    exit 1
}
_borg_child_directives docs/plans/directives "$slug"
```

`_borg_child_directives` prints one path per still-parented directive and exits 0 with zero or more
lines; it exits **2** on an empty slug, which is "I could not check" and must never be read as
"nothing to find". Only `docs/plans/directives/` is scanned — `assimilated/` and `severed/` are
resolved by definition.

**If it printed ANY paths, STOP.** Report them exactly like this and go no further:

```
✗ Blocked: un-resolved child directives (move to severed/ or ship them first):
  - docs/plans/directives/<filename>.md
  - docs/plans/directives/<filename>.md
```

Do NOT proceed to criteria evaluation or shipping. The developer must either ship the child
directive or `git mv` it to `docs/plans/severed/` with a one-line "why severed" comment before
assimilation can continue. **If it printed nothing**, proceed to Step 1 without comment — do not
mention the check.

**THE BLOCK ABOVE WAS DELETED ONCE AND MUST NOT BE AGAIN.** The first draft of this rewrite replaced
the whole step and dropped the `✗ Blocked` format and the "Do NOT proceed" sentence with it, leaving
a step that computed the right answer and then did nothing with it — on this repository, listing
nine blocking directives and shipping anyway. Fixing the measurement while deleting the action is
the same defect one layer over: the old version passed because it measured nothing, that one would
have passed because it acted on nothing.

**THE OLD INSTRUCTION HERE WAS TO COMPUTE THE SLUG FROM THE OBJECTIVE PROSE, AND NO COMPUTATION
CAN.** The archived filename is a hand-written condensation. Measured 2026-09-15 on this repository:
the computed form ran 268 characters against a real slug of
`2026-08-24-one-front-door-link-derived-fact-surface`, and the plan *title* does not yield it either
— the real slug drops `borg` and `as-the`. So this gate searched for a string no directive carried,
found nothing, and was specified to proceed to Step 1 without comment — while **nine** directives
named the plan. It did not fail; it certified. The slug is now declared once by `/borg-plan` and read
by everyone, and a missing declaration is a refusal rather than a silent pass.

## Step 1: Load the Plan

Read `PROJECT_PLAN.md` from the project root.

- If it doesn't exist: skip criteria evaluation. Still report test/lint results and present the
  diff summary so the developer can decide whether to ship the changes as-is.
- If it exists: proceed with criteria evaluation.

## Step 2: Evaluate Each Criterion

For each acceptance criterion — run the verification yourself, don't ask the developer:
1. Does the thing exist? Use Glob/Grep/Read to verify.
2. Run the verification command from the plan.
3. Check edge cases mentioned in the plan.

Present results with evidence (the command you ran or file you checked):
```
Shipping checklist for [project]:
  ✓ [Criterion] — Evidence: [specific evidence]
  ✗ [Criterion] — Missing: [what] — To fix: [action]
  ⊘ [Criterion] — Blocked: [why] — Workaround: [if any]
```

## Step 3: Check the Ship Definition

Check each part of the plan's ship definition: committed? PR open/merged? Tests passing? Docs
reflect current state?

## Step 4: Verdict and Execution

**Criteria unmet:** "Not ready. [N] of [M] criteria met. Remaining: [list with effort estimates].
Focus on these. Do not add new scope." Stop here.

**All met but still working:** "This meets all acceptance criteria. Ship it. You're still working,
which means: (a) real problem not in criteria → name it, (b) polishing → stop, (c) new idea →
note for next session. Which is it?" Wait for answer before proceeding.

**All criteria met — run The Collective Review before shipping:**

### Step 4a: The Collective Review

Before making the ship/no-ship call, run The Collective adversarial review. Follow the process
defined in the `borg-collective-review` skill:

1. Feed the personas: the completed checklist, git diff, test results, and any open concerns
2. Present The Collective Review (core cast + any summoned code owners + rotating specialist
   evaluating the deliverable)
3. The Adult's verdict feeds into the next step — if The Adult says "not ready", that's a blocker

Include The Collective Review output in your shipping checklist presentation so the developer sees
all perspectives before confirming.

### Step 4b: Execute Shipping

#### Local Extensions: 02-output

Before executing shipping actions, check for local extension files. Read each file below that
exists and treat its contents as additional instructions for shaping the ship (e.g. content to
include in the PR body, tickets to reference). Read in order; later files extend or override
earlier ones.

1. `~/.config/borg/extensions/skill-extensions/borg-assimilate/02-output.md`
2. `<project root>/.borg/skill-extensions/borg-assimilate/02-output.md`

If neither exists, skip silently. Fold any extension instructions into the shipping action list
below before presenting it for confirmation.

#### Shipping Actions

1. Present the shipping actions as a numbered list:
   - Merge PR (show exact `gh pr merge` command)
   - Any plan-specific ship definition steps
   - Run 03-followup extensions (see below) — only after the merge has been confirmed
   - Archive PROJECT_PLAN.md → `docs/plans/assimilated/<date>-<slug>.md` with checkboxes marked
     + ship date
   - Remove PROJECT_PLAN.md from project root
2. **Ask for confirmation**: "Ready to ship. These are the actions I'll take: [list]. Confirm?"
3. Only execute after explicit confirmation. Execute each step, reporting results.
4. After shipping, verify: PR merged, plan archived, working tree clean.

#### Local Extensions: 03-followup

After the merge has succeeded but before plan archival, check for local extension files. Read
each file below that exists and treat its contents as additional instructions for follow-up
actions (e.g. closing a ticket, posting to a channel). Read in order; later files extend or
override earlier ones.

1. `~/.config/borg/extensions/skill-extensions/borg-assimilate/03-followup.md`
2. `<project root>/.borg/skill-extensions/borg-assimilate/03-followup.md`

If neither exists, skip silently. If a follow-up action fails (e.g. JIRA API down), report the
failure but do not roll back the merge — proceed with archival and surface the failure to the
developer to resolve manually.

### Plan Archival Format

When archiving PROJECT_PLAN.md:
- Copy to `docs/plans/assimilated/<slug>.md`, where `<slug>` is the plan's **declared**
  `- Plan-slug:` value — the same `_borg_plan_declared_slug PROJECT_PLAN.md` read Step 0.75 made.
  Do NOT compute it from the objective: Step 0.75 gated on the declared slug, so archiving under a
  computed one renames the plan out from under the nine directives that point at it, and the
  `*Parent plan:*` lineage silently dangles.
- Add `*Shipped: <today's date> — PR #<number> merged to main*` below the established date
- Mark all acceptance criteria checkboxes as `[x]`
- Append an "Additional Work Shipped" section if significant work happened beyond the criteria
- Delete PROJECT_PLAN.md from project root

### Step 4c: Chained Auto-Promotion

After PROJECT_PLAN.md has been archived (the previous step), check whether the next directive
should promote itself automatically — reusing Step 0.75's own scan idiom, run after archival
instead of before it.

1. Scan `docs/plans/directives/*.md` for top-level candidates: files with **no** line matching
   `^\*Parent plan:` (children of an in-flight plan are not top-level). Ignore
   `docs/plans/assimilated/` and `docs/plans/severed/`.
2. Check whether the plan that just shipped carries a `^\*Next: <slug>\*` line pointing at
   another directive.
3. Decide the outcome:
   - **Zero candidates**: silent no-op. Say nothing further about Step 4c.
   - **Exactly one candidate, or a `^\*Next: <slug>\*` pointer whose target file exists**: run
     `borg start <slug>` immediately and report `✓ Auto-promoted <slug>`.
   - **Two or more candidates and no resolved `^\*Next:*` signal**: ask one bounded question —
     "N candidates, none chained: which one? [list]" — and stop. Do not guess.
   - **A `^\*Next: <slug>\*` pointer whose target file does NOT exist**: treat it as absent and
     fall through to the candidate-count branch above (do not crash, do not report an error for
     the dangling pointer itself).
4. This never fires on a directive's *first* promotion — only after an archival has just
   happened, per this step's position in the flow.

## Rules

- Do NOT add criteria not in the plan. The plan is the contract.
- Do NOT say "you should also..." unless something is genuinely broken.
- "That's not in the acceptance criteria. Want to add it? That's a scope change."
- Show the exact commands. Don't make them look anything up.
- NEVER merge or archive without explicit confirmation from the developer.
