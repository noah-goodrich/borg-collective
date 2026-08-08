---
id: obs-20260501-snowfort-remediation-gated-on-user
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- snowfort
- cortex
- remediation
- session-continuity
category: tool_behavior
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.269511+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260501-snowfort-remediation-gated-on-user

## content

The Snowfort remediation plan (13 APPLY NOW items) was fully prepared and presented within Cortex session %40, but execution requires the user to explicitly say 'apply the plan' in that specific session. The session cannot be resumed or the command issued by the orchestrator on the user's behalf — it requires interactive user presence in the Cortex session.

## resolution

Documented as a blocker in the session handoff. Next session must locate Cortex session %40 and issue the apply command interactively. Starting with SEC_016 (MFA enforcement) is the recommended first action.
