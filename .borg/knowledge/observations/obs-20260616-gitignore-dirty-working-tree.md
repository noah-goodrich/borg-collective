---
id: obs-20260616-gitignore-dirty-working-tree
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- git
- gitignore
- working-tree
- borg-collective
category: gotcha
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.390142+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-gitignore-dirty-working-tree

## content

A .gitignore modification in /Users/noah/dev/borg-collective working tree was present at session start and remained unaddressed at checkpoint. Orchestrator sessions that spawn nanoprobes in worktrees may leave the main working tree dirty without anyone noticing.

## resolution

Not resolved in this session. Next session should inspect `git status` in borg-collective main worktree, determine if the .gitignore change is intentional, and either commit or revert it before merging PR #21.
