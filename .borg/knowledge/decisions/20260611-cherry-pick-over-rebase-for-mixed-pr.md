---
id: 20260611-cherry-pick-over-rebase-for-mixed-pr
date: '2026-06-11'
project: borg-collective
domain: git-workflow
tags:
- git
- cherry-pick
- pr-cleanup
- branch-hygiene
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.476009+00:00'
updated_at: '2026-06-11 22:41:19.476009+00:00'
---

# 20260611-cherry-pick-over-rebase-for-mixed-pr

## decision

Cherry-picked only the 5 orchestrator-mode commits from PR #21 rather than rebasing the whole branch, dropping the 3 borg-plan-promote commits that had already landed via PR #29.

## context

PR #21 contained two logical groups of commits: orchestrator-mode work (its original purpose) and borg-plan-promote work (added later). PR #29 had already merged the borg-plan-promote commits, making them duplicates that would conflict on rebase.

## reasoning

Cherry-picking the specific commits to a clean branch produced a PR with exactly the intended diff — no noise, no conflicts, no duplicate history. A rebase would have required resolving conflicts caused by commits that were already in main and would have left redundant commits in the history.
