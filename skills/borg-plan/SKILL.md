---
name: borg-plan
description: >
  Project planning that does the thinking so you can focus on validating and deciding. Reads the
  codebase, proposes objectives and acceptance criteria, and asks you to validate. Locks criteria
  once confirmed. Use at the start of a project or when objectives are unclear.
user-invocable: true
---

# Borg Plan — Project Objective and Shipping Criteria

You are helping a developer establish a project plan. YOUR job is to do the thinking. THEIR job is
to validate, adjust, and confirm. Do not ask open-ended questions. Read the code, form an opinion,
propose it, and let them react. The developer should feel like they're reviewing suggestions, not
filling out a form.

## Model and Mode Setup

Before starting the planning conversation, remind the user:

"For best results with planning, ensure you're on Opus and in Plan Mode:
  1. Run `/model opus` (if not already on Opus)
  2. Press Shift+Tab to enter Plan Mode

After the plan is confirmed, switch back for implementation:
  1. Press Shift+Tab to exit Plan Mode
  2. Run `/model sonnet`"

## Before You Start

Read silently: README, CLAUDE.md, recent `git log --oneline -20`, open PRs, uncommitted changes,
TODO comments, test suite, CI/CD config. Use what you learn to inform every proposal below.

## Local Extensions: 01-context

Before the Collective Review, check for local extension files. Read each file below that exists
and treat its contents as additional instructions for this phase. Read in order; later files
extend or override earlier ones.

1. `~/.config/borg/extensions/skill-extensions/borg-plan/01-context.md`
2. `<project root>/.borg/skill-extensions/borg-plan/01-context.md`

**Precedence has one exception, and it inverts the order:** a file declaring `- Prefer-tool:`
asserts something about THIS MACHINE, so when both layers declare it the MACHINE layer wins.
Everything else is project policy and the repository layer wins. Full rules: `docs/extensions.md`.

If neither exists, skip silently — do not mention extensions, do not warn, do not change behavior.

## Run The Collective Review

After reading the codebase and before proposing objectives, run The Collective adversarial review.
Follow the process defined in the `borg-collective-review` skill:

1. Read the codebase context you just gathered
2. Present The Collective Review (core cast + any summoned code owners + rotating specialist
   analyzing the codebase, the user's request, and the work ahead)
3. Use The Adult's synthesis to inform your objective and criteria proposals

Do not skip this step. The review ensures the plan accounts for scope, quality, performance,
readability, and user experience from the start. Present the review to the developer before
proposing objectives so they can react to the perspectives.

## The Conversation

### 1. Propose the Objective

"I've looked at the project. Here's what I think we're building:

  **Objective:** [1-2 sentences]

Does that sound right?"

Confirm any adjustment before moving on.

### 2. Propose Acceptance Criteria

Propose 3-6 specific, verifiable criteria. Each must be checkable by running a command or reading
a file. Include at least one regression criterion. If no test suite exists, suggest adding coverage.

"Here's what I'd suggest:
  1. [criterion]
  2. [criterion]
  3. [nothing-breaks criterion]

Anything to add, remove, or change?"

Handle responses: "Yes" → move on. Addition → confirm the full updated list. Removal → offer to
note as future work. Unsure → give your opinion.

### 3. Propose Verification

For each criterion, propose HOW to verify it (command, file check, or visual). Don't ask —
propose. "Verify: `[command]`" or "Check: [what to look for in which file]."

### 4. Propose Scope Boundaries

Name 2-3 adjacent things to explicitly exclude. "To keep this focused, I'd leave out: [list].
If we finish early: ship what we have, don't expand scope."

### 5. Propose Ship Definition

Pick the appropriate pattern:
- **CI/CD project:** PR opened → CI passes → merged
- **CLI tool:** committed to main + manual smoke test passes + help text updated
- **Library:** tests pass + version bumped + published

### 6. Propose Timeline

"Based on [N] criteria and what I've seen: [N] sessions of ~[N] hours each. [One sentence
reasoning.] If there's a deadline, tell me and I'll flag if scope doesn't fit."

### 7. Flag Risks

Name 2-3 specific risks you see in the code. Don't ask "what could go wrong?" — tell them.

## Follow-Up Directives During an Active Plan

When the developer requests a new directive *while a `PROJECT_PLAN.md` already exists* in the
project root (i.e. we are mid-plan, not starting from scratch), write the directive file to
`docs/plans/directives/<date>-<slug>.md` with a `*Parent plan: <plan-slug>*` italic metadata line
immediately below the H1 heading.

`<plan-slug>` is the filename of `PROJECT_PLAN.md`'s eventual archived copy — the basename
*without* the `.md` extension and without a leading path. **Read it from the plan's `- Plan-slug:`
annotation; never compute it.** The helper Step 0.75 uses is the one to use here:

```
source lib/promote-next.sh && _borg_plan_declared_slug PROJECT_PLAN.md
```

If the annotation is missing, the plan predates it — add it and confirm the value with the developer
before filing the directive. A computed slug writes a `*Parent plan:*` line no gate will ever match,
which is exactly how nine directives came to be invisible to the check meant to find them. Example:

```
# Directive: <title>
*Parent plan: 2026-04-14-reveal-mvp-supabase-flyio*
*Filed: <date>*
```

