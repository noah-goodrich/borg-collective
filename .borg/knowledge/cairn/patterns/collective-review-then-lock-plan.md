---
id: collective-review-then-lock-plan
project: cairn
domain: architecture
tags:
- collective
- adr
- planning
- adversarial-review
preconditions: []
steps:
- Draft ADR with proposed anchors (non-negotiable invariants) and open forks (undecided
  options)
- 'Run Collective review assigning roles: Scope Hawk, Skeptic, DB Architect, Migration-Safety
  Engineer (adjust roles to domain)'
- Identify convergence vs. divergence across roles; forks with consensus get locked,
  divergent ones escalate to explicit decision record
- Record locked decisions (both recommended options or single choice) in PROJECT_PLAN.md
- Write verifiable acceptance criteria in PROJECT_PLAN.md before any implementation
- Commit PROJECT_PLAN.md; do not start implementation until criteria are locked
pitfalls:
- Skipping the plan-lock gate and jumping to implementation leaves acceptance criteria
  ambiguous — tests end up testing the implementation rather than the requirement
- Running the Collective review only at the ADR level (not at the plan/implementation
  level) misses concrete issues like SQLAlchemy autoload interaction with VIEWs
- Capacity pressure (too many active projects) can cause premature implementation
  starts before the plan is stable — treat locked plan as a hard gate
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-21 22:17:44.753694+00:00'
updated_at: '2026-07-21 22:17:44.753695+00:00'
---

# collective-review-then-lock-plan

## description

Run a multi-role Collective adversarial review on an ADR before writing PROJECT_PLAN.md acceptance criteria, ensuring design forks are resolved before implementation begins
