---
id: 20260611-registry-pure-discovery-index
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- borg-collective
- registry
- state-management
- json
- per-project
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.484564+00:00'
updated_at: '2026-06-11 22:41:19.484565+00:00'
---

# 20260611-registry-pure-discovery-index

## decision

Move volatile per-project state fields (status, last_activity, claude_session_id, has_uncommitted_changes, waiting_reason, notify_origin) out of the central ~/.config/borg/registry.json into per-project <project>/.borg/state.json files. Registry becomes a pure discovery index.

## context

registry.json was serving dual purposes: project discovery/metadata AND runtime volatile state. This caused contention and made the registry a mutable hotspot across concurrent hook executions.

## reasoning

Co-locating volatile state with the project it describes eliminates cross-project write contention, makes project state portable with the repo checkout, and allows the registry to be a stable, rarely-written index. Atomic tmp+mv writes to per-project state.json prevent corruption during concurrent hook fires.
