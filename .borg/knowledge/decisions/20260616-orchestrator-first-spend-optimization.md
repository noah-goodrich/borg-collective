---
id: 20260616-orchestrator-first-spend-optimization
date: '2026-06-16'
project: borg-collective
domain: architecture
tags:
- token-spend
- cost-optimization
- opus
- orchestration
- subagents
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.524954+00:00'
updated_at: '2026-06-16 10:27:02.524955+00:00'
---

# 20260616-orchestrator-first-spend-optimization

## decision

Reframe spend optimization as orchestrator-first: lean main context, delegate output-heavy work to subagents returning summaries, minimize main-loop turns and thinking

## context

Initial spend analysis attributed costs incorrectly. After correcting the cost model, a heavy session is ~96% main-loop (Opus thinking-as-output + cache reads) and ~4% subagents

## reasoning

The 96% main-loop share means the only meaningful cost lever is reducing Opus main-loop token burn — not subagent tier-routing, which was already optimized. Output-heavy delegation to subagents with summary returns directly reduces the expensive component.
