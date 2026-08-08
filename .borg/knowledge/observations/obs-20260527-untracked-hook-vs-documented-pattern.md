---
id: obs-20260527-untracked-hook-vs-documented-pattern
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- hooks
- CLAUDE.md
- git
- untracked-files
- documentation-drift
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.400016+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260527-untracked-hook-vs-documented-pattern

## content

hooks/borg-plan-promote.sh and tests/plan_promote.bats exist in the worktree and are referenced in CLAUDE.md 'Key Patterns' as if implemented, but the files themselves are untracked — they won't survive a fresh clone or a different checkout. CLAUDE.md documents a pattern whose implementation isn't committed.

## resolution

Either commit the hook files on their own PR, or add a note to CLAUDE.md that the implementation is pending commit. As-is, a developer following CLAUDE.md will expect the hook to exist and find nothing after a fresh clone.
