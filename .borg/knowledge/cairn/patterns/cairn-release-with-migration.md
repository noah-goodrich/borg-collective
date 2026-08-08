---
id: cairn-release-with-migration
project: cairn
domain: infrastructure
tags:
- release
- migration
- postgresql
- deployment
- ci
preconditions: []
steps:
- Ensure all tests pass (pytest, lint) including migration class test and schema drift-check
  against pg16 throwaway snapshot
- Run /simplify pass to remove dead code before final commit
- Merge PR with migration (PR-B pattern)
- Create version bump PR/commit, tag vX.Y.Z
- Apply migration to shared prod cairn (verify prior migration version, run migration,
  confirm new version)
- Redeploy cairn-api container from local build or image
- 'Verify live: /health shows new version, /ready shows migrations match, new endpoints
  return real prod data'
- Check GHCR publish workflow completed for cross-host image availability (gh run
  list --workflow=publish-image.yml)
pitfalls:
- The local host redeployment and GHCR publish are independent — local is fast (local
  build), GHCR may still be in_progress at checkpoint; other hosts depend on GHCR,
  not the local deployment
- Schema drift-check must use a throwaway pg16 snapshot to avoid polluting prod; CI
  does this automatically but verify the workflow covers it
- Confirm the migration version chain is unbroken before applying to prod (e.g., prod
  at 007, migration is 009 — verify 008 was applied first or is included)
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-24 05:15:46.525450+00:00'
updated_at: '2026-07-24 05:15:48.164587+00:00'
---

# cairn-release-with-migration

## description

Ship a cairn release that includes a DB migration: validate CI, merge, apply migration to prod, redeploy container, verify live
