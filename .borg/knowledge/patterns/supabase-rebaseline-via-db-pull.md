---
id: supabase-rebaseline-via-db-pull
project: borg-collective
domain: infrastructure
tags:
- supabase
- migrations
- rebaseline
- consolidation
preconditions: []
steps:
- 'Take a full schema snapshot of the current live DB as a backup: `supabase db dump
  --schema-only > snapshot.sql`.'
- Run `supabase db pull` against the live project to generate a single baseline migration
  that reflects actual current state.
- Replace the existing (contaminated) migration history with the pulled baseline as
  migration `0001`.
- All future migrations are additive from this point — no retroactive repair.
- For multi-app shared projects, decide migration ownership before rebaselining so
  the new history has a single owner.
pitfalls:
- Never attempt blind repair of a contaminated ledger (manually editing old migration
  files) — `db pull` from live state is the safe path.
- The schema snapshot at step 1 is your rollback artifact — store it outside the repo.
- If multiple apps share the project, rebaselining without deciding ownership just
  defers the conflict.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-17 18:01:10.023643+00:00'
updated_at: '2026-06-17 18:01:10.023644+00:00'
---

# supabase-rebaseline-via-db-pull

## description

Safely rebaseline a contaminated Supabase migration ledger using `db pull` to establish ground truth from the live schema, rather than attempting to repair the existing migration history.
