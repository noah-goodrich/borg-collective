---
id: obs-20260611-pr29-updates-may-conflict-pr22
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- git
- rebase
- pr-conflicts
- documentation
category: error_encountered
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.469986+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-pr29-updates-may-conflict-pr22

## content

PR #29 touched CLAUDE.md, README.md, docs/architecture.md, and borg.zsh — many of the same files likely modified in PR #22 (docs/borg-next-level-research). This means PR #22 almost certainly has conflicts with main that need resolution before it can merge.

## resolution

Next session must check PR #22 for conflicts and rebase it onto main before attempting to merge. Use `git rebase main` on the PR branch and resolve any overlapping documentation changes.
