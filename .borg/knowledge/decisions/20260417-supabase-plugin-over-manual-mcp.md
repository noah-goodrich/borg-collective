---
id: 20260417-supabase-plugin-over-manual-mcp
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- supabase
- claude
- mcp
- plugins
- workspace-config
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.034794+00:00'
updated_at: '2026-06-11 20:39:25.034794+00:00'
---

# 20260417-supabase-plugin-over-manual-mcp

## decision

Use `supabase@claude-plugins-official` plugin in `.claude/settings.json` rather than manually wiring Supabase MCP configuration

## context

Needed to integrate Supabase tooling into the borg-collective Claude workspace. Two paths existed: manual MCP server config or the official plugin.

## reasoning

Standardizes the integration pattern for the workspace; official plugin handles connection boilerplate and is more maintainable than hand-rolled MCP wiring.
