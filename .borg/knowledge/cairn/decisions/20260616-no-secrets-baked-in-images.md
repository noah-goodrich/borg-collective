---
id: 20260616-no-secrets-baked-in-images
date: '2026-06-16'
project: cairn
domain: infrastructure
tags:
- docker
- secrets
- ghcr
- anthropic
- security
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0914-cairn
created_at: '2026-06-16 10:27:02.525425+00:00'
updated_at: '2026-06-16 10:27:02.525426+00:00'
---

# 20260616-no-secrets-baked-in-images

## decision

ANTHROPIC_API_KEY passed at container runtime via Keychain + gitignored `.env` + compose passthrough; image bakes no secret

## context

cairn Dockerfile.standalone needed access to Anthropic API but publishing to GHCR means the image is potentially public

## reasoning

Secrets in images are irrevocable once pushed to a registry; runtime passthrough is the only safe pattern for public images
