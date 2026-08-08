---
id: 20260527-mcp-over-pipx-host-install
date: '2026-06-11'
project: cairn
domain: architecture
tags:
- mcp
- fastapi
- integration
- borg-collective
- optional-dependency
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1925-cairn
created_at: '2026-06-11 20:31:18.006137+00:00'
updated_at: '2026-06-11 20:31:18.006138+00:00'
---

# 20260527-mcp-over-pipx-host-install

## decision

Expose Cairn as an MCP service over Streamable HTTP rather than requiring a host-PATH pipx install

## context

The original borg-collective plugin used `command -v cairn` to detect Cairn availability, which was brittle and required developers to install Cairn globally on the host. The cairn-triage PROJECT_PLAN posed fix-or-drop.

## reasoning

MCP over HTTP decouples the plugin from host-PATH concerns, fits the 'optional dependency, never required install' principle from stillpoint-cross-project-principles, and lets the borg plugin call Cairn when present without mandating any install. The service can run in Docker alongside the rest of the stack.
