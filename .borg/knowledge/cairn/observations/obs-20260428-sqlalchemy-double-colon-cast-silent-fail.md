---
id: obs-20260428-sqlalchemy-double-colon-cast-silent-fail
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- sqlalchemy
- pgvector
- postgres
- named-parameters
- silent-failure
- vector-search
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:17.998379+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260428-sqlalchemy-double-colon-cast-silent-fail

## content

SQLAlchemy's text() parameter parser interprets `::` in `:emb::vector` as part of the parameter name, not as Postgres cast syntax. The query is sent to Postgres with a malformed parameter binding — no exception is raised, searches return empty results, and embedding UPDATE statements silently affect 0 rows. This broke all vector search and the entire embedding backfill pipeline.

## resolution

Replace all instances of `:param::type` with `CAST(:param AS type)` in SQLAlchemy text() expressions. Affected files: search.py:27 and db.py:281,288,295.
