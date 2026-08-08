---
id: obs-20260501-mcp-prod-smoke-before-launch
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- ingle
- mcp
- smoke-test
- prod-verification
category: pattern_discovered
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.269174+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260501-mcp-prod-smoke-before-launch

## content

After deploying the Ingle MCP server and migrating prod data, a live MCP smoke test (calling family_get_preferences through the actual deployed worker) was run before declaring the service ready. This caught any gap between the migration script's reported success and actual data accessibility through the API layer.

## resolution

Smoke test passed. Pattern: always exercise the full request path (client → worker → Supabase) after a data migration, not just verify DB rows directly.
