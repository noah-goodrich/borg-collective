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

## Local Extensions: 01-context

Before loading context, check for local extension files. Read each file below that exists, in order; later files
extend or override earlier ones.

1. `~/.config/borg/extensions/skill-extensions/borg-review/01-context.md` (per machine)
2. `<project root>/.borg/skill-extensions/borg-review/01-context.md` (per project)

**Precedence has one exception, and it inverts the order:** a file declaring `- Prefer-tool:`
asserts something about THIS MACHINE, so when both layers declare it the MACHINE layer wins.
Everything else is project policy and the repository layer wins. Full rules: `docs/extensions.md`.

If neither exists, skip silently — do not mention extensions, do not warn, do not change behavior.


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

## Local Extensions: 02-output

Before settling on the single recommendation, check for local extension files. Read each file below that exists, in
order; later files extend or override earlier ones.

1. `~/.config/borg/extensions/skill-extensions/borg-review/02-output.md` (per machine)
2. `<project root>/.borg/skill-extensions/borg-review/02-output.md` (per project)

**Precedence has one exception, and it inverts the order:** a file declaring `- Prefer-tool:`
asserts something about THIS MACHINE, so when both layers declare it the MACHINE layer wins.
Everything else is project policy and the repository layer wins. Full rules: `docs/extensions.md`.

If neither exists, skip silently — do not mention extensions, do not warn, do not change behavior.

Fold any extension instructions into the recommendation. **There is deliberately no
`03-followup` for this skill.** Its entire contract is that it ends on exactly ONE action, and a
hook that runs after the recommendation invites a second — which is the failure mode the
one-recommendation rule exists to prevent. If a machine needs post-review behaviour, it belongs in
the skill the recommendation points at.

## Step 4: One Recommendation

End with exactly ONE action. Not options. One thing.

- On track → "Next: [specific criterion]."
- Scope crept → "Park [tangent]. Back to [criterion]."
- Stuck in loop → "Stop. Try [specific alternative] instead."
- Blocked → "Switch projects. Come back when [blocker] resolves."
- Done → "All criteria met. Run `/borg-assimilate`."
- Fading → "Good stopping point. Run `/borg-link-up`, then break."

Can't pick one? Pick the one that ships something soonest.

## Optional: The Collective Review

If the diagnostic reveals significant concerns (multiple criteria unmet, scope creep detected, or
stuck in a loop), run The Collective Review from `borg-collective-review` to get structured
multi-perspective analysis before making your recommendation. This adds depth when the simple
diagnostic isn't enough.
