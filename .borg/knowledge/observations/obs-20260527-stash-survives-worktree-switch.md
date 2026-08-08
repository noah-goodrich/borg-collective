---
id: obs-20260527-stash-survives-worktree-switch
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- git
- stash
- worktree
- multi-worktree
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.454241+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260527-stash-survives-worktree-switch

## content

In a git worktree setup, stashes are stored in the shared .git directory and are visible from all worktrees. A stash created on `research/agent-teams-2026-05-23` is accessible (and poppable) from `chore/borg-state-2026-05-27`. This is intentional behavior but surprises developers who expect stashes to be local to a worktree.

## resolution

Use named stashes (`git stash push -m <name>`) so the intended worktree context is unambiguous. Document the stash name and intended pop location in handoff docs.
