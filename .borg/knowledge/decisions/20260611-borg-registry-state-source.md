---
id: 20260611-borg-registry-state-source
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- borg
- registry
- state
- v0.8.0
- capacity
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.510486+00:00'
updated_at: '2026-06-11 22:41:19.510487+00:00'
---

# 20260611-borg-registry-state-source

## decision

cmd_next and _borg_print_briefing must read from borg_registry_with_state, not the raw registry.

## context

Post-v0.8.0, the raw registry is vestigial and does not reflect live agent state. Both commands were reading stale data, causing incorrect capacity and next-agent calculations.

## reasoning

borg_registry_with_state is the authoritative live view. The raw registry remains for backward-compatibility scaffolding only and should not be used for runtime decisions.
