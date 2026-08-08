---
id: obs-20260423-ingle-drone-container-registry-gap
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- borg
- drone
- containers
- registry
- session-history
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.201375+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260423-ingle-drone-container-registry-gap

## content

Projects running inside drone containers under /workspace appear idle in 'borg ls' even when actively running Claude sessions. The Claude session history is written inside the container filesystem and never surfaces on the host, so the borg registry sees no activity.

## resolution

Treat 'idle' status in borg ls as unreliable for container-hosted projects. To verify actual activity, inspect the container directly rather than relying on host-side registry state.
