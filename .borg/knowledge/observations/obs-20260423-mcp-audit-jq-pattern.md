---
id: obs-20260423-mcp-audit-jq-pattern
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- claude
- mcp
- jq
- jsonl
- audit
- tool_use
category: pattern_discovered
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.290835+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260423-mcp-audit-jq-pattern

## content

Claude session JSONL files record every tool_use invocation. The specific MCP tool names can be extracted with: jq -r '..|.name? // empty' ~/.claude/projects/<slug>/*.jsonl | grep -i supabase. This reliably surfaces which MCP tools are actually being called in production sessions, enabling data-driven allowlist decisions rather than guessing.

## resolution

Use this pattern before modifying any MCP allowlist to ensure the right tools are targeted. The dominant calls in reveal/ingle were execute_sql (7), apply_migration (4), and read-only list_*/get_* ops.
