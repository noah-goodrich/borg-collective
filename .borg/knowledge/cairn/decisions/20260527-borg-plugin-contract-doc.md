---
id: 20260527-borg-plugin-contract-doc
date: '2026-06-11'
project: cairn
domain: integration
tags:
- borg-collective
- mcp
- contract
- documentation
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1925-cairn
created_at: '2026-06-11 23:12:50.717330+00:00'
updated_at: '2026-06-11 23:12:50.717330+00:00'
---

# 20260527-borg-plugin-contract-doc

## decision

Replace the brittle `command -v cairn` PATH check in the cairn-restoration directive with a formal contract document at docs/integrations/borg-plugin-contract.md

## context

The borg-collective plugin needed a stable interface description to integrate with Cairn optionally. A shell PATH check provided no versioning or capability discovery.

## reasoning

A contract document provides a stable, human- and machine-readable specification of the MCP endpoint, available tools, and version requirements. Decouples the plugin's integration logic from Cairn's deployment topology.
