---
id: 20260319-devnet-external-network
date: '2026-06-11'
project: cairn
domain: infrastructure
tags:
- docker
- devcontainer
- networking
- postgres
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1925-cairn
created_at: '2026-06-11 20:31:17.983757+00:00'
updated_at: '2026-06-11 20:31:17.983758+00:00'
---

# 20260319-devnet-external-network

## decision

Connect cairn devcontainer to an external devnet Docker network to reach dev-postgres as a named host

## context

cairn needs to connect to a shared dev-postgres container that runs on a pre-existing shared network

## reasoning

Matches established pattern in this dev environment; avoids duplicating a postgres service inside cairn's compose file; named host resolution works across containers on the same network
