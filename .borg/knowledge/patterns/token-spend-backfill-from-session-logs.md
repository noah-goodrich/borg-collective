---
id: token-spend-backfill-from-session-logs
project: borg-collective
domain: observability
tags:
- token-spend
- backfill
- jsonl
- jq
- cost-tracking
preconditions: []
steps:
- Implement a SessionEnd collector hook that writes per-session records (project,
  model, raw token counts, est_cost_usd) to `~/.claude/token-spend.jsonl`
- Write `backfill-spend.sh` that replays historical session log data through the same
  cost model
- Correct the cost model against actual Anthropic pricing tiers (cache reads vs. cache
  writes vs. output vs. input; thinking billed as output)
- Run backfill to populate historical records; validate total against known billing
- Query with `jq` by project/date range for spend attribution
- Re-run backfill after any session where the collector wasn't active (e.g., hook
  loaded before collector existed)
pitfalls:
- The SessionEnd hook will NOT capture the session in which it is first installed
  — the hook loads at session start, so the current session is always missed on first
  install
- Thinking tokens are billed as output tokens, not at a separate rate; mispricing
  this causes large underestimates for Opus-heavy sessions
- Cache read vs. cache write pricing differs by ~10x; conflating them skews per-session
  estimates significantly
- Subagent token counts must be aggregated separately — they run under different models
  (Sonnet/Haiku) and the main-loop accounting won't capture them automatically without
  subagent-aware instrumentation
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.526356+00:00'
updated_at: '2026-06-16 10:27:02.526357+00:00'
---

# token-spend-backfill-from-session-logs

## description

Backfill historical token spend from existing session logs into a queryable JSONL ledger when a new spend-tracking hook is installed mid-history
