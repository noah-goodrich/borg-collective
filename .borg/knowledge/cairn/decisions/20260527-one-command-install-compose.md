---
id: 20260527-one-command-install-compose
date: '2026-06-11'
project: cairn
domain: infrastructure
tags:
- docker-compose
- developer-experience
- postgres
- onboarding
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1925-cairn
created_at: '2026-06-11 23:12:50.716905+00:00'
updated_at: '2026-06-11 23:12:50.716905+00:00'
---

# 20260527-one-command-install-compose

## decision

Provide bin/cairn-up and a top-level compose.yml that auto-detect a dev-postgres and fall back to a bundled cairn-postgres container

## context

The previous README required multiple manual steps to get Cairn running, creating friction for both new developers and the borg-collective plugin's optional integration path.

## reasoning

Single-command startup with environment auto-detection reduces onboarding friction. Fallback to bundled postgres means zero external dependencies for isolated setups while still reusing an existing dev-postgres when present.
