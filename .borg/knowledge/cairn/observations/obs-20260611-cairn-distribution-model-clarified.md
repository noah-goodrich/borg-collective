---
id: obs-20260611-cairn-distribution-model-clarified
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- distribution
- mcp
- architecture
- integration
category: domain_knowledge
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:18.018547+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-cairn-distribution-model-clarified

## content

Cairn's distribution model was clarified this session: it runs as a service (not installed as a pip package per-project). Other projects integrate via MCP over HTTP (default: http://localhost:8767/mcp), not by importing cairn as a library. The borg-collective plugin is the reference integration point.

## resolution

This distinction matters for how Phase 2 is wired: the borg plugin should call the MCP endpoint when cairn is running, not import cairn directly. Start at docs/integrations/borg-plugin-contract.md.
