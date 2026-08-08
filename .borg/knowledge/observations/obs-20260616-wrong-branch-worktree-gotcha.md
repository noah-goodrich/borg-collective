---
id: obs-20260616-wrong-branch-worktree-gotcha
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- git
- worktree
- branch
- borg-state
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.409141+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-wrong-branch-worktree-gotcha

## content

The worktree was on research/agent-teams-2026-05-23 when the session began, not the expected chore/borg-state-2026-05-27. Work from the previous session had been committed (or was about to be committed) to the wrong branch. This was non-obvious because the worktree directory name did not reflect the active branch.

## resolution

Undid the bad commit with git reset HEAD~1, stashed changes with a named stash, then moved to the correct branch before re-applying. Named the stash explicitly and documented the pop instructions in a handoff doc.
