---
id: obs-20260418-uncommitted-session-batch
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- git
- workflow
- housekeeping
- borg-collective
category: gotcha
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.046331+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260418-uncommitted-session-batch

## content

Session ended with four related changes (.gitignore, drone.zsh, .claude/, portfolio directive) all unstaged. These appear intentionally grouped for a single cleanup commit but were not committed before session end, creating a risk of them being lost or interleaved with unrelated future work.

## resolution

Commit the batch explicitly before starting new work: git add .gitignore drone.zsh docs/plans/directives/2026-04-14-portfolio-mvp-pivot.md && git commit. Resolve .claude/ gitignore policy first (see obs-20260418-claude-settings-local-gitignore-gap).
