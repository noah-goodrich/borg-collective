---
id: cairn-backfill-source-session
project: cairn
domain: data-migration
tags:
- backfill
- source-session
- attribution
- idempotency
preconditions: []
steps:
- Run `cairn backfill-source-session` (no flags) to preview affected counts and validate
  project-match guards
- 'Review output: confirm expected record counts and that 0 dangling FKs are projected'
- Run `cairn backfill-source-session --commit` to write attribution
- Re-run without --commit (or with --commit) to confirm 0 records updated (idempotency
  check)
- Spot-check a sample of attributed records to verify project alignment
pitfalls:
- Attribution can only reach ~82% — records created before session tracking existed
  have no recoverable session; the remaining ~18% requires LLM inference to attribute
- The 'gap cap' (max records to attribute per run) defaults to unlimited in the full-backfill
  mode — confirm this is intended before running against prod
- 'Project-mismatch guard is critical: a session''s project must match the record''s
  project or attribution is skipped; verify this logic in dry-run output'
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-15 15:41:50.298793+00:00'
updated_at: '2026-07-15 15:41:50.298794+00:00'
---

# cairn-backfill-source-session

## description

Attribute existing unattributed records (decisions/patterns/observations) to their originating sessions using the backfill-source-session command
