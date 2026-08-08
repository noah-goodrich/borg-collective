---
id: cairn-standalone-container-rollout
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
- Add `Dockerfile.standalone` with no baked secrets
- Add GHCR publish workflow triggered on `v*` tags
- Implement `/health` and `/ready` endpoints as the container health contract
- 'Wire API key via: Keychain entry → gitignored `.env` file → compose `environment`
  passthrough'
- Run `bin/cairn-up` to rebuild and recreate container from standalone image
- Verify `/health` + `/ready` return green and migrations are current
- 'To publish publicly: push a `v*` tag, then set the GHCR package visibility to public'
pitfalls:
- Until a `v*` tag is pushed, GHCR publish workflow never runs — the image exists
  only locally
- GHCR packages default to private; must explicitly set public after first publish
  if open distribution is intended
- '`.env` must be gitignored before the key is written to it — verify `.gitignore`
  entry exists first'
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0914-cairn
superseded_by: null
created_at: '2026-06-16 10:27:02.527245+00:00'
updated_at: '2026-06-16 10:27:02.527246+00:00'
---

# cairn-standalone-container-rollout

## description

Ship cairn as a self-contained Docker image with health contract and LLM key passthrough
