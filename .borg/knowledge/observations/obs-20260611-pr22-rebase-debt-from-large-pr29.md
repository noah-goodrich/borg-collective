---
id: obs-20260611-pr22-rebase-debt-from-large-pr29
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- git
- rebase
- merge-conflicts
- pr-ordering
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.479472+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-pr22-rebase-debt-from-large-pr29

## content

PR #29 touched many files (gitignore, CLAUDE.md, README, architecture docs, session checkpoints). Any open PR that also touches those files will now have merge conflicts with main. PR #22 (docs/borg-next-level-research) is the known casualty and requires a rebase pass before it can merge.

## resolution

Flagged for next session: rebase PR #22 onto main, resolve conflicts, force-push. No immediate action needed as PR #22 is non-blocking research content.
