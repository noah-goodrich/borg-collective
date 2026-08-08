---
id: alembic-migration-tdd-with-downgrade-test
project: cairn
domain: testing
tags:
- alembic
- tdd
- migration
- postgres
- docker
preconditions: []
steps:
- Run `drone exec cairn -- alembic revision -m '<description>'` to scaffold the migration
  file
- 'Write `tests/test_migration.py` BEFORE filling in the migration body: assert target
  columns exist after upgrade, assert they are absent after downgrade'
- Implement `upgrade()` and `downgrade()` in the migration file to make the tests
  pass
- Match FK shape to an existing reference table in `docs/schema.snapshot.sql` (e.g.
  `decisions` table at lines 299-323)
- Run `drone exec cairn -- pytest tests/test_migration.py` — must pass upgrade and
  downgrade
- Refresh `docs/schema.snapshot.sql` (e.g. via `pg_dump --schema-only`) and include
  in the same commit
pitfalls:
- Self-referential FKs (`superseded_by`) need `ON DELETE SET NULL` not `ON DELETE
  CASCADE` — cascading deletes would remove the entire supersession chain
- Alembic autogenerate will include the belief VIEW in its diff if SQLAlchemy has
  reflected it — exclude VIEWs from the autoload path before running autogenerate
- Forgetting to update schema.snapshot.sql in the same commit leaves documentation
  stale and can cause snapshot-diff CI checks to fail
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-21 22:17:44.754463+00:00'
updated_at: '2026-07-21 22:17:44.754464+00:00'
---

# alembic-migration-tdd-with-downgrade-test

## description

Write and run Alembic schema migrations test-first inside the container, with an explicit downgrade test and column-existence assertions
