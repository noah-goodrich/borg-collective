---
id: obs-20260623-monthly-spend-limit-kills-subagents
session_date: '2026-06-23'
project: cairn
tool: claude-code
tags:
- claude
- spend-limit
- subagent
- token-spend
- reliability
category: tool_behavior
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260623-0355-cairn
superseded_by: null
created_at: '2026-06-23 03:56:23.663198+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260623-monthly-spend-limit-kills-subagents

## content

When the monthly Claude spend limit is hit, subagent/workflow dispatch fails mid-task with 'You've hit your monthly spend limit.' The main loop remains operational but any task that forks a subagent (e.g., token-cost nanoprobe a06437) will die mid-execution. This is not a crash — it is a silent partial failure that may leave work uncommitted or state inconsistent.

## resolution

Raise the limit at claude.ai/settings/usage or wait for monthly reset. Until then, avoid dispatching subagent-heavy workflows. The main loop can still be used for interactive work.
