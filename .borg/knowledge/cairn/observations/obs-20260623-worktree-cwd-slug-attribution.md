---
id: obs-20260623-worktree-cwd-slug-attribution
session_date: '2026-06-23'
project: cairn
tool: claude-code
tags:
- token-spend
- project-attribution
- git-worktree
- claude-code
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260623-0355-cairn
superseded_by: null
created_at: '2026-06-23 03:56:23.662838+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260623-worktree-cwd-slug-attribution

## content

Claude Code git-worktree sessions set CWD to `.claude/worktrees/<branch-slug>` inside the repo (e.g., `/Users/noah/dev/troth/.claude/worktrees/fix-foo`). The collector extracted the branch slug as the project name instead of the repo name (`troth`). 3 sessions were filed under random branch slugs.

## resolution

Add a case arm `*/.claude/worktrees/*) _wt="${CWD%/.claude/worktrees/*}"; PROJECT="${_wt##*/}" ;;` to strip the worktree suffix and use the parent directory name as the project. Relabel the 3 historical records after shipping.