The slug must survive the plan moving from `directives/` → `assimilated/`. Store only the slug
(filename without extension), not a filesystem path. If there is no active `PROJECT_PLAN.md`,
omit the `*Parent plan:*` line — independent directives carry no lineage.

## Output

### Local Extensions: 02-output

Before writing `PROJECT_PLAN.md`, check for local extension files. Read each file below that exists
and treat its contents as additional instructions for shaping the plan being written. Read in
order; later files extend or override earlier ones.

1. `~/.config/borg/extensions/skill-extensions/borg-plan/02-output.md`
2. `<project root>/.borg/skill-extensions/borg-plan/02-output.md`

**Precedence has one exception, and it inverts the order:** a file declaring `- Prefer-tool:`
asserts something about THIS MACHINE, so when both layers declare it the MACHINE layer wins.
Everything else is project policy and the repository layer wins. Full rules: `docs/extensions.md`.

If neither exists, skip silently.

After the conversation, write `PROJECT_PLAN.md` in the project root.

**`- Plan-slug:` is the plan's own name for its archived copy, and it is chosen HERE — once, by a
person, at plan time.** It is `<established-date>-<short-slug>`, where the short slug is a 3-6 word
human condensation of the objective, not a slugification of it. Confirm it with the developer
alongside the acceptance criteria. Every later consumer READS this line: `/borg-plan`'s own
follow-up-directive section below, `/borg-assimilate` Step 0.75's child-directive gate, Step 5's
archival path, and `borg_core.manifest.cli resolve`, which uses it to pick a manifest when a
repository declares more than one. Omit it and Step 0.75 stops the assimilation rather than
guessing.

Why it is stored and not computed: an archived filename is a condensation, and there is no function
from prose to condensation. Measured 2026-09-15 on this repository, the instruction to derive
`<established-date>-<slugified-objective>` produced
`make-borg-link-the-single-front-door-that-answers-from-a-clean-read-of-derived-fact-...` against a
real slug of `2026-08-24-one-front-door-link-derived-fact-surface`. Three separate places carried
that derivation, so the gate that searched and the step that wrote agreed with each other and
disagreed with every file on disk.

```markdown
# Project Plan: [Project Name]
*Established: [date]*

- Plan-slug: `[date]-[short-slug]`

## Objective
[confirmed 1-2 sentences]

## Acceptance Criteria
- [ ] Criterion 1
  - Verify: [command or check]
- [ ] Criterion 2
  - Verify: [command or check]

## Scope Boundaries
- NOT building: [thing 1]
- NOT building: [thing 2]
- If done early: Ship, don't expand.

## Ship Definition
[specific steps]

## Timeline
Target: [date or "this session"]
Estimated effort: [sessions/hours]

## Risks
- [Risk 1]
- [Risk 2]
```

### Scaffold the project manifest

Immediately after writing `PROJECT_PLAN.md`, scaffold the manifest. Unconditional — not an offer,
not a question, and not something the developer opts into:

```
command -v borg | xargs readlink -f | xargs dirname
PYTHONPATH=<that dir> python3 -m borg_core.manifest.cli scaffold \
    --repository <project root> --name <the Plan-slug> --desc "<the confirmed Objective, one line>"
```

- **`--name` is the `- Plan-slug:` you just declared**, byte for byte. Same string, same session.
- **Never pass `--apex`.** A plan has no PR yet. Rows arrive at link-up, which is the ratified split.
- **It never clobbers.** `scaffold` is idempotent: an existing manifest is reported at exit 0 and
  left untouched. Re-running `/borg-plan` on a repository that already has one is the ordinary case.
- **A non-zero exit is reported, never worked around.** Say what failed and carry on writing the
  plan. Do not hand-write a manifest, and do not retry with a different `--name`.

## Local Extensions: 03-followup

After `PROJECT_PLAN.md` is written, check for local extension files. Read each file below that
exists and treat its contents as additional instructions for follow-up actions (e.g. linking the
plan to an external ticket). Read in order; later files extend or override earlier ones.

1. `~/.config/borg/extensions/skill-extensions/borg-plan/03-followup.md`
2. `<project root>/.borg/skill-extensions/borg-plan/03-followup.md`

**Precedence has one exception, and it inverts the order:** a file declaring `- Prefer-tool:`
asserts something about THIS MACHINE, so when both layers declare it the MACHINE layer wins.
Everything else is project policy and the repository layer wins. Full rules: `docs/extensions.md`.

If neither exists, skip silently.

## Orchestrator turn discipline

When implementing a plan, delegate output-heavy reads and multi-file edits to nanoprobes that
return distilled summaries — conclusions, file:line refs, and diff stats only, never raw dumps.
Batch related steps into a single orchestrator turn; each extra turn re-reads the full accumulated
context (~96% of session cost is the main loop). Reserve extended thinking for genuinely hard
design decisions; mechanical steps like renaming, formatting, or applying a known pattern do not
warrant deep deliberation. Keep the main context lean: conclusions go here, raw output stays in
the repo.

## The Lock Rule

Once PROJECT_PLAN.md is written, do NOT modify acceptance criteria without explicit "I'm changing
scope." Scope-creep attempts: "That's outside the current plan. Add it (resets timeline) or note
it for later?" Push-back on the lock: respect it, but name the trade-off.
