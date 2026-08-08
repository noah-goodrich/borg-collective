---
id: cairn-search-knowledge-function-upgrade
project: cairn
domain: db
tags:
- postgres
- alembic
- migration
- search
- functions
preconditions: []
steps:
- In the new migration's upgrade(), DROP FUNCTION search_knowledge(<old-arg-list>)
  before the CREATE FUNCTION with the new signature.
- In downgrade(), DROP FUNCTION search_knowledge(<new-arg-list>) and re-CREATE the
  previous version.
- Always mirror the new arg count in the SQLAlchemy db.py call site that invokes the
  function.
- Run drone exec cairn -- pytest tests/test_migration.py to verify the upgrade/downgrade
  cycle.
pitfalls:
- 'Postgres function overloading: if you CREATE a 7-arg version without DROPping the
  5-arg version, both exist. Calls with matching arg counts will hit the wrong version.'
- The downgrade must restore the exact prior signature — test with alembic downgrade
  base then alembic upgrade head.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260610-1630-cairn
superseded_by: null
created_at: '2026-06-10 16:50:37.419427+00:00'
updated_at: '2026-06-10 16:50:37.419427+00:00'
---

# cairn-search-knowledge-function-upgrade

## description

How to safely replace or extend the search_knowledge() Postgres function across migrations.
