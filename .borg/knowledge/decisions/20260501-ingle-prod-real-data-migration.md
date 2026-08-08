---
id: 20260501-ingle-prod-real-data-migration
date: '2026-06-16'
project: borg-collective
domain: infrastructure
tags:
- ingle
- supabase
- data-migration
- mcp
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.266027+00:00'
updated_at: '2026-06-16 10:27:02.266028+00:00'
---

# 20260501-ingle-prod-real-data-migration

## decision

Migrate real Goodrich family data directly to prod Supabase; confirm dummy Jane/John Smith data never existed in prod (only local seed)

## context

Before going live with the MCP server, it was necessary to verify that no placeholder/demo data was present in prod and that real family preferences were correctly populated.

## reasoning

Auditing seed vs. prod environments before live deployment prevents embarrassing or incorrect data being served through the MCP tool. Confirming dummy data scope (local-only) meant no teardown step was required in prod.
