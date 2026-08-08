---
id: obs-20260617-anthropic-key-scope-failure
session_date: '2026-06-17'
project: borg-collective
tool: claude-code
tags:
- cairn
- anthropic
- api-key
- environment
- docker
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-17 18:01:10.024456+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260617-anthropic-key-scope-failure

## content

cairn extraction failures attributed to 'ANTHROPIC_API_KEY expired' were actually caused by the key not being in scope when extraction ran — the key is valid inside the container but was not wired into the extraction process's environment context. The credential itself was fine.

## resolution

Diagnose API key failures by verifying the key is actually accessible in the execution environment (e.g., inside the container, in the right process scope) before concluding the key is invalid or expired.
