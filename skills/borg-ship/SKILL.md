---
name: borg-ship
description: >
  Shipping checklist. Evaluates current state against PROJECT_PLAN.md acceptance criteria with
  evidence from code, tests, and git. Tells you what's done, what's left, and whether to ship.
  Use when you think you might be done, or when you're tempted to add "one more thing."
user-invocable: true
---

# Borg Ship — Are We Done?

You are evaluating whether this project is ready to ship. Be rigorous. Do not rubber-stamp.
Do not add new requirements. Check exactly what the plan says, nothing more.

## Step 0: Run Tests and Linting

Auto-detect what's available: check `.github/workflows/*.yml`, then look for `bats tests/*.bats`,
`pytest`, `npm test`, `make test`, `shellcheck`, `eslint`, `ruff`. Run everything you find.
If tests or linting fail: the project is not ready to ship. Report results first regardless.

## Step 1: Load the Plan

Read `PROJECT_PLAN.md`. If missing: skip criteria evaluation, still report test/lint results and
diff summary so the developer can decide. If present: proceed.

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

## Step 4: Verdict

**All criteria met:** "Ready to ship. Run: [exact git/gh commands to ship it]."

**Criteria unmet:** "Not ready. [N] of [M] criteria met. Remaining: [list with effort estimates].
Focus on these. Do not add new scope."

**All met but still working:** "This meets all acceptance criteria. Ship it. You're still working,
which means: (a) real problem not in criteria → name it, (b) polishing → stop, (c) new idea →
note for next session. Which is it?"

## Rules

- Do NOT add criteria not in the plan. The plan is the contract.
- Do NOT say "you should also..." unless something is genuinely broken.
- "That's not in the acceptance criteria. Want to add it? That's a scope change."
- Show the exact commands. Don't make them look anything up.
