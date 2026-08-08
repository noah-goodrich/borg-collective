---
id: schema-snapshot-refresh-on-migration
project: cairn
domain: testing
tags:
- alembic
- schema-snapshot
- drift-check
- ci
preconditions: []
steps:
- After a migration file is merged to main, run the snapshot refresh script (or equivalent
  `pg_dump` command).
- 'Commit the updated `docs/schema.snapshot.sql` in a dedicated PR (e.g., cairn #27).'
- Verify the drift-check CI job goes green before merging any dependent PRs.
pitfalls:
- Easy to forget when the migration PR itself passes CI — the drift-check fails on
  the *next* PR, not the migration PR, making the root cause non-obvious.
- 'In this session, the snapshot was stale since PR #22 (migration 006 added `call_log_id`),
  leaving drift-check RED for multiple PRs until explicitly fixed.'
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260714-0405-cairn
superseded_by: null
created_at: '2026-07-14 04:06:54.530412+00:00'
updated_at: '2026-07-14 04:06:54.530413+00:00'
---

# schema-snapshot-refresh-on-migration

## description

After merging a new Alembic migration, `docs/schema.snapshot.sql` must be refreshed or the drift-check gate turns RED and blocks subsequent PRs.
