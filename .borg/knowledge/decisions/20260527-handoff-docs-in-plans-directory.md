---
id: 20260527-handoff-docs-in-plans-directory
date: '2026-06-11'
project: borg-collective
domain: workflow
tags:
- handoff
- docs
- carry-forward
- session-management
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.452870+00:00'
updated_at: '2026-06-11 22:41:19.452870+00:00'
---

# 20260527-handoff-docs-in-plans-directory

## decision

Carry-forward context between sessions is stored as named docs under docs/plans/handoff/ rather than inline in checkpoints

## context

Session had multiple open threads that could not be resolved in a single sitting. Checkpoints alone are not discoverable enough to surface actionable next steps.

## reasoning

Handoff docs are explicitly named, structured, and contain exact commands — a future session or agent can open them directly without reconstructing context from checkpoint prose.
