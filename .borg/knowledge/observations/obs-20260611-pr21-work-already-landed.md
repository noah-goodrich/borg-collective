---
id: obs-20260611-pr21-work-already-landed
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- borg-collective
- branch-hygiene
- pr-rebase
- duplicate-commits
category: pattern_discovered
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.486830+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-pr21-work-already-landed

## content

PR #21 (orchestrator-mode session separation) had 5 genuine new commits plus 3 borg-plan-promote commits that had already landed via a different PR. The branch appeared large and conflicted but the real delta was small once stale commits were dropped. Similarly, PRs #22 and #23 each had 8–10 stale commits that needed dropping before clean merge.

## resolution

Before rebasing a long-lived branch, enumerate its commits against main (git log main..branch --oneline) and cross-reference against recently merged PRs to identify already-landed work. Drop those commits in an interactive rebase before attempting conflict resolution — it dramatically reduces the conflict surface.
