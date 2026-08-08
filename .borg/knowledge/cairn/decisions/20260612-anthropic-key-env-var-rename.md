---
id: 20260612-anthropic-key-env-var-rename
date: '2026-06-12'
project: cairn
domain: infrastructure
tags:
- cairn
- anthropic
- api-key
- environment-variable
- container
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1925-cairn
created_at: '2026-06-12 03:25:39.251828+00:00'
updated_at: '2026-06-12 03:25:39.251829+00:00'
---

# 20260612-anthropic-key-env-var-rename

## decision

Map ANTHROPIC_SDK_KEY → ANTHROPIC_API_KEY inside the cairn container

## context

Cairn container was not picking up the Anthropic API key due to environment variable name mismatch

## reasoning

The SDK expects ANTHROPIC_API_KEY; the host environment uses ANTHROPIC_SDK_KEY; explicit mapping in the container config resolves the mismatch without changing host conventions
