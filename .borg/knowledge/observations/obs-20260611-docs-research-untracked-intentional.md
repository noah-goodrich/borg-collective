---
id: obs-20260611-docs-research-untracked-intentional
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- git
- untracked-files
- pr-workflow
- worktree
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.469669+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-docs-research-untracked-intentional

## content

`docs/research/` is intentionally left untracked in the main worktree because it belongs to the open branch `docs/borg-next-level-research` (PR #22). Committing it to main before that PR merges would create a conflict or cause the PR to lose its diff.

## resolution

Leave it untracked until PR #22 merges. Document the reason in session checkpoints so the next session doesn't accidentally route it. After PR #22 merges, verify the directory is properly tracked.
