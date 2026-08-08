---
id: alembic-pgvector-initial-migration
project: cairn
domain: database
tags:
- alembic
- postgresql
- pgvector
- migrations
- hnsw
preconditions: []
steps:
- 'Enable extensions first in upgrade(): op.execute(''CREATE EXTENSION IF NOT EXISTS
  vector''); op.execute(''CREATE EXTENSION IF NOT EXISTS "uuid-ossp"'')'
- Create all tables using op.create_table() with sa.Column definitions; use pgvector.sqlalchemy.Vector(384)
  for embedding columns
- Add HNSW vector indexes via op.execute() with raw SQL (op.create_index does not
  support HNSW operator class syntax)
- Add GIN and btree filtered indexes via op.create_index() with postgresql_using and
  postgresql_where kwargs
- Create stored functions via op.execute() with CREATE OR REPLACE FUNCTION SQL
- 'Implement a complete downgrade(): drop functions, drop indexes, drop tables in
  reverse dependency order, drop extensions last'
pitfalls:
- HNSW index creation syntax (WITH (m=..., ef_construction=...)) is not expressible
  through op.create_index(); must use op.execute() with raw SQL
- 'Extension DROP order matters in downgrade: drop vector extension after all tables
  using Vector columns are dropped'
- cairn_test database must be manually pre-created before migration tests can run
  — the migration code does not CREATE DATABASE
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 23:12:50.697645+00:00'
updated_at: '2026-06-11 23:12:50.697645+00:00'
---

# alembic-pgvector-initial-migration

## description

Structure an Alembic initial migration for a Postgres schema that uses pgvector, HNSW indexes, GIN indexes, and stored functions
