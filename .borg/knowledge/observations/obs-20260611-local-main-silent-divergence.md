---
id: obs-20260611-local-main-silent-divergence
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- git
- local-main
- branch-hygiene
- commit-hygiene
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.469327+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-local-main-silent-divergence

## content

5 commits accumulated on local main without being pushed, causing local main to silently diverge from origin/main. This went undetected until a merge operation revealed the divergence. Local main divergence is invisible in normal daily use unless you check `git status` with upstream tracking or run `git log origin/main..main`.

## resolution

Rescued commits to a feature branch (`feat/orchestrator-mode-session-separation`), then `git reset --hard origin/main` to realign local main. Prevention: add a shell prompt or pre-push hook that warns when local main is ahead of origin/main.
