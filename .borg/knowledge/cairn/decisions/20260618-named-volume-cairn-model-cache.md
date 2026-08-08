---
id: 20260618-named-volume-cairn-model-cache
date: '2026-06-18'
project: cairn
domain: infrastructure
tags:
- docker
- compose
- volumes
- devcontainer
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260618-0029-cairn
created_at: '2026-06-18 00:30:17.377473+00:00'
updated_at: '2026-06-18 00:30:17.377483+00:00'
---

# 20260618-named-volume-cairn-model-cache

## decision

Use a named Docker volume `cairn-model-cache` in compose.yml instead of an anonymous or bind-mount volume

## context

Backfill robustness work on fix/backfill-extraction-robustness branch revealed model cache needed persistent, named storage to survive container restarts without conflicting with devcontainer setup

## reasoning

Named volumes are portable across compose file references, survive `docker compose down` without `-v`, and can be explicitly managed; anonymous volumes get orphaned and bind mounts create host-path coupling
