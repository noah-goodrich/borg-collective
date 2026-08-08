---
id: 20260709-b-seam-optional-token-params
date: '2026-07-09'
project: cairn
domain: architecture
tags:
- api-design
- extensibility
- mcp
- token-tracking
- schema-evolution
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260709-1535-cairn
created_at: '2026-07-09 15:36:29.691802+00:00'
updated_at: '2026-07-09 15:36:29.691803+00:00'
---

# 20260709-b-seam-optional-token-params

## decision

Accept optional session_id/call_source/token params in /search and MCP search/briefing now, persisting only when supplied, so per-turn token hooks require no future migration

## context

The per-turn PostToolUse token hook (B fast-follow) needs to inject token counts into the cairn tool call, but was not being built this session

## reasoning

Migrations are expensive in a shared deployed DB. Carving the seam now means the hook can be added as a pure client-side change with no schema or API changes. The optional columns add zero cost when absent.
