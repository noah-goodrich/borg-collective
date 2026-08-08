---
id: obs-20260611-pr21-mixed-concern-commit-history
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- git
- pr-hygiene
- cherry-pick
- commit-history
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.479143+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-pr21-mixed-concern-commit-history

## content

PR #21 was opened for orchestrator-mode work but accumulated borg-plan-promote commits during the same working period. When PR #29 later merged the borg-plan-promote commits first, PR #21's branch contained duplicate commits relative to main, making a standard merge or rebase produce conflicts on already-resolved content.

## resolution

Cherry-picked only the 5 orchestrator-mode commits onto a clean branch, force-pushed, retitled the PR, and merged cleanly. Future prevention: keep PRs to a single logical concern; if work is added to a branch mid-flight, split it before the other concern merges.
