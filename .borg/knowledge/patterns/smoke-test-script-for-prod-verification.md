---
id: smoke-test-script-for-prod-verification
project: borg-collective
domain: testing
tags:
- reveal
- smoke-test
- prod-verification
- python
preconditions: []
steps:
- 'Identify all prod surface areas that can silently fail: storage bucket object existence,
  DB row counts and field constraints, API endpoints, generated asset URLs'
- Write script to check each surface area and report pass/fail with specific failure
  details
- Run script immediately after deployment to catch regressions before users do
- Commit script to repo so it is available to all future sessions
pitfalls:
- Smoke scripts that only check HTTP 200 responses miss silent data failures (e.g.,
  empty gallery, missing archetype images returning 404 from storage)
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.267213+00:00'
updated_at: '2026-06-16 10:27:02.267214+00:00'
---

# smoke-test-script-for-prod-verification

## description

Write a standalone smoke test script (scripts/smoke_prod.py) that validates all critical prod surface areas after a deployment or data import, runnable outside the application container
