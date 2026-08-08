---
id: 20260801-opus-default-fable-optin-routing
date: '2026-08-01'
project: borg-collective
domain: architecture
tags:
- model-routing
- agents
- claude-opus
- claude-fable
- settings.json
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: cairn-backfill-commit
source_model: null
source_session: null
created_at: '2026-08-01 03:01:33.312077+00:00'
updated_at: '2026-08-01 03:01:33.312078+00:00'
---

# 20260801-opus-default-fable-optin-routing

## decision

Opus 4.8 as default model, Fable 5 as explicit opt-in; codified in both agents/ROUTING.md and settings.json

## context

Model routing documentation was out of sync with actual settings.json configuration, creating ambiguity about which model agents would use

## reasoning

Single source of truth requires ROUTING.md to mirror settings.json exactly. Fable 5 opt-in preserves cost control while making the higher-capability model available for deliberate use cases.
