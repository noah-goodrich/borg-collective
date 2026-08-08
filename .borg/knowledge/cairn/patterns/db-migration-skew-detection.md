---
id: db-migration-skew-detection
project: cairn
domain: infrastructure
tags:
- database
- migrations
- readiness-probe
- deployment
preconditions: []
steps:
- Observe /ready returning 503
- Query DB for current migration version (e.g., alembic current or equivalent)
- Check deployed image's expected migration version
- If DB > image version, the probe is correct — the image needs to be updated, not
  the probe
- Deploy updated image to resolve
pitfalls:
- 503 from /ready during migration skew looks identical to a broken probe — do not
  'fix' the probe without checking versions first
- 'In this session: DB was at 006, image at 005 — /ready 503 was correct behavior,
  not a bug'
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260713-2223-cairn
superseded_by: null
created_at: '2026-07-13 22:50:48.700001+00:00'
updated_at: '2026-07-13 22:50:48.700002+00:00'
---

# db-migration-skew-detection

## description

When /ready returns 503, check DB migration version against deployed image version before assuming the probe is misconfigured.
