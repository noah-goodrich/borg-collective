---
id: obs-20260611-host-cli-direct-postgres-no-http
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- cli
- postgres
- http
- architecture
- borg
- environment
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:18.036952+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-host-cli-direct-postgres-no-http

## content

The host Python CLI connects directly to Postgres (not via the cairn HTTP service). This means running 'cairn search' or 'borg search' from a Claude Code session that lacks POSTGRES_PASSWORD in its environment will fail silently or with a connection error, even if the cairn service container is healthy on :8767.

## resolution

Deferred to post-v0.2. Long-term fix would be to have the CLI optionally talk HTTP to the service rather than requiring direct DB credentials in the calling environment.
