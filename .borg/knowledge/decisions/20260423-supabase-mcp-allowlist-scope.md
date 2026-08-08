---
id: 20260423-supabase-mcp-allowlist-scope
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- claude
- mcp
- supabase
- permissions
- allowlist
- developer-experience
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.088463+00:00'
updated_at: '2026-06-11 20:39:25.088464+00:00'
---

# 20260423-supabase-mcp-allowlist-scope

## decision

Allowlist only read-only Supabase MCP tools globally; leave mutating ops (execute_sql, apply_migration, branch/project lifecycle) behind a prompt.

## context

Supabase MCP permission prompts were creating friction across multiple Claude sessions in reveal and ingle projects. 26 real tool invocations were audited to determine which tools were actually being called.

## reasoning

Read-only ops (list_*, get_*, generate_typescript_types, search_docs) carry no destructive risk and were generating most of the prompt noise. Mutating ops like execute_sql and apply_migration have irreversible consequences and warrant a human checkpoint each time.
