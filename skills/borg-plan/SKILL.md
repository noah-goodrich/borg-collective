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
2. `<repository root>/.borg/skill-extensions/borg-plan/01-context.md`

**Precedence has one exception, and it inverts the order:** a file declaring `- Prefer-tool:`
asserts something about THIS MACHINE, so when both layers declare it the MACHINE layer wins.
Everything else is repository policy and the repository layer wins. Full rules: `docs/extensions.md`.

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

Read `references/follow-up-directives.md` (relative to this skill's base directory) only when the developer requests a new directive and a `PROJECT_PLAN.md` already exists in the repository root.

## Output

Read `references/output.md` (relative to this skill's base directory) once the conversation is done and before writing `PROJECT_PLAN.md`. It holds the 02-output extension notice, the Plan-slug rule, the PROJECT_PLAN.md template, the manifest scaffolding steps (`borg_core.manifest.cli`, unconditional right after the plan is written) and the 03-followup extension notice.

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
