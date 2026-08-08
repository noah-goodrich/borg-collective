---
id: 20260611-multi-arch-docker-image
date: '2026-06-11'
project: cairn
domain: infrastructure
tags:
- docker
- ci
- multi-arch
- arm64
- amd64
- ghcr
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1925-cairn
created_at: '2026-06-11 23:12:50.741033+00:00'
updated_at: '2026-06-11 23:12:50.741033+00:00'
---

# 20260611-multi-arch-docker-image

## decision

Publish multi-arch (linux/amd64 + linux/arm64) images to GHCR using QEMU in GitHub Actions

## context

cairn needs to run on both x86 servers and ARM development machines (e.g., Apple Silicon). Single-arch images require per-platform builds or slow emulation at runtime.

## reasoning

QEMU + Docker buildx in CI is the standard low-friction path to multi-arch images without separate runners. Cost is longer build time, which is acceptable for a release workflow.
