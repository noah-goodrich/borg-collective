---
id: obs-20260420-registry-idle-null-waiting-unreachable-state
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- borg
- registry
- state-machine
- hooks
- debugging
category: gotcha
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.194844+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260420-registry-idle-null-waiting-unreachable-state

## content

Registry showed `status: idle`, `last: null`, and a non-null `waiting_reason` simultaneously on ingle and reveal — a state combination that should not be reachable through normal hook paths (waiting_reason implies a waiting status transition occurred, but status is idle and last is null).

## resolution

Not yet diagnosed. Likely stale state from earlier manual intervention, or borg-notify.sh is partially failing inside the container and leaving the registry in an intermediate state. Requires tracing borg-notify.sh execution path from inside the container. Worth a deeper trace before relying on registry state for orchestration decisions.
