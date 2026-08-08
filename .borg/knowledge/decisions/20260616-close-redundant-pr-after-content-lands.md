---
id: 20260616-close-redundant-pr-after-content-lands
date: '2026-06-16'
project: borg-collective
domain: git-workflow
tags:
- git
- pr-management
- rebase
- technical-debt
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.427718+00:00'
updated_at: '2026-06-16 10:27:02.427719+00:00'
---

# 20260616-close-redundant-pr-after-content-lands

## decision

When a PR's subset of commits lands via another PR, prefer rebasing the original PR to drop the now-duplicate commits rather than closing it, if the remaining commits are still valuable

## context

PR #21 contained both orchestrator-mode commits and borg-plan-promote commits. The borg-plan-promote content landed via PR #29, leaving PR #21 with conflicts and redundant commits

## reasoning

The orchestrator-mode commits in PR #21 (08fb429..4f899ba) are still unmerged and valid. A targeted rebase dropping only the 3 conflicting commits preserves that value without losing work. Alternatively, opening a focused PR on just those 5 commits is cleaner if the branch history is complex.
