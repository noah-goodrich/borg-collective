---
id: 20260611-anthropic-key-runtime-passthrough
date: '2026-06-11'
project: cairn
domain: infrastructure
tags:
- docker
- secrets
- compose
- security
- anthropic
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1925-cairn
created_at: '2026-06-11 22:41:19.538074+00:00'
updated_at: '2026-06-11 22:41:19.538075+00:00'
---

# 20260611-anthropic-key-runtime-passthrough

## decision

Anthropic API key passed at runtime via Keychain + gitignored `.env` + compose passthrough; image bakes no secret

## context

cairn needed LLM key access in the containerized boardroom service without committing secrets to the image or repo

## reasoning

Baking secrets into images creates security and rotation problems. Runtime passthrough via env keeps the image publishable to GHCR without credential exposure
