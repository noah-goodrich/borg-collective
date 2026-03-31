---
name: borg-review
description: >
  Mid-session diagnostic. Checks progress against the plan, detects scope creep and bad loops,
  and gives you ONE recommendation for what to do next. Use when stuck, scattered, or unsure
  if you're still building the right thing.
user-invocable: true
---

# Borg Review — Mid-Session Diagnostic

You are performing a structured review of the current session. Do the analysis yourself — read the
plan, check the code, look at git status, and TELL the developer what you found. Don't ask them
to self-assess. They're calling this skill because they've lost the thread.

## Step 1: Load Context

Do all of these silently before saying anything:

1. Read `PROJECT_PLAN.md` if it exists
2. Run `git diff --stat` to see what's changed
3. Run `git log --oneline -5` to see recent commits
4. Check for uncommitted changes
5. Look at what files were discussed in the conversation so far

If there's no PROJECT_PLAN.md, lead with that: "There's no project plan. We're working without
acceptance criteria. I'd recommend running `/borg-plan` first — want to do that now, or keep
going without one?"

## Step 2: Present the Diagnostic

Present a single, clear status report. Don't ask questions yet — just tell them what you see:

```
Session diagnostic:

  Plan: [exists / missing]
  Time in session: [estimate based on conversation length]

  Progress:
    ✓ [Criterion met — with evidence]
    ◐ [Criterion partially done — what remains]
    ✗ [Criterion not started]

  [N] of [M] criteria addressed. [Assessment: on track / drifting / stuck]
```

## Step 3: Flag Problems

Check for these issues and report any you find. Be direct — name the problem and the fix.

**Scope creep:** Compare what's been worked on to the acceptance criteria.
- If work doesn't map to any criterion: "We've been working on [X], which isn't in the plan.
  This is scope creep. I'd recommend: [stop and refocus / note it for later / add it to plan
  with timeline adjustment]."

**Loop detection:** Look for patterns in the conversation:
- Same error appearing 3+ times: "We've hit [error] [N] times. The current approach isn't
  working. Two alternatives: [option A] or [option B]."
- Undo-redo pattern: "We changed [thing], reverted it, and are changing it again. Before
  another attempt: what specifically was wrong with the first version?"
- Yak shaving: "We started with [original task] → needed [thing A] → which needed [thing B]
  → which needed [thing C]. We're 3 levels deep. Shortcut: [simpler approach that avoids the
  dependency chain]."
- Perfectionism: "This already meets the acceptance criteria. The changes since then are
  polish, not progress. Ship it."

**Verification gaps:** Check whether verification is set up for completed criteria.
- "We've completed [criterion] but haven't verified it yet. Quick check: [specific command
  to run]."

**Energy/momentum:** Based on message patterns (shorter messages, repeated questions, long gaps):
- "Looks like momentum is dropping. Options: take a break, switch to a simpler task, or
  timebox this — 15 more minutes then ship what we have."

## Step 4: One Recommendation

End with exactly ONE action. Not a menu. Not options. One thing to do next.

Choose based on what you found:

- **On track:** "You're on track. Next up: [specific criterion to work on next]."
- **Scope crept:** "Park [tangent work] and get back to [specific criterion]. You can come
  back to it after shipping."
- **Stuck in a loop:** "Stop. Try [specific alternative approach] instead."
- **Blocked:** "You're blocked on [thing]. Switch to a different project and come back when
  [blocker is resolved]."
- **Done:** "All criteria are met. Run `/borg-ship` to verify and ship."
- **Fading energy:** "Good stopping point. Run `/checkpoint-enhanced` to save context, then
  take a break."

If you genuinely can't pick one, pick the one that ships something soonest.
