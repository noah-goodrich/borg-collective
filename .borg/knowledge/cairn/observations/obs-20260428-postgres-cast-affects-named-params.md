---
id: obs-20260428-postgres-cast-affects-named-params
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- sqlalchemy
- postgres
- pgvector
- text-queries
category: error_encountered
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:17.999392+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260428-postgres-cast-affects-named-params

## content

The `::` Postgres type cast operator conflicts with SQLAlchemy's named parameter syntax when used in text() queries. SQLAlchemy tokenizes `:emb::vector` as a parameter named `emb::vector` (or similar), which does not match the bound parameter `emb`, causing binding failures or no-ops. This is a known SQLAlchemy limitation with Postgres-specific syntax.

## resolution

Always use ANSI SQL `CAST(:param AS type)` syntax instead of `::` casts when writing SQLAlchemy text() queries with named parameters that precede a cast operator.
