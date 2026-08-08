---
id: sqlalchemy2-alembic-project-setup
project: cairn
domain: architecture
tags:
- sqlalchemy
- alembic
- postgres
- python
- project-setup
preconditions: []
steps:
- Define ORM models using DeclarativeBase (SQLAlchemy 2.0); include all columns needed
  for type-safe inserts but treat these as secondary to the migration DDL
- Run alembic init alembic and configure alembic.ini with a date-prefixed version
  file template (e.g., %Y%m%d_rev_slug)
- Wire alembic/env.py to the project's get_database_url() / get_engine(); add NullPool
  override path for test environments
- Write the initial migration (alembic revision --autogenerate or by hand) including
  extensions, tables, indexes, stored functions, and a complete downgrade()
- Add sqlalchemy>=2.0 and alembic to project dependencies
- Add sqlfluff to dev deps and configure .sqlfluff for the target dialect; add sqlfluff
  lint to the project's lint entrypoint
- 'Test the full cycle: alembic upgrade head, run tests, alembic downgrade base'
pitfalls:
- autogenerate does not detect stored functions, custom extensions, or HNSW indexes
  — write those migration sections by hand
- If ORM models and migrations diverge, alembic autogenerate on subsequent revisions
  will generate spurious diffs; keep models and migrations in sync
- pgvector columns (Vector(384)) require pgvector.sqlalchemy import in both ORM models
  and migration files
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:17.985689+00:00'
updated_at: '2026-06-11 20:31:17.985690+00:00'
---

# sqlalchemy2-alembic-project-setup

## description

Establish a SQLAlchemy 2.0 + Alembic foundation for a Python project: ORM models for inserts, migrations as schema source of truth
