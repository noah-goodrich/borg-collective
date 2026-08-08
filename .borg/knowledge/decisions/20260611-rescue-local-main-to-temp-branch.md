---
id: 20260611-rescue-local-main-to-temp-branch
date: '2026-06-11'
project: borg-collective
domain: git-workflow
tags:
- git
- branch-hygiene
- local-main-divergence
- recovery
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.476424+00:00'
updated_at: '2026-06-11 22:41:19.476425+00:00'
---

# 20260611-rescue-local-main-to-temp-branch

## decision

When local main had diverged from origin/main with 5 untracked commits, rescued the commits to a temp branch first, then hard-reset local main to origin/main, rather than force-pushing or merging.

## context

5 commits had accumulated directly on local main instead of feature branches, causing local main to diverge from origin/main.

## reasoning

Rescuing to a temp branch preserves the work without risk before destructive operations. Hard-resetting local main to origin/main then gives a clean starting point. This is the safe, reversible sequence — nothing is lost and the invariant (local main tracks origin/main) is restored.
