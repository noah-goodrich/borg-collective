---
id: obs-20260616-pr-content-overlap-conflict
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- git
- pr-management
- rebase
- conflict
- long-lived-branches
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.430180+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-pr-content-overlap-conflict

## content

When a long-lived branch contains commits that later land via a different PR (e.g., hotfix or cleanup PR), the original branch will have conflicts that are difficult to resolve because the conflicting commits are your own work, already merged. A naive conflict resolution risks either losing the merged content or duplicating it.

## resolution

Use interactive rebase (git rebase -i main) to drop the specific commits whose content is already in main, rather than resolving conflicts. Identify the commits by hash before rebasing (git log --oneline) and use 'drop' for the duplicate commits. Force-push the rebased branch.
