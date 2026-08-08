---
id: obs-20260723-capacity-warning-before-prb
session_date: '2026-07-24'
project: cairn
tool: claude-code
tags:
- borg
- orchestration
- capacity
- project-limit
category: tool_behavior
files_involved: []
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-24 03:54:03.160312+00:00'
updated_at: '2026-07-24 03:55:24.084484+00:00'
---

# obs-20260723-capacity-warning-before-prb

## content

A capacity warning (4 active projects vs orchestrator limit of 3) was active at session start. This is an orchestrator-level constraint that can block new work from being scheduled.

## resolution

Run `borg-next` before starting PR-B to verify capacity is within limits. Do not assume the warning has cleared between sessions.
