---
id: obs-20260611-pr29-gitignore-scope-creep
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- gitignore
- scope
- untracked-files
- deferred-commits
category: gotcha
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.478509+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-pr29-gitignore-scope-creep

## content

Deferred untracked files accumulated across multiple sessions into a large catch-up PR (PR #29). This made the PR harder to review and increased the risk of the gitignore error (above) going unnoticed, since reviewers see many files at once and may not scrutinize each gitignore line.

## resolution

Merged as-is for pragmatic reasons, but the pattern of deferring untracked files risks compounding errors. Committing .gitignore changes immediately when the need is identified would have caught the erroneous '.borg/' line sooner.
