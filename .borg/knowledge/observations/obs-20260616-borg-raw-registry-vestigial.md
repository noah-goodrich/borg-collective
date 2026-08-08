---
id: obs-20260616-borg-raw-registry-vestigial
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- borg
- registry
- v0.8.0
- state
- capacity
- next
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.493071+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-borg-raw-registry-vestigial

## content

After v0.8.0, the raw borg registry no longer carries agent state (active/waiting/idle). Any code reading the raw registry for state-dependent logic (capacity counts, next-agent selection) silently gets wrong answers — typically treating all agents as idle. Both cmd_next and _borg_print_briefing had this bug.

## resolution

All state-dependent reads must use borg_registry_with_state. Audit any function that inspects agent state and confirm it is not reading the raw registry.
