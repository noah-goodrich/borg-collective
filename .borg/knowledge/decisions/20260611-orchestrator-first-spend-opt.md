---
id: 20260611-orchestrator-first-spend-opt
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- cost-optimization
- token-spend
- orchestrator
- claude-opus
- subagents
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.537673+00:00'
updated_at: '2026-06-11 22:41:19.537674+00:00'
---

# 20260611-orchestrator-first-spend-opt

## decision

Reframe spend optimization as orchestrator-first: lean main context, delegate output-heavy work to subagents returning summaries, minimize main-loop turns/thinking

## context

Analysis of backfilled token spend data revealed ~96% of cost is in the main orchestrator loop (Opus: thinking-as-output + cache reads), not subagents (~4%)

## reasoning

Since the cost lever is almost entirely in the main loop, optimizing subagent routing is low-impact. The highest ROI is reducing main-loop context size and turn count
