---
id: obs-20260423-ac-smoke-test-requires-real-session
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- testing
- notifications
- claude
- tmux
- smoke-test
category: tool_behavior
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.117348+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260423-ac-smoke-test-requires-real-session

## content

The double-fire acceptance criterion (AC2) for the notification bridge cannot be verified synthetically or in a single coding session. It requires an actual Claude orchestrator turn to complete in a live tmux session, which produces the real state file transition that borg-notifyd watches.

## resolution

Accept this as a manual smoke test step. Schedule it as the first action in the next interactive session. Watch stderr of notify.sh during the test to confirm the /.dockerenv guard is firing correctly.
