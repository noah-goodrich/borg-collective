---
id: cairn-pgvector-cast-silent-failure-2026-04-28
session_date: '2026-06-10'
project: cairn
tool: claude-code
tags:
- pgvector
- sqlalchemy
- postgres
- bug
- silent-failure
category: error_encountered
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260610-1630-cairn
superseded_by: null
created_at: '2026-06-10 16:50:37.420456+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# cairn-pgvector-cast-silent-failure-2026-04-28

## content

Using :emb::vector Postgres cast shorthand in SQLAlchemy text() queries silently breaks all pgvector search. The double-colon conflicts with SQLAlchemy's named parameter parser, causing the parameter to be misinterpreted. No exception is raised — queries simply return empty results.

## resolution

Replace all :emb::vector with CAST(:emb AS vector) in search.py and db.py.
