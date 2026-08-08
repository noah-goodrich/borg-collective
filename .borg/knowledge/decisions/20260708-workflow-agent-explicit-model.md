---
id: 20260708-workflow-agent-explicit-model
date: '2026-07-08'
project: borg-collective
domain: infrastructure
tags:
- model-routing
- workflow
- agent
- cost-management
alternatives: []
applies_to: []
confidence: 0.85
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260708-1940-orchestrator
created_at: '2026-07-08 19:41:01.398536+00:00'
updated_at: '2026-07-08 19:41:01.398537+00:00'
---

# 20260708-workflow-agent-explicit-model

## decision

Every agent() call inside Workflow scripts must pass an explicit model: parameter; no implicit inheritance from the outer session model is permitted.

## context

Discovered that Workflow agent() calls silently inherit the session's default model. With Fable 5 as default, ~40 workflow agents per session ran on the most expensive tier without any indication.

## reasoning

Explicit model selection at the call site makes cost and capability choices visible, reviewable, and auditable. It prevents accidental Fable 5 usage from spreading through automation.
