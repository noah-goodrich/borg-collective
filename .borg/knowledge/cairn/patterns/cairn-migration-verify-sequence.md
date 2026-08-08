---
id: cairn-migration-verify-sequence
project: cairn
domain: infrastructure
tags:
- cairn
- postgres
- migration
- alembic
preconditions: []
steps:
- Connect to cairn DB (drone exec cairn or direct psql with credentials)
- 'Run: SELECT version_num FROM alembic_version; — confirm head matches expected revision
  ID'
- 'Confirm target table exists: \d documents (or equivalent)'
- Run a smoke test write + read to confirm the table is live and accessible
pitfalls:
- Alembic version table may show a prior revision if migration script ran but errored
  partway — always check table existence, not just version_num
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:18.025586+00:00'
updated_at: '2026-06-11 20:31:18.025587+00:00'
---

# cairn-migration-verify-sequence

## description

Sequence for verifying a cairn DB migration landed correctly in production.
