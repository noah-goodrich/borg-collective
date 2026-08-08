---
id: 20260527-service-layer-split-rest-mcp
date: '2026-06-11'
project: cairn
domain: architecture
tags:
- fastapi
- mcp
- service-layer
- code-reuse
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1925-cairn
created_at: '2026-06-11 20:31:18.006749+00:00'
updated_at: '2026-06-11 20:31:18.006750+00:00'
---

# 20260527-service-layer-split-rest-mcp

## decision

Extract a `cairn.service` layer so that both the REST API and the MCP endpoint share the same business logic

## context

Adding 11 MCP tools on top of an existing REST API risked duplicating logic in two handler layers.

## reasoning

Single source of truth for business logic; both transports (REST + MCP Streamable HTTP at /mcp) call into the same service functions. Keeps tests focused on service behaviour rather than transport-specific wiring.
