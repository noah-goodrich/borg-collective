---
id: cairn-add-alembic-migration
project: cairn
domain: db
tags:
- alembic
- postgres
- migration
- schema
preconditions: []
steps:
- 'Generate the revision: drone exec cairn -- alembic revision --autogenerate -m ''<message>'''
- Set down_revision to the previous migration's revision ID (e.g., '001_initial').
- If the migration adds or replaces a Postgres function, DROP the old overload explicitly
  before CREATE — Postgres overloads on argument list and will not replace a function
  with a different signature silently.
- Implement a complete downgrade() that reverses every CREATE TABLE, CREATE INDEX,
  CREATE FUNCTION, and CREATE EXTENSION in reverse order.
- 'Apply: drone exec cairn -- alembic upgrade head'
- 'Verify with the test suite: drone exec cairn -- pytest tests/test_migration.py
  -v'
pitfalls:
- Forgetting to DROP the old search_knowledge() overload before CREATE with a new
  signature leaves both overloads active and causes ambiguous-function errors at query
  time.
- Using Base.metadata.create_all() instead of alembic upgrade head will silently diverge
  the schema from migration history.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260610-1630-cairn
superseded_by: null
created_at: '2026-06-10 16:50:37.417503+00:00'
updated_at: '2026-06-10 16:50:37.417504+00:00'
---

# cairn-add-alembic-migration

## description

How to add a new Alembic migration to the cairn schema without breaking the downgrade chain.
