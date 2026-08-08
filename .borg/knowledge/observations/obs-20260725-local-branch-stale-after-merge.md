---
id: obs-20260725-local-branch-stale-after-merge
session_date: '2026-07-25'
project: borg-collective
tool: git
tags:
- git
- workflow
- housekeeping
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-25 16:56:41.544766+00:00'
updated_at: '2026-07-25 17:54:08.585417+00:00'
---

# obs-20260725-local-branch-stale-after-merge

## content

At session start the local checkout was sitting on the already-merged feature branch (feat/usage-guardian-dispatch-guard) rather than main. This means any new work started from a stale base would have diverged from the squash-merge commit on main.

## resolution

Always sync to main at the start of a session: `git checkout main && git pull origin main`. Verify with `git log --oneline -5` that HEAD matches the expected merge commit.
