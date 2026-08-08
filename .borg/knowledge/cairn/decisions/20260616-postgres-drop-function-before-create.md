---
id: 20260616-postgres-drop-function-before-create
date: '2026-06-16'
project: cairn
domain: infrastructure
tags:
- cairn
- postgres
- alembic
- migration
- overloading
- search_knowledge
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0914-cairn
created_at: '2026-06-16 10:27:03.265180+00:00'
updated_at: '2026-06-16 10:27:03.265181+00:00'
---

# 20260616-postgres-drop-function-before-create

## decision

Always DROP FUNCTION search_knowledge(...) with full arg-list signature before CREATE in Alembic migrations, and mirror in downgrade

## context

Adding filter_source/filter_doc_type parameters to search_knowledge() changes its signature; Postgres treats different arg-lists as different overloads

## reasoning

Postgres function overloading means CREATE OR REPLACE only replaces the exact same signature. Without DROP, the old overload remains and callers may resolve to the wrong version depending on how arguments are passed. Explicit DROP with the exact old signature is the only safe approach.
