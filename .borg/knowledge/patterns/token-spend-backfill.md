---
id: token-spend-backfill
project: borg-collective
domain: observability
tags:
- token-spend
- jsonl
- backfill
- claude-code
- cost-tracking
preconditions: []
steps:
- Implement SessionEnd hook that appends per-model raw token counts + est_cost_usd
  to ~/.claude/token-spend.jsonl
- Write backfill-spend.sh that replays historical session data through the same cost
  model
- Run backfill script to populate JSONL with pre-existing sessions
- Validate via jq queries grouping by project/time to confirm totals are plausible
- 'Note: the session active when the collector was first installed will NOT be captured
  — re-run backfill next session to include it'
pitfalls:
- The session that installs the SessionEnd collector loads it too late — the hook
  registers after session-start, so that session's spend is missed. Always re-run
  backfill the following session.
- 'Cost model errors compound across 100+ sessions — validate the per-model pricing
  constants carefully before backfilling (see PR #13 cost model correction)'
- Cache read tokens (especially Opus) dominate spend but are priced at a fraction
  of output tokens — a mispriced cache tier causes large estimation errors
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.538814+00:00'
updated_at: '2026-06-11 22:41:19.538814+00:00'
---

# token-spend-backfill

## description

Bootstrap historical token spend records from existing session logs when a new SessionEnd collector is added mid-project
