---
id: alembic-integration-test-cycle
project: cairn
domain: testing
tags:
- alembic
- postgres
- integration-testing
- migrations
preconditions: []
steps:
- Pre-create a dedicated test database (e.g., cairn_test) — migrations do not create
  the database itself
- In test setup, run alembic downgrade base to ensure a clean slate regardless of
  prior state
- Run alembic upgrade head
- Assert expected tables, columns, extensions, indexes, and constraints are present
  via information_schema or pg_catalog queries
- Assert stored functions are callable with known inputs
- Run alembic downgrade base to verify the downgrade path is complete and correct
- In test teardown, run downgrade base again to leave the database clean for subsequent
  runs
pitfalls:
- cairn_test database must be manually pre-created; the migration engine will fail
  with 'database does not exist' if it is missing
- PostgreSQL DDL is non-transactional — you cannot roll back a failed upgrade inside
  a transaction; always use downgrade base for cleanup
- lru_cache on get_engine() will return the production engine unless explicitly bypassed;
  pass NullPool engine via Alembic config override in tests
- Extension creation (CREATE EXTENSION IF NOT EXISTS) requires superuser or appropriate
  privileges; test database user must have them
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:17.984440+00:00'
updated_at: '2026-06-11 20:31:17.984441+00:00'
---

# alembic-integration-test-cycle

## description

Integration test pattern for verifying Alembic migration upgrade/downgrade cycles against a real database
