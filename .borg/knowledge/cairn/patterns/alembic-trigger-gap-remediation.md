---
id: alembic-trigger-gap-remediation
project: cairn
domain: database
tags:
- alembic
- postgresql
- triggers
- updated_at
- migrations
preconditions: []
steps:
- 'Audit all tables with an updated_at column: SELECT table_name FROM information_schema.columns
  WHERE column_name = ''updated_at'''
- Cross-reference against pg_trigger to find tables missing a BEFORE UPDATE trigger
  calling set_updated_at()
- In the migration, CREATE OR REPLACE FUNCTION set_updated_at() if not already present
- CREATE TRIGGER trg_set_updated_at_<table> BEFORE UPDATE ON <table> FOR EACH ROW
  EXECUTE FUNCTION set_updated_at() for each gap table
- 'Include downgrade: DROP TRIGGER IF EXISTS trg_set_updated_at_<table> ON <table>'
- 'Verify with a test: UPDATE a row and assert updated_at changed'
pitfalls:
- A table can have the updated_at column (added in a prior migration) with no trigger
  — the column silently stays at its insert value forever. Always check both column
  existence AND trigger existence.
- The decisions table had updated_at from a prior PR (#33 era) but the trigger was
  never added — discovered only during the Codex migration audit
- If set_updated_at() is defined in an earlier migration, use CREATE OR REPLACE in
  the new migration to be idempotent, but verify the function body is correct first
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-24 03:53:11.045165+00:00'
updated_at: '2026-07-24 03:55:23.997706+00:00'
---

# alembic-trigger-gap-remediation

## description

Remediate tables that have an updated_at column but no BEFORE UPDATE trigger wiring it to set_updated_at(). This is a silent data quality gap — the column exists but never updates.
