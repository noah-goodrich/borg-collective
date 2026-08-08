---
id: obs-20260611-sessionend-hook-misses-install-session
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- claude-code
- hooks
- sessionend
- token-spend
- lifecycle
category: tool_behavior
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.540785+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-sessionend-hook-misses-install-session

## content

A SessionEnd hook installed during a session does NOT capture that session's token spend. Claude Code loads hooks at session start; a hook registered mid-session is not active for the current session's end event.

## resolution

Documented in session notes: re-run backfill-spend.sh at the start of the next session to capture the missed session. This is expected behavior, not a bug.
