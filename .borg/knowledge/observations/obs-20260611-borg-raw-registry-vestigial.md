---
id: obs-20260611-borg-raw-registry-vestigial
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- borg
- registry
- v0.8.0
- capacity
- state
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.512698+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-borg-raw-registry-vestigial

## content

Post-v0.8.0, the raw borg registry is vestigial and does NOT reflect live agent state. cmd_next and _borg_print_briefing were silently reading stale data from it, causing capacity and next-agent outputs to be wrong with no error message.

## resolution

Always use borg_registry_with_state for any runtime query about agent state, capacity, or next selection. Treat the raw registry as write-only scaffolding.
