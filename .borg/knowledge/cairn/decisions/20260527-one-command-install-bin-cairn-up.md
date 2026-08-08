---
id: 20260527-one-command-install-bin-cairn-up
date: '2026-06-11'
project: cairn
domain: infrastructure
tags:
- docker
- compose
- dx
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
created_at: '2026-06-11 20:31:18.007205+00:00'
updated_at: '2026-06-11 20:31:18.007206+00:00'
---

# 20260527-one-command-install-bin-cairn-up

## decision

Provide `bin/cairn-up` + top-level `compose.yml` that auto-detects a dev-postgres and falls back to a bundled `cairn-postgres` service

## context

README previously required multiple manual steps; new developers and CI environments needed a repeatable single-command bootstrap.

## reasoning

Reduces onboarding friction; the auto-detect logic means developers with an existing postgres don't spin up a duplicate container, while greenfield setups get a working DB without any extra config.
