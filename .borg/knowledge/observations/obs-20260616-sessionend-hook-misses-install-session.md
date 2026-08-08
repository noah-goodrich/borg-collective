---
id: obs-20260616-sessionend-hook-misses-install-session
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- hooks
- sessionend
- token-spend
- claude-code
- plugin-lifecycle
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.527637+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-sessionend-hook-misses-install-session

## content

A SessionEnd hook installed during a session will NOT capture that session's token spend. Claude Code loads hooks at session start; hooks registered mid-session are not retroactively applied to the current session.

## resolution

After installing the spend collector, restart Claude Code to activate it. Run `backfill-spend.sh` after the next session to capture the install session if needed.
