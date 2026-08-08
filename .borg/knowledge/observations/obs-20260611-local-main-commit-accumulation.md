---
id: obs-20260611-local-main-commit-accumulation
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- git
- local-main
- branch-hygiene
- workflow
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.478825+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-local-main-commit-accumulation

## content

5 commits accumulated directly on local main across sessions before the divergence was noticed. This is a silent failure mode — git does not warn that you are committing to a branch that is supposed to track a remote. The divergence only surfaces when you attempt to push or pull.

## resolution

Rescued to a temp branch, reset local main to origin/main. Prevention: always verify current branch before committing (git branch or prompt integration showing branch name); consider a pre-commit hook that warns on direct commits to main.
