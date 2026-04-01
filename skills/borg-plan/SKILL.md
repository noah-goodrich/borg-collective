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
to validate, adjust, and confirm. Do not ask open-ended questions that require them to generate
answers from scratch. Instead: read the code, form an opinion, propose it, and let them react.

The developer should feel like they're reviewing your suggestions, not filling out a form.

## Model and Mode Setup

Before starting the planning conversation, remind the user:

"For best results with planning, ensure you're on Opus and in Plan Mode:
  1. Run `/model opus` (if not already on Opus)
  2. Press Shift+Tab to enter Plan Mode

After the plan is confirmed, switch back for implementation:
  1. Press Shift+Tab to exit Plan Mode
  2. Run `/model sonnet`"

## Before You Start

1. Read the project's README, CLAUDE.md, and any existing documentation
2. Look at recent git history (`git log --oneline -20`)
3. Check for open PRs, uncommitted changes, TODO comments
4. Look at the test suite (does it exist? what's the coverage?)
5. Check for a CI/CD configuration

Use what you learn to inform your proposals below.

## The Conversation

### 1. Propose the Objective

Based on what you read, propose what this project is trying to accomplish:

"I've looked at the project. Here's what I think we're building:

  **Objective:** [your best understanding in 1-2 sentences]

Does that sound right, or would you frame it differently?"

If they say it's right, move on. If they adjust, incorporate and confirm: "Got it — so the
objective is: [revised]. Correct?"

### 2. Propose Acceptance Criteria

Based on the objective and codebase, propose 3-6 specific, testable criteria:

"Here's what I'd suggest for acceptance criteria:

  1. [Criterion based on what the code needs]
  2. [Criterion based on what the code needs]
  3. [Criterion you think they might have missed — tests, docs, error handling]
  4. [Criterion about what should NOT break]

Anything to add, remove, or change?"

**Guidelines for good criteria:**
- Each one should be verifiable by running a command, checking a file, or viewing output
- Include at least one "nothing breaks" criterion (existing tests pass, no regressions)
- If the project has no tests, suggest: "Should we add test coverage as a criterion?"
- If there are docs that would need updating, include that
- Think about edge cases: what happens when the network is down? when the database is empty?
  when the config file is missing?

When they respond, handle it conversationally:
- "Yes" → move on
- They add something → "Added. The full list is now: [list]. Good?"
- They remove something → "Removed. Want to note it as a future item instead?"
- They're unsure → offer your opinion: "I'd include it because [reason], but it's your call."

### 3. Propose Verification for Each Criterion

For each criterion, suggest HOW to verify it. Don't ask them to think of verification — propose it:

"For each criterion, here's how I'd verify it:

  1. [Criterion] → Run: `[specific command]`
  2. [Criterion] → Check: [specific file or output]
  3. [Criterion] → Test: `[test command]`
  4. [Criterion] → Verify: [manual check — describe what to look for]

Do these checks make sense? Any you'd do differently?"

If the project has a test suite, default to running it. If it doesn't, suggest the simplest
verification that proves the criterion is met — a grep, a curl, a visual check.

### 4. Propose Scope Boundaries

Based on what you've seen, name things that are adjacent but should be excluded:

"To keep this focused, I'd suggest we explicitly leave out:

  - [Adjacent feature that's tempting but separate]
  - [Refactoring that could be done but isn't required]
  - [Nice-to-have that would expand the timeline]

If we finish early: ship what we have, don't expand scope.

Sound right?"

### 5. Propose Ship Definition

Suggest what "shipped" means based on the project's setup:

"For shipping, I'd suggest:

  [Choose the appropriate set based on what you see:]

  **If the project has CI/CD:**
  • PR opened against main
  • CI checks pass
  • PR merged

  **If the project is a CLI tool:**
  • Changes committed to main
  • Manual smoke test passes
  • Help text / docs updated

  **If the project is a library:**
  • Tests pass
  • Version bumped
  • Changelog updated
  • Published to registry

Does that capture 'shipped' for this project, or is there more to it?"

### 6. Propose Timeline

Based on the scope:

"Based on the [N] criteria and what I've seen of the codebase, I'd estimate this takes
[N] sessions of about [N] hours each. [Reasoning — e.g., 'the first 3 components took
about 30 minutes each, so the remaining 2 should be similar.']

Does that feel right? If there's a deadline, tell me and I'll flag if the scope doesn't fit."

### 7. Flag Risks You See

Don't ask "what could go wrong?" — tell them what you think could go wrong:

"A few things I'd watch out for:

  - [Risk based on code: e.g., 'This function has no error handling for network failures']
  - [Risk based on dependencies: e.g., 'This depends on postgres running']
  - [Risk based on scope: e.g., 'The test suite is thin here — changes might break things
    we don't catch']

Anything else you're worried about?"

## Output

After the conversation, produce a `PROJECT_PLAN.md` file in the project root:

```markdown
# Project Plan: [Project Name]
*Established: [date]*

## Objective
[1-2 sentences — the confirmed version]

## Acceptance Criteria
- [ ] Criterion 1
  - Verify: [command or check]
- [ ] Criterion 2
  - Verify: [command or check]
- [ ] Criterion 3
  - Verify: [command or check]

## Scope Boundaries
- NOT building: [thing 1]
- NOT building: [thing 2]
- If done early: Ship, don't expand.

## Ship Definition
[Specific steps — PR, tests, merge, etc.]

## Timeline
Target: [date or "this session"]
Estimated effort: [sessions/hours]

## Risks
- [Risk 1]
- [Risk 2]
```

## The Lock Rule

Once PROJECT_PLAN.md is written:
- Do NOT modify acceptance criteria without the developer explicitly saying "I'm changing scope."
- If they ask for something outside the criteria: "That's outside the current plan. Want to add
  it? Fair warning: expanding scope resets the shipping clock."
- If they say "while we're here, let's also..." — name it: "That's scope creep. I can note it
  for a future session. Want to stay focused on the current criteria?"
- If they push back on the lock: respect it, but make the trade-off visible: "Sure, adding
  [thing]. That changes the timeline from [X] to [Y]. Still want to include it?"
