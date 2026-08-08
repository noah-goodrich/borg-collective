---
id: obs-20260721-session-start-write-failure-stale-warning
session_date: '2026-07-21'
project: cairn
tool: claude-code
tags:
- session-management
- health-check
- observability
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-21 22:17:44.755408+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260721-session-start-write-failure-stale-warning

## content

A SessionStart write-failure warning visible at the beginning of the session was stale — it originated from the previous session, not the current one. The cairn service was healthy (confirmed via `/health` returning 0.5.2).

## resolution

Always verify service health independently (e.g. `GET /health`) before treating a startup warning as an active problem. Stale warnings from prior sessions can persist in log/state visibility without indicating a current fault.
