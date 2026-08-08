---
id: 20260611-rescue-commits-to-feature-branch
date: '2026-06-11'
project: borg-collective
domain: git-workflow
tags:
- git
- branch-management
- commit-recovery
- local-main
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.467169+00:00'
updated_at: '2026-06-11 22:41:19.467170+00:00'
---

# 20260611-rescue-commits-to-feature-branch

## decision

Rescued commits made directly to local main by cherry-picking/branching to a feature branch, then hard-reset local main to origin/main

## context

5 commits had been made directly to local main without being pushed, causing local main to diverge from origin/main

## reasoning

Preserves the work without polluting main's history; the rescued branch can then go through normal PR review. Hard-resetting local main to origin/main restores the invariant that local main tracks remote.
