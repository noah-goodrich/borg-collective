---
id: obs-20260616-pr22-conflict-risk-after-bulk-merge
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- pr-management
- rebase
- conflict-prediction
- research-prs
category: pattern_discovered
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.440722+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-pr22-conflict-risk-after-bulk-merge

## content

PR #22 (docs/borg-next-level-research) likely accumulated merge conflicts with main because PR #29 updated many of the same docs files (CLAUDE.md, README, architecture docs). Long-lived research/documentation branches are especially vulnerable to this when a bulk-cleanup PR lands on main.

## resolution

Deferred to next session with an explicit note to rebase PR #22 onto main before attempting merge. Pattern: any time a 'cleanup' PR touches widespread docs, audit open PRs for overlap before merging the cleanup.
