---
id: obs-20260423-drone-container-session-history-invisible
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- claude
- borg
- drone
- container
- jsonl
- session-history
- registry
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.295253+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260423-drone-container-session-history-invisible

## content

Claude sessions running inside drone containers mounted at /workspace never write their JSONL history to the host filesystem. As a result, borg ls shows those projects as idle even when they are actively being used, and the MCP tool audit pattern (grep over ~/.claude/projects/) will silently miss all tool calls from those sessions.

## resolution

When a project appears idle in borg ls despite known activity, check whether its Claude session runs in a containerized workspace. For MCP audit purposes, either exec into the container to access its local JSONL files, or rely on external logging rather than host-side history files.
