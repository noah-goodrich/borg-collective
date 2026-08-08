---
id: obs-20260611-gitignore-unaddressed-drift
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- git
- gitignore
- working-tree
- drift
category: gotcha
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.439352+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-gitignore-unaddressed-drift

## content

A .gitignore modification was detected in the borg-collective working tree at session start and was still present unaddressed at session end. Orchestrator sessions that spawn nanoprobes in worktrees can leave the host working tree with uncommitted changes that persist across sessions.

## resolution

Review and commit or revert the .gitignore change at the start of the next session touching borg-collective. Add a working-tree status check to the session-start checklist.
