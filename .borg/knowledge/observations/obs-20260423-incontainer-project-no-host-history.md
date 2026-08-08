---
id: obs-20260423-incontainer-project-no-host-history
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- claude
- borg
- drone
- container
- jsonl
- ingle
- project-registry
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.089737+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260423-incontainer-project-no-host-history

## content

ingle is registered in the borg registry and appears in 'borg ls', but has zero Claude session JSONL history on the host. This is because ingle runs inside a drone container where Claude's working directory is /workspace, not a host path. The host-side ~/.claude/projects/ directory will never accumulate logs for it.

## resolution

When auditing MCP usage for container-based projects, connect into the container and look for JSONL logs under the container's equivalent of ~/.claude/. Do not interpret missing host-side logs as 'no sessions ran'.
