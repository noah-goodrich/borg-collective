---
id: 20260423-global-vs-project-claude-settings
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- claude
- settings
- global-config
- mcp
- allowlist
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.294579+00:00'
updated_at: '2026-06-11 22:41:19.294579+00:00'
---

# 20260423-global-vs-project-claude-settings

## decision

Apply MCP tool allowlist changes to ~/.claude/settings.json (global) rather than project-scoped config files

## context

Needed to decide scope when reducing Supabase MCP prompt friction affecting multiple projects (reveal, ingle)

## reasoning

The read-only Supabase tools are safe to allow universally — there is no project where allowing get_*/list_* ops would be harmful. Global scope avoids per-project config drift and immediately benefits all future projects.
