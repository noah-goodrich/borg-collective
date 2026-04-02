---
name: borg-review
description: >
  Mid-session diagnostic. Checks progress against the plan, detects scope creep and bad loops,
  and gives you ONE recommendation for what to do next. Use when stuck, scattered, or unsure
  if you're still building the right thing.
user-invocable: true
---

# Borg Review — Mid-Session Diagnostic

Do the analysis yourself — read the plan, check the code, run git commands, and TELL the developer
what you found. Don't ask them to self-assess. They called this because they've lost the thread.

## Step 1: Load Context (silently)

1. Read `PROJECT_PLAN.md` if it exists
2. Run `git diff --stat` and `git log --oneline -5`
3. Check uncommitted changes
4. Review what files were touched in this conversation

If there's no PROJECT_PLAN.md: lead with that and ask if they want to run `/borg-plan` first.

## Step 2: Present the Diagnostic

```
Session diagnostic:
  Plan: [exists / missing]
  Progress: [N] of [M] criteria addressed

  ✓ [Criterion met — with evidence]
  ◐ [Criterion partially done — what remains]
  ✗ [Criterion not started]

  Assessment: [on track / drifting / stuck]
```

## Step 3: Flag Problems

Name any you find. Be direct.

**Scope creep:** Work that doesn't map to any criterion → "This is scope creep. Recommend: stop
and refocus / note for later / add to plan with timeline adjustment."

**Loop detection:**
- Same error 3+ times → "Current approach isn't working. Try [option A] or [option B]."
- Undo-redo → "We've changed and reverted [thing]. What specifically was wrong with version 1?"
- Yak-shaving (3+ levels deep) → "We're [N] levels from the original task. Shortcut: [simpler path]."
- Perfectionism → "This already meets the criteria. Ship it."

**Verification gaps:** "We completed [criterion] but haven't verified it. Run: [command]."

**Energy drop** (shorter messages, repeated questions): "Momentum is dropping. Take a break or
timebox: 15 more minutes, then ship what we have."

## Step 4: One Recommendation

End with exactly ONE action. Not options. One thing.

- On track → "Next: [specific criterion]."
- Scope crept → "Park [tangent]. Back to [criterion]."
- Stuck in loop → "Stop. Try [specific alternative] instead."
- Blocked → "Switch projects. Come back when [blocker] resolves."
- Done → "All criteria met. Run `/borg-assimilate`."
- Fading → "Good stopping point. Run `/checkpoint-enhanced`, then break."

Can't pick one? Pick the one that ships something soonest.
