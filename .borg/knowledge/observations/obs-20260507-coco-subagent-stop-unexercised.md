---
id: obs-20260507-coco-subagent-stop-unexercised
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- CoCo
- SubagentStop
- hook
- nanoprobe
- Cortex
category: gotcha
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.350904+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260507-coco-subagent-stop-unexercised

## content

CoCo SubagentStop registration was wired identically to Claude Code, but no Cortex nanoprobe has ever run. Correctness is assumed, not verified.

## resolution

Treat CoCo nanoprobe support as opt-in until a Cortex-originated nanoprobe exercises the hook. Do not depend on it for critical orchestration paths.
