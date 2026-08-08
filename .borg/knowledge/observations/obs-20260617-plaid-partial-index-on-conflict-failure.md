---
id: obs-20260617-plaid-partial-index-on-conflict-failure
session_date: '2026-06-17'
project: borg-collective
tool: claude-code
tags:
- postgres
- plaid
- partial-index
- unique-constraint
- on-conflict
- supabase
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-17 18:01:10.025270+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260617-plaid-partial-index-on-conflict-failure

## content

A partial index (e.g., `CREATE UNIQUE INDEX ... WHERE condition`) cannot serve `ON CONFLICT` clauses in Postgres upserts — `ON CONFLICT` requires a full UNIQUE constraint, not a partial index. troth's Plaid Link was returning 500 errors because the DB had a partial unique index where a plain UNIQUE constraint was needed.

## resolution

Drop the partial index and replace with a plain UNIQUE constraint. Migration `20260615010001` applied this fix to production, resolving the live Plaid Link 500.
