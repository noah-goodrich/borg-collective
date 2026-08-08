---
id: supabase-shared-ledger-unblock
project: borg-collective
domain: infrastructure
tags:
- supabase
- migrations
- shared-ledger
- multi-app
preconditions: []
steps:
- Run `supabase db push --dry-run` to identify which migrations are present in the
  DB but missing from the local directory.
- For each foreign migration, create a no-op placeholder file in the local migrations
  directory with the exact same timestamp+name.
- The no-op file content should be a SQL comment only — no schema changes.
- Re-run `supabase db push --dry-run` to confirm the ledger now shows 'up to date'.
- Merge and deploy the placeholder PR before attempting any further schema migrations.
pitfalls:
- Do not copy the actual SQL from the foreign migration — the no-op approach is intentional.
  Duplicating DDL creates a second source of truth and risks double-application.
- This is a stopgap, not a permanent fix. The root fix is a clear migration ownership
  decision (which app owns the shared project's ledger going forward).
- Verify `db push --dry-run` is clean BEFORE applying any pending real migrations,
  or the real migration may partially apply against a confused ledger state.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-17 18:01:10.023161+00:00'
updated_at: '2026-06-17 18:01:10.023162+00:00'
---

# supabase-shared-ledger-unblock

## description

Unblock a Supabase `db push` that is stalled because another app has applied migrations to a shared project that the current app's migration directory doesn't know about.
