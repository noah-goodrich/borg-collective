---
id: 20260423-supabase-mcp-allowlist-readonly
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- claude
- mcp
- supabase
- permissions
- allowlist
- settings
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.294158+00:00'
updated_at: '2026-06-11 22:41:19.294159+00:00'
---

# 20260423-supabase-mcp-allowlist-readonly

## decision

Allowlist 17 read-only Supabase MCP tools globally in ~/.claude/settings.json; keep mutating ops (execute_sql, apply_migration, branch/project lifecycle) prompt-gated

## context

Read-only Supabase MCP tool calls were generating permission prompts that interrupted Claude sessions in the reveal and ingle projects. Audited 26 actual tool_use calls to determine which tools were safe to promote.

## reasoning

Read-only ops carry no write risk and were the dominant source of friction. Mutating ops (execute_sql=7 calls, apply_migration=4 calls) were actually more frequent but carry real data-change risk, so the safety/friction tradeoff favors keeping them gated. Global scope means all future projects benefit immediately.
