---
id: obs-20260708-cairn-api-host-default-0000
session_date: '2026-07-08'
project: borg-collective
tool: claude-code
tags:
- cairn
- security
- api
- network-binding
- default-config
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260708-1940-orchestrator
superseded_by: null
created_at: '2026-07-08 19:41:01.407186+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260708-cairn-api-host-default-0000

## content

cairn/src/cairn/api.py:264 defaults CAIRN_API_HOST to 0.0.0.0, binding the API to all network interfaces. This exposes the cairn API to any network-reachable host by default, which is inappropriate for a local development tool.

## resolution

Default should be changed to 127.0.0.1. Fix is straightforward (one-line change) but has not been applied. Queued as a security follow-up for the next session.
