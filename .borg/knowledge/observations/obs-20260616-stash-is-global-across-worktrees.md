---
id: obs-20260616-stash-is-global-across-worktrees
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- git
- worktree
- stash
- multi-worktree
category: tool_behavior
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.410191+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-stash-is-global-across-worktrees

## content

Git stashes are stored globally per repository, not per worktree. A stash created while in the research/agent-teams worktree is accessible (and accidentally poppable) from the borg-state worktree or any other. The stash index (stash@{0}) also shifts when new stashes are pushed.

## resolution

Always name stashes descriptively when they are intended to survive across sessions or branch switches. Document the stash name — not the index — in handoff docs. Verify the correct stash before popping with git stash list.
