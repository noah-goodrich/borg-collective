---
id: obs-20260721-pr-left-unmerged-live-pane-typing
session_date: '2026-07-21'
project: borg-collective
tool: claude-code
tags:
- merge-strategy
- safety
- tmux
- send-keys
- review-process
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-21 22:16:47.852027+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260721-pr-left-unmerged-live-pane-typing

## content

PR #88 was deliberately left unmerged despite CI green and CLEAN merge state, because it is the first capability in the project that types directly into live Claude panes. Human review and explicit merge decision is required for this class of capability even when automation gates pass.

## resolution

Establish a team norm: PRs whose primary side effect is writing to live interactive sessions require explicit human merge (not auto-merge), regardless of CI status. Document this gate in the PR description.
