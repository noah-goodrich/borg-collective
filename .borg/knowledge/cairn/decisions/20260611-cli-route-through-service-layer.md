---
id: 20260611-cli-route-through-service-layer
date: '2026-06-11'
project: cairn
domain: architecture
tags:
- cli
- service-layer
- embeddings
- consistency
- semantic-search
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1925-cairn
created_at: '2026-06-11 20:31:18.033522+00:00'
updated_at: '2026-06-11 20:31:18.033523+00:00'
---

# 20260611-cli-route-through-service-layer

## decision

CLI record_* functions route through cairn.service.record_* instead of calling db.insert_* directly

## context

CLI-recorded knowledge had NULL embeddings because it bypassed the service layer that handles embedding generation before insert. This made CLI-recorded rows invisible to semantic search — the primary value proposition of cairn.

## reasoning

api.py and mcp.py already routed through the service layer. Making CLI consistent with this pattern ensures all entry points produce searchable records with non-NULL embeddings.
