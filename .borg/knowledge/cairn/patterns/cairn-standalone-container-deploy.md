---
id: cairn-standalone-container-deploy
project: cairn
domain: infrastructure
tags:
- docker
- ghcr
- compose
- health-check
- migrations
preconditions: []
steps:
- Ensure Dockerfile.standalone and GHCR publish workflow are merged to main
- Run `bin/cairn-up` to rebuild and recreate the cairn-api container on the standalone
  image
- Verify /health and /ready endpoints return green
- Confirm migrations are at expected version via /health response or migration logs
- Wire ANTHROPIC_API_KEY via Keychain + gitignored .env + compose env passthrough
  (do not bake into image)
- 'To publish publicly: push a v* tag → GHCR publish workflow triggers → set package
  visibility to public'
pitfalls:
- GHCR package defaults to private — must explicitly set visibility to public after
  first publish if public access is intended
- Image must bake no secrets; key must come entirely from runtime environment
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 22:41:19.539775+00:00'
updated_at: '2026-06-11 22:41:19.539775+00:00'
---

# cairn-standalone-container-deploy

## description

Build, publish, and verify the cairn standalone container image
