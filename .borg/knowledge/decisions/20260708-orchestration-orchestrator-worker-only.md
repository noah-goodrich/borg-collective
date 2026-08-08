---
id: 20260708-orchestration-orchestrator-worker-only
date: '2026-07-08'
project: borg-collective
domain: architecture
tags:
- orchestration
- multi-agent
- conductor
- architecture-freeze
alternatives: []
applies_to: []
confidence: 0.75
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260708-1940-orchestrator
created_at: '2026-07-08 19:41:01.399601+00:00'
updated_at: '2026-07-08 19:41:01.399602+00:00'
---

# 20260708-orchestration-orchestrator-worker-only

## decision

Freeze orchestration architecture to orchestrator-worker topology only, with a Conductor role; reject peer-to-peer and hierarchical multi-level patterns.

## context

Needed to stabilize the orchestration model before Fable's subscription tier ends, to avoid revisiting fundamental topology decisions in future sessions.

## reasoning

Orchestrator-worker is the simplest topology that supports the current use cases. Freezing 10 decisions now prevents architectural drift and gives future sessions a clear foundation to build on rather than relitigating topology.
