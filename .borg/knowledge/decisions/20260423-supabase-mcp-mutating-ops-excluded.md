---
id: 20260423-supabase-mcp-mutating-ops-excluded
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- mcp
- supabase
- security
- allowlist
- claude
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.113659+00:00'
updated_at: '2026-06-11 20:39:25.113660+00:00'
---

# 20260423-supabase-mcp-mutating-ops-excluded

## decision

Exclude execute_sql and apply_migration from the global Claude MCP allowlist; keep them behind interactive prompts.

## context

Allowlisting read-only Supabase MCP tools to reduce prompt friction during normal development sessions.

## reasoning

Silent schema changes carry disproportionate risk — a misfire from execute_sql or apply_migration could corrupt production data or schema without any human checkpoint. The prompt friction for these two operations is an intentional safety gate.
