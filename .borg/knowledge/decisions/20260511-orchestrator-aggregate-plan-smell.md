---
id: 20260511-orchestrator-aggregate-plan-smell
date: '2026-06-16'
project: borg-collective
domain: code-quality
tags:
- orchestrator
- planning
- borg
- process
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.365883+00:00'
updated_at: '2026-06-16 10:27:02.365883+00:00'
---

# 20260511-orchestrator-aggregate-plan-smell

## decision

Orchestrator-side aggregate plan files are an anti-pattern; preference is per-project directives with immediate dispatch

## context

Session revealed that aggregating multi-project plans into a single orchestrator file creates overhead and delays; feedback captured in feedback_per_project_directives.md

## reasoning

Aggregate plans require the orchestrator to maintain cross-project state; per-project directives are self-contained, composable, and enable parallel dispatch
