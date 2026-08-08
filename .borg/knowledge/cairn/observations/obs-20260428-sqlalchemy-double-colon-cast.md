---
id: obs-20260428-sqlalchemy-double-colon-cast
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- sqlalchemy
- postgresql
- pgvector
- silent-failure
- type-casting
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 23:12:50.709161+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260428-sqlalchemy-double-colon-cast

## content

The Postgres cast syntax `:param::type` (e.g., `:emb::vector`) silently breaks in SQLAlchemy text() queries. SQLAlchemy's named-parameter parser misinterprets the double-colon, causing all vector search queries and embedding backfills to fail without raising any exception. Queries execute successfully but return empty results or perform no updates.

## resolution

Replace `:param::type` with `CAST(:param AS type)` in all SQLAlchemy text() queries. Affected files: search.py:27 and db.py:281,288,295.
