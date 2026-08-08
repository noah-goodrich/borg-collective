---
id: obs-20260801-drone-postcreate-sentinel-stale
session_date: '2026-08-01'
project: borg-collective
tool: claude-code
tags:
- drone
- devcontainer
- postCreateCommand
- CLAUDE.md
- learned-lessons
- sentinel
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: null
superseded_by: null
created_at: '2026-08-01 02:47:55.568616+00:00'
updated_at: '2026-08-01 02:47:55.568618+00:00'
---

# obs-20260801-drone-postcreate-sentinel-stale

## content

CLAUDE.md contained a 'Learned lesson' stating 'drone never runs postCreateCommand'. This was false — drone DOES run postCreateCommand, but uses a sentinel guard to prevent re-execution on subsequent container starts. The lesson encoded the behavior incorrectly, likely written before the sentinel was added.

## resolution

Verified against actual drone code. Updated documentation to reflect the correct behavior: drone runs postCreateCommand once (sentinel-guarded). Treat CLAUDE.md 'Learned lessons' as potentially stale — verify against code before relying on them.
