---
id: obs-20260708-fable5-weekly-limit-multi-hits
session_date: '2026-07-08'
project: borg-collective
tool: claude-code
tags:
- fable-5
- usage-limits
- cost
- session-limits
- workflow
category: performance
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260708-1940-orchestrator
superseded_by: null
created_at: '2026-07-08 19:41:01.408107+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260708-fable5-weekly-limit-multi-hits

## content

A single project session hit 3 session limits and 1 weekly limit when running with Fable 5 as the default model and ~40 workflow agents per session. The weekly limit is particularly disruptive because it blocks all work until the reset, not just the current session.

## resolution

Resolved by: (1) switching default to Opus 4.8, (2) requiring explicit model routing in all workflow scripts, (3) parking Fable-appropriate work and resuming on cheaper models after reset. Future sessions should treat any workflow with >5 agent() calls as a cost-risk requiring explicit model audit before execution.
