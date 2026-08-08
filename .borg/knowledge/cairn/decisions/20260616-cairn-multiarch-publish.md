---
id: 20260616-cairn-multiarch-publish
date: '2026-06-16'
project: cairn
domain: infrastructure
tags:
- cairn
- docker
- multi-arch
- ghcr
- arm64
- amd64
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0914-cairn
created_at: '2026-06-16 10:27:02.540546+00:00'
updated_at: '2026-06-16 10:27:02.540546+00:00'
---

# 20260616-cairn-multiarch-publish

## decision

cairn Docker images are published as multi-arch manifests (linux/amd64 + linux/arm64) via QEMU + buildx.

## context

cairn needed to be deployable on both x86 servers and Apple Silicon dev machines without separate image tags.

## reasoning

Single manifest covering both architectures eliminates platform-specific image references and allows the same compose.yml to work across machine types.
