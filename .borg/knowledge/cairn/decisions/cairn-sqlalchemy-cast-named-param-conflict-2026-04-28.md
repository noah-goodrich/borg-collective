---
id: cairn-sqlalchemy-cast-named-param-conflict-2026-04-28
date: '2026-06-10'
project: cairn
domain: db
tags:
- postgres
- sqlalchemy
- pgvector
- bug
alternatives: []
applies_to: []
confidence: 0.99
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260610-1630-cairn
created_at: '2026-06-10 16:50:37.414286+00:00'
updated_at: '2026-06-10 16:50:37.414287+00:00'
---

# cairn-sqlalchemy-cast-named-param-conflict-2026-04-28

## decision

Use CAST(:emb AS vector) syntax for pgvector parameters in SQLAlchemy, not the :emb::vector Postgres shorthand cast.

## context

All search and embedding backfill silently broke — every call returned no results with no error.

## reasoning

SQLAlchemy's named parameter parser interprets the double-colon as a type cast operator and corrupts the query. CAST() is unambiguous.
