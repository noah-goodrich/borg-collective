---
id: obs-20260527-untracked-hooks-not-in-pr
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- hooks
- tests
- untracked-files
- borg-plan-promote
category: gotcha
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.447286+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260527-untracked-hooks-not-in-pr

## content

`hooks/borg-plan-promote.sh` and `tests/plan_promote.bats` exist in the worktree as untracked files, and the PreToolUse auto-plan-promote pattern is already documented in CLAUDE.md — but the implementation files have never been committed. A future session could mistake 'documented in CLAUDE.md' for 'committed to the repo'.

## resolution

Explicitly listed in Next Session as a disposition item: decide whether to commit the files. Until committed, the pattern is documented but the implementation is not version-controlled and could be lost.
