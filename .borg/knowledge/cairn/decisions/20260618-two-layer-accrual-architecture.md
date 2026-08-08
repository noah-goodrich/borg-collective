---
id: 20260618-two-layer-accrual-architecture
date: '2026-06-18'
project: cairn
domain: architecture
tags:
- knowledge-extraction
- launchd
- hooks
- borg
- pipeline
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260618-0029-cairn
created_at: '2026-06-18 00:30:17.384671+00:00'
updated_at: '2026-06-18 00:30:17.384673+00:00'
---

# 20260618-two-layer-accrual-architecture

## decision

Implement knowledge accrual as two independent layers: Layer 1 (borg hook on session end) + Layer 2 (launchd nightly backstop at 03:00)

## context

Single-point extraction is fragile — if a session ends abnormally or the hook fails, knowledge is lost permanently

## reasoning

Layer 1 captures immediately while context is fresh; Layer 2 provides a catch-all for sessions where Layer 1 silently failed, ensuring no extraction window is permanently missed
