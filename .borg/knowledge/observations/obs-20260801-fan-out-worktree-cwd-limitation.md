---
id: obs-20260801-fan-out-worktree-cwd-limitation
session_date: '2026-08-01'
project: borg-collective
tool: claude-code
tags:
- fan-out
- worktree
- background-agents
- nanoprobe
- git
- isolation
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-08-01 02:47:55.711552+00:00'
updated_at: '2026-08-01 02:47:55.711553+00:00'
---

# obs-20260801-fan-out-worktree-cwd-limitation

## content

The custom nanoprobe worktree implementation exists specifically because native background-agents + isolation:worktree fails when CWD is not a git repo. This is the single known case where custom code was added to work around a tool limitation rather than leverage native capability.

## resolution

Identified as the highest-leverage spike for next session: test whether native background-agents + isolation:worktree now handles the non-git-repo CWD case. If yes, the custom nanoprobe worktree code can be retired. Do not retire speculatively — validate first.
