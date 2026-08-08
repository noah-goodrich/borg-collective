---
id: contradiction-detection-idempotent-queue
project: cairn
domain: architecture
tags:
- contradiction-detection
- belief-store
- idempotency
- state-machine
preconditions: []
steps:
- Detect candidate pairs using similarity threshold (config-driven)
- Insert into contradiction_review with ON CONFLICT DO NOTHING on UNIQUE(belief_id,
  conflicting_id)
- 'Route through state machine: proposed → superseded | invalidated | dismissed'
- Treat dismissed as terminal — dismissed pairs never re-enter the queue
- Expose queue via REST + MCP tools for human review
pitfalls:
- Without the UNIQUE constraint + ON CONFLICT DO NOTHING, repeated detection runs
  bloat the queue and re-surface dismissed pairs
- State machine must enforce terminal states at the application layer in addition
  to any DB constraints — callers should reject transition attempts out of dismissed
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-24 05:15:46.526218+00:00'
updated_at: '2026-07-24 05:15:48.164587+00:00'
---

# contradiction-detection-idempotent-queue

## description

Pattern for building an idempotent contradiction detection queue that respects terminal review states
