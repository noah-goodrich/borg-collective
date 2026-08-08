---
id: 20260715-ghcr-publish-on-release-not-merge
date: '2026-07-15'
project: cairn
domain: infrastructure
tags:
- docker
- ghcr
- release
- versioning
- ci-cd
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: null
created_at: '2026-07-15 15:41:50.294314+00:00'
updated_at: '2026-07-15 15:41:50.294318+00:00'
---

# 20260715-ghcr-publish-on-release-not-merge

## decision

Publish tagged Docker images to GHCR explicitly on release (tag-publish step), not implicitly on merge to main

## context

GHCR was stale at 0.4.0 when the team needed 0.5.2 — versions 0.5.0 and 0.5.1 were never tag-published to the registry, forcing a local build for the deploy

## reasoning

Without an explicit publish step keyed to version tags, the registry drifts behind main; other devcontainers and consumers silently pull stale images. Making the publish an explicit, required release step makes the gap visible immediately.
