---
id: obs-20260418-uncommitted-housekeeping-batch
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- git
- workflow
- housekeeping
category: pattern_discovered
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.267689+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260418-uncommitted-housekeeping-batch

## content

Four related housekeeping changes (.gitignore, drone.zsh, .claude/, directive doc) were completed in the same session but left uncommitted — apparently intentionally staged for a single cleanup commit. This is a clean practice but creates a recovery risk if the session context is lost before commit.

## resolution

When a session ends with an intentional 'commit later' batch, record the exact file list in the session debrief or a scratch note. Suggested commit: `git add .gitignore drone.zsh docs/plans/directives/2026-04-14-portfolio-mvp-pivot.md && git commit -m 'chore: housekeeping batch'` (resolve .claude/ policy first).
