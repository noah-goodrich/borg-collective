---
id: 20260611-multi-arch-image-qemu
date: '2026-06-11'
project: cairn
domain: infrastructure
tags:
- docker
- multi-arch
- amd64
- arm64
- ghcr
- ci
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1925-cairn
created_at: '2026-06-11 20:31:18.034781+00:00'
updated_at: '2026-06-11 20:31:18.034781+00:00'
---

# 20260611-multi-arch-image-qemu

## decision

Build and publish multi-arch Docker image (linux/amd64 + linux/arm64) using QEMU in publish-image.yml

## context

cairn needs to run on both developer laptops (Apple Silicon / arm64) and typical cloud/CI hosts (amd64). A single-arch image forces one group to run under emulation or rebuild locally.

## reasoning

QEMU-based cross-compilation in CI is well-supported by docker/setup-qemu-action and buildx, adding minimal CI complexity while producing a single manifest that works natively on both architectures.
