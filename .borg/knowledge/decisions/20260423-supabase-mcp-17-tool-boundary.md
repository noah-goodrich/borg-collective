---
id: 20260423-supabase-mcp-17-tool-boundary
date: '2026-06-16'
project: borg-collective
domain: infrastructure
tags:
- claude-code
- mcp
- supabase
- allowlist
- tool-taxonomy
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.200282+00:00'
updated_at: '2026-06-16 10:27:02.200283+00:00'
---

# 20260423-supabase-mcp-17-tool-boundary

## decision

The safe/unsafe boundary for Supabase MCP tools was drawn at: generate_typescript_types, get_*, list_*, search_docs = safe; execute_sql, apply_migration, branch/project lifecycle ops = gated

## context

Needed a principled, auditable line for what goes in the allowlist rather than ad-hoc decisions.

## reasoning

Name-based heuristic (get_/list_ prefixes + generate_typescript_types + search_docs) maps cleanly onto read-only semantics. The exceptions (execute_sql, apply_migration) are write ops regardless of how they're called.
