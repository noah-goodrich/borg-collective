---
id: cairn-release-deploy-verify
project: cairn
domain: infrastructure
tags:
- release
- docker
- deployment
- verification
- ghcr
preconditions: []
steps:
- Bump version in code and tag the git commit (e.g., v0.5.2)
- 'Build the image locally: `docker compose --project-name cairn build cairn-api`'
- 'Bring up the new container: `docker compose --project-name cairn up -d cairn-api`'
- Verify /health returns the new version string
- Verify /ready returns 200 (migrations at head, model loaded)
- Smoke-test any newly added endpoints (e.g., /stats/reuse, /stats/usage)
- Publish multi-arch image to GHCR with versioned tags (X.Y.Z, X.Y, latest)
pitfalls:
- GHCR may be stale by multiple minor versions if the publish step was skipped in
  prior releases — always check the registry tag before assuming it is current
- Docker Desktop can hang host-wide overnight; verify daemon health before starting
  a deploy session
- Building locally will succeed even if GHCR publish fails — confirm the push completed
  before declaring the release done for other consumers
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-15 15:41:50.298120+00:00'
updated_at: '2026-07-15 15:41:50.298121+00:00'
---

# cairn-release-deploy-verify

## description

End-to-end release flow for cairn-api: build locally, deploy, verify endpoints, then publish to GHCR
