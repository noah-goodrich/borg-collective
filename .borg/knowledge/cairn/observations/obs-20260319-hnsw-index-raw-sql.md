---
id: obs-20260319-hnsw-index-raw-sql
session_date: '2026-03-19'
project: cairn
tool: cursor
tags:
- alembic
- pgvector
- hnsw
- postgresql
- indexes
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 23:12:50.699611+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260319-hnsw-index-raw-sql

## content

Alembic's op.create_index() cannot express HNSW index syntax for pgvector (e.g., USING hnsw (column vector_cosine_ops) WITH (m=16, ef_construction=64)). Attempting to use op.create_index() with postgresql_using='hnsw' and operator class arguments results in malformed DDL.

## resolution

Use op.execute() with raw SQL strings for all HNSW index creation and their corresponding DROP INDEX in downgrade(). GIN and standard btree indexes can still use op.create_index().
