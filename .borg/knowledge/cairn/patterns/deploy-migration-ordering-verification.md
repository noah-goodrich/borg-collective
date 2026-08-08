---
id: deploy-migration-ordering-verification
project: cairn
domain: infrastructure
tags:
- deployment
- alembic
- migration
- docker
- ghcr
preconditions: []
steps:
- Merge migration code to main
- Confirm the new image tag is published to the registry (check workflow success)
- Update docker-compose or deployment manifest to reference the new tag
- Recreate the container (not just restart) so the new image is pulled
- Check service health and alembic head alignment before declaring done
pitfalls:
- A container restart reuses the cached image — if the tag hasn't changed in compose,
  you're still running the old code against the upgraded DB
- In a shared environment where multiple projects use one cairn-api, a pause/restart
  by any operator can surface the skew at any time, not just during your deploy window
- alembic upgrade runs at startup; if the code ceiling is below the DB stamp, startup
  crashes silently from the service consumer's perspective
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260709-1535-cairn
superseded_by: null
created_at: '2026-07-09 15:36:29.693876+00:00'
updated_at: '2026-07-09 15:36:29.693877+00:00'
---

# deploy-migration-ordering-verification

## description

After merging a migration, verify that the running image in all environments is rebuilt from the new HEAD before restarting the service. A stale image (old migration ceiling) against an already-upgraded DB causes a crash-loop on startup.
