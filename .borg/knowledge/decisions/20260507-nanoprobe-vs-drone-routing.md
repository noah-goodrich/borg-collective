---
id: 20260507-nanoprobe-vs-drone-routing
date: '2026-06-16'
project: borg-collective
domain: architecture
tags:
- orchestration
- nanoprobe
- drone
- agent-routing
- claude-code
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.345426+00:00'
updated_at: '2026-06-16 10:27:02.345426+00:00'
---

# 20260507-nanoprobe-vs-drone-routing

## decision

Nanoprobe by default for autonomous sub-tasks; drone reserved for human-review tasks; escalate to drone when nanoprobe blocks on intervention

## context

Two agentic execution patterns existed (nanoprobe via SubagentStop hook, drone via worktree exec). Needed a clear routing rule to avoid ambiguity at dispatch time.

## reasoning

Nanoprobes are lighter-weight and fully autonomous. Drones imply a handoff surface where a human may need to inspect or approve output. Keeping the default lightweight prevents over-engineering routine tasks.
