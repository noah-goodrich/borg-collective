---
id: 20260616-kill-llm-debrief-use-checkpoints
date: '2026-06-16'
project: borg-collective
domain: architecture
tags:
- session-lifecycle
- checkpoint
- debrief
- llm-cost
- borg-hooks
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.209502+00:00'
updated_at: '2026-06-16 10:27:02.209503+00:00'
---

# 20260616-kill-llm-debrief-use-checkpoints

## decision

Removed the Sonnet LLM debrief generation on session stop. SessionStart hook now reads the newest checkpoint file directly instead of a debrief file.

## context

The debrief system ran a Sonnet LLM call on every session stop to summarize the session into a debrief file, which the start hook then loaded. Checkpoints (written by /borg-checkpoint skill) contained equivalent structured information written by the operator deliberately.

## reasoning

Checkpoints are higher-signal than auto-generated debriefs because they capture operator intent rather than LLM summarization of tool calls. Eliminating the stop-time LLM call reduces cost and latency on every session end. The debrief skill was redundant once checkpoints existed.
