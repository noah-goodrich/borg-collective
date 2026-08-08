---
id: 20260616-cherry-pick-over-rebase-for-pr21
date: '2026-06-16'
project: borg-collective
domain: infrastructure
tags:
- git
- cherry-pick
- branch-management
- conflict-resolution
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.437926+00:00'
updated_at: '2026-06-16 10:27:02.437927+00:00'
---

# 20260616-cherry-pick-over-rebase-for-pr21

## decision

Cherry-picked only the 5 orchestrator-mode commits from PR #21 rather than rebasing the entire branch onto main

## context

PR #21 contained 8 commits total: 5 orchestrator-mode commits (the actual intent of the PR) and 3 borg-plan-promote commits that had already landed on main via PR #29. A naive rebase would have produced conflicts or duplicate commits.

## reasoning

Cherry-picking the specific commits that hadn't yet landed gave a clean branch with exactly the intended changes, avoiding the mess of conflict-resolving commits that were already present on main.
