---
id: 20260428-cairn-http-api-architecture
date: '2026-06-11'
project: cairn
domain: architecture
tags:
- fastapi
- http-api
- service-architecture
- devcontainers
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1925-cairn
created_at: '2026-06-11 20:31:17.995848+00:00'
updated_at: '2026-06-11 20:31:17.995849+00:00'
---

# 20260428-cairn-http-api-architecture

## decision

Implement cairn as a persistent HTTP API service (FastAPI on port 8767) rather than a CLI tool that connects directly to Postgres

## context

Cairn needs to work from host, multiple devcontainers, Claude Code sandboxes, and cron jobs — all of which have different environments and network contexts

## reasoning

A single API service on devnet means all containers share one connection point regardless of their local environment. The shell client becomes a thin curl wrapper, which works in stripped environments (cron, Claude Code sandbox) where Python dependencies or Postgres access may not be available.
