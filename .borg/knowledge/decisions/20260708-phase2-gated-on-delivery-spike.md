---
id: 20260708-phase2-gated-on-delivery-spike
date: '2026-07-09'
project: borg-collective
domain: architecture
tags:
- tmux
- claude-code
- drone
- guardian
- spike-first
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260709-0431-orchestrator
created_at: '2026-07-09 15:25:36.240839+00:00'
updated_at: '2026-07-09 15:25:36.240841+00:00'
---

# 20260708-phase2-gated-on-delivery-spike

## decision

Gate Phase 2 checkpoint sweep on a manual delivery spike, not on a timing threshold

## context

Phase 2 would send a warning message into a mid-turn Claude pane via `tmux send-keys`. The borg:8 zombie incident demonstrated that send-keys into a busy pane has unproven behavior.

## reasoning

If `tmux send-keys '/borg-link-up' Enter` does not land in a mid-turn Claude pane, the entire checkpoint sweep mechanism is invalid and the guardian's value proposition shrinks to warn-only. This must be falsified or confirmed empirically before building.
