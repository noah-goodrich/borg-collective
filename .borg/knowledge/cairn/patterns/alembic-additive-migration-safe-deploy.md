---
id: alembic-additive-migration-safe-deploy
project: cairn
domain: infrastructure
tags:
- alembic
- postgresql
- migrations
- zero-downtime
- deployment
preconditions: []
steps:
- Verify the migration is purely additive (new columns with defaults or nullable,
  new triggers, new indexes only — no DROP, no ALTER TYPE, no column renames)
- Confirm the running image's ORM does not reference the new columns (old code must
  be safe against their presence)
- 'Run: `drone exec cairn -- env POSTGRES_DB=cairn alembic upgrade head`'
- Verify alembic_version row updated to new revision
- Re-run the test suite (or /borg-verify) against prod schema to confirm 0 findings
pitfalls:
- Do not apply this pattern if the migration drops or renames columns — the running
  image may reference the old column names and will fail at runtime
- Check that any new NOT NULL columns have a server-side DEFAULT, otherwise backfill
  will be required before the migration can complete
- Prod may lag behind dev by multiple revisions; `alembic upgrade head` will apply
  all pending migrations in sequence — review each one, not just the most recent
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-24 03:54:03.156433+00:00'
updated_at: '2026-07-24 03:55:23.997706+00:00'
---

# alembic-additive-migration-safe-deploy

## description

Apply an additive Alembic migration to a production database that is currently running an older image, when the migration only adds columns/triggers and does not drop or alter existing columns.
