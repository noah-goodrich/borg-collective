---
id: two-phase-directive-ship-then-migrate
project: borg-collective
domain: architecture
tags:
- migration
- directives
- planning
- risk-management
preconditions: []
steps:
- 'Identify the behavioral boundary: what can ship and be verified independently of
  any data migration?'
- Ship Directive A (behavior only) with full tests. Merge to main.
- 'Write Directive B stub capturing: migration plan, cutover option chosen, known
  regressions to watch, blockers. File under docs/plans/directives/.'
- Mark Directive B as blocked on Directive A being active (e.g., post-borg-setup,
  post-deploy).
- 'Next session: verify Directive A live, then promote Directive B to full directive
  and begin.'
pitfalls:
- Forgetting that 'merged to main' != 'active in current session' for hook-based tooling
  — installed hooks lag until setup is re-run.
- Directive B stub must capture enough context to reconstruct intent across sessions;
  include field-by-field migration list and chosen cutover option explicitly.
- If Directive A renames env vars or changes session classification logic, Directive
  B's migration correctness depends on A being live first — do not attempt B in the
  same session as A even if time permits.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.377484+00:00'
updated_at: '2026-06-16 10:27:02.377485+00:00'
---

# two-phase-directive-ship-then-migrate

## description

When a feature requires both behavioral changes and a data migration, ship behavioral changes as Directive A, stub the migration as Directive B blocked on A being verified live. Prevents shipping an intermediate state where new behavior depends on data that hasn't been migrated yet.
