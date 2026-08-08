---
id: obs-20260616-local-main-silent-divergence
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- git
- local-main
- divergence
- silent-failure
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.439610+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-local-main-silent-divergence

## content

5 commits had accumulated directly on local main without being pushed, causing local main to silently diverge from origin/main. This was not immediately visible and would have caused confusing merge conflicts or duplicate history on any subsequent branch work.

## resolution

Detected via `git log --oneline origin/main..main`. Rescued commits to a temp branch, then hard-reset local main to origin/main. Future sessions should check for local main divergence as the first step when picking up after a gap.
