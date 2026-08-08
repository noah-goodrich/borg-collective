---
id: 20260527-borg-plugin-contract-doc-over-path-check
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
created_at: '2026-06-11 20:31:18.007663+00:00'
updated_at: '2026-06-11 20:31:18.007663+00:00'
---

# 20260527-borg-plugin-contract-doc-over-path-check

## decision

Replace the brittle `command -v cairn` PATH check in the borg-collective plugin with a formal contract document (`docs/integrations/borg-plugin-contract.md`)

## context

The old detection mechanism assumed cairn was on the host PATH, which the MCP architecture makes obsolete.

## reasoning

A contract doc lets the plugin author implement proper MCP-based capability detection (HTTP reachability check) rather than a host-binary check. Decouples Cairn's deployment model from the plugin's detection logic.
