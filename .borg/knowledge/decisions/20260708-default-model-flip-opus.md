---
id: 20260708-default-model-flip-opus
date: '2026-07-08'
project: borg-collective
domain: infrastructure
tags:
- model-routing
- cost-management
- claude-code
- settings
alternatives: []
applies_to: []
confidence: 0.8
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260708-1940-orchestrator
created_at: '2026-07-08 19:41:01.396128+00:00'
updated_at: '2026-07-08 19:41:01.396131+00:00'
---

# 20260708-default-model-flip-opus

## decision

Flip ~/.claude/settings.json default model from claude-fable-5[1m] to claude-opus-4-8

## context

Fable 5 is the priciest tier ($10/$50) and was silently being used by all Workflow agent() calls that didn't specify an explicit model, causing repeated session and weekly usage limit hits.

## reasoning

Opus 4.8 is sufficient for the remaining work (commits, research synthesis, security fixes). The Fable 5 tier should only be invoked deliberately for tasks that genuinely require it.
