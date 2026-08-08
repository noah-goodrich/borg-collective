---
id: obs-20260423-ingle-container-no-host-history
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- ingle
- claude
- drone
- container
- borg
- session-history
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.290458+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260423-ingle-container-no-host-history

## content

The ingle project runs inside a drone container at /workspace, so Claude session JSONL files are written inside the container rather than to the host ~/.claude/projects/ directory. borg ls shows ingle as registered but its session history appears absent from the host, which can look like the project is idle or has never been used when inspecting from the host.

## resolution

When auditing Claude tool_use history for ingle, exec into the drone container and inspect /workspace/.claude/ (or equivalent container path) rather than the host ~/.claude/projects/ slug directory.
