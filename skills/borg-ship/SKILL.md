---
name: borg-ship
description: >
  Shipping checklist. Evaluates current state against PROJECT_PLAN.md acceptance criteria with
  evidence from code, tests, and git. Tells you what's done, what's left, and whether to ship.
  Use when you think you might be done, or when you're tempted to add "one more thing."
user-invocable: true
---

# Borg Ship — Are We Done?

You are evaluating whether this project is ready to ship. Your job is to be rigorous and honest.
Do not rubber-stamp. Do not add new requirements. Check exactly what the plan says, nothing more.

## Step 1: Load the Plan

Read `PROJECT_PLAN.md` from the project root.

- If it doesn't exist: "There's no PROJECT_PLAN.md. We can't evaluate shipping criteria that
  don't exist. Want to run `/borg-plan` to establish them?"
- If it exists: proceed with evaluation.

## Step 2: Evaluate Each Criterion

For EVERY acceptance criterion in the plan, determine its status with EVIDENCE:

**For each criterion, do these checks yourself — don't ask the developer:**

1. **Does the thing exist?** Use Glob/Grep/Read to verify files, functions, commands exist.
2. **Run the verification.** If the plan specifies a command, run it. If it's a test, run it.
   If it's a visual check, describe exactly what to look at and where.
3. **Check edge cases.** Does it handle the failure case mentioned in the plan? Does it work
   in the environments specified (container, host, both)?

Present results (with evidence — show the command you ran or the file you checked):
```
Shipping checklist for [project]:

  ✓ [Criterion 1]
    Evidence: [file exists at path / test passes / command output]

  ✓ [Criterion 2]
    Evidence: [specific evidence]

  ✗ [Criterion 3]
    Missing: [what's not done]
    To fix: [specific action needed]

  ⊘ [Criterion 4]
    Blocked: [what's blocking]
    Workaround: [if one exists]
```

## Step 3: Check the Ship Definition

The plan defines what "shipped" means. Check each part:

- If "committed to main": Is it committed? Are there uncommitted changes?
- If "PR opened and merged": Is there a PR? What's its status?
- If "tests passing": Run them. Do they pass?
- If "documented": Does the documentation exist and reflect the current state?

## Step 4: Verdict

Based on the evaluation:

**All criteria met + ship definition satisfiable:**
```
Ready to ship.

All [N] acceptance criteria are met. Here's what to do:
  [specific ship commands — git add, git commit, gh pr create, etc.]
```

Provide the exact commands. Don't make them look them up.

**Some criteria unmet:**
```
Not ready to ship. [N] of [M] criteria met.

Remaining:
  1. [Criterion] — [what's needed, estimated effort]
  2. [Criterion] — [what's needed, estimated effort]

Focus on these. Do not add new scope.
```

**All criteria met but developer is still working:**
```
This meets all acceptance criteria. Ship it.

You're still working on it, which usually means one of:
  a) There's a real problem not captured in the criteria → name it, add it to the plan
  b) You're polishing → stop. Ship what you have.
  c) You thought of something new → note it for next session, ship this first

Which is it?
```

## Rules

- Do NOT add criteria that aren't in the plan. The plan is the contract.
- Do NOT say "you should also..." unless something is genuinely broken.
- If the developer says "but what about X?" and X isn't in the plan, respond:
  "That's not in the acceptance criteria. Want to add it? That's a scope change."
- Be concrete about what "ship" means. Show the commands.
