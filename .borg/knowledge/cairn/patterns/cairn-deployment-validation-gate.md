---
id: cairn-deployment-validation-gate
project: cairn
domain: infrastructure
tags:
- cairn
- deployment
- validation
- data-integrity
- docker
preconditions: []
steps:
- Pull new image and start stack
- Check /health endpoint returns ok
- Check /ready endpoint and confirm migrations are at expected head (e.g., 002_documents)
- Record knowledge counts before deployment (sessions, decisions, patterns, observations,
  documents)
- Compare knowledge counts after deployment — must be equal (no data loss)
- 'Perform a live data-fix verification: record something via the in-container CLI,
  then search for it and confirm it appears with expected similarity score'
- Only after all checks pass, pin compose.yml to the new version tag
- Record rollback digest (docker inspect output) for emergency use
pitfalls:
- Skipping the before/after count comparison can miss silent data loss during migration
- The CLI-record→search round-trip specifically validates the embedding pipeline is
  live, not just that the DB is up
- GHCR package visibility may need to be manually flipped to public before the image
  is pullable outside the org
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0914-cairn
superseded_by: null
created_at: '2026-06-16 10:27:02.541342+00:00'
updated_at: '2026-06-16 10:27:02.541343+00:00'
---

# cairn-deployment-validation-gate

## description

Post-deployment validation sequence to confirm a new cairn release is safe before pinning compose.yml.
