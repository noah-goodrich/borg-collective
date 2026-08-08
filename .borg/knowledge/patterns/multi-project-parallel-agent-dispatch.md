---
id: multi-project-parallel-agent-dispatch
project: borg-collective
domain: orchestration
tags:
- borg
- parallel
- multi-project
- full-auto
preconditions: []
steps:
- Identify tracks that have no inter-dependencies (e.g., reveal beta hardening, ingle
  prod, troth scaffold are independent)
- Write per-project directives with explicit scope, acceptance criteria, and cost-pinned
  file lists
- Dispatch all agents simultaneously without waiting for cross-track confirmation
- Monitor for hard blockers only (auth failures, missing secrets, schema conflicts);
  surface immediately
- Collect commit SHAs and artifact counts from each agent as completion signal
- Write session checkpoint capturing state, blockers, and next-session entry points
  for each track
pitfalls:
- Aggregate plan files (single doc covering all tracks) become bottlenecks; use per-project
  directives instead
- Agents may overlap on shared infrastructure (e.g., two projects sharing a Supabase
  instance) causing migration timestamp collisions — pre-check and offset timestamps
- Full-auto mode still requires the orchestrator to surface credential leaks or destructive
  operation flags immediately
- Cost-pinned files must be explicitly listed in each directive or agents will touch
  them
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.366259+00:00'
updated_at: '2026-06-16 10:27:02.366259+00:00'
---

# multi-project-parallel-agent-dispatch

## description

Dispatch multiple independent sub-agents in parallel across projects when Noah enables full-auto mode; only escalate hard blockers
