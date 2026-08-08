---
id: 20260616-borg-next-registry-source
date: '2026-06-16'
project: borg-collective
domain: architecture
tags:
- borg
- registry
- state
- v0.8.0
- technical-debt
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.490458+00:00'
updated_at: '2026-06-16 10:27:02.490459+00:00'
---

# 20260616-borg-next-registry-source

## decision

cmd_next and _borg_print_briefing must read borg_registry_with_state, not the raw registry

## context

Post-v0.8.0 the raw registry is a vestigial artifact; state (active/waiting/idle) is only present in the state-enriched registry. Both functions were reading the wrong source, making capacity and next-agent logic silently incorrect.

## reasoning

The state-enriched registry is the single source of truth for runtime agent state. Reading the raw registry returns stale or absent state fields, causing next/capacity to behave as if all agents are idle.
