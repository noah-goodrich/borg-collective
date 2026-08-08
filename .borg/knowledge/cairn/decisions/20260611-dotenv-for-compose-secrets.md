---
id: 20260611-dotenv-for-compose-secrets
date: '2026-06-11'
project: cairn
domain: infrastructure
tags:
- docker-compose
- secrets
- environment-variables
- devcontainer
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1925-cairn
created_at: '2026-06-11 20:31:18.015293+00:00'
updated_at: '2026-06-11 20:31:18.015294+00:00'
---

# 20260611-dotenv-for-compose-secrets

## decision

Use gitignored `.env` (repo root) and `.devcontainer/.env` files for compose secrets; docker compose auto-loads both.

## context

POSTGRES_PASSWORD was baked as empty in compose.yml because `${POSTGRES_PASSWORD}` has no default and the shell sourcing secrets.zsh wasn't propagating into compose's environment. This caused a live DB outage with every API call returning 500/db-unreachable.

## reasoning

Docker compose natively auto-loads `.env` from the working directory, so no tooling changes are needed. Gitignoring the files keeps secrets out of version control. The pattern works identically for devcontainer and production-like local setups.
