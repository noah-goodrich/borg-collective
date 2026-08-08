---
id: 20260618-rename-devcontainer-service-cairn-api-dev
date: '2026-06-18'
project: cairn
domain: infrastructure
tags:
- docker
- devcontainer
- port-conflict
- compose
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260618-0029-cairn
created_at: '2026-06-18 00:30:17.383553+00:00'
updated_at: '2026-06-18 00:30:17.383554+00:00'
---

# 20260618-rename-devcontainer-service-cairn-api-dev

## decision

Rename the devcontainer docker-compose service to `cairn-api-dev` to avoid port conflicts

## context

The `.devcontainer/docker-compose.yml` service name was colliding with the main `compose.yml` service, causing port binding conflicts when both were active

## reasoning

Distinct service names prevent Docker Compose from merging or conflicting services when devcontainer tooling and manual compose invocations coexist on the same machine
