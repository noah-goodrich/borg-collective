---
id: 20260527-per-project-state-json
date: '2026-06-16'
project: borg-collective
domain: architecture
tags:
- borg-collective
- state-management
- registry
- shell
- json
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.455741+00:00'
updated_at: '2026-06-16 10:27:02.455741+00:00'
---

# 20260527-per-project-state-json

## decision

Migrate volatile session state (claude_session_id, last_activity, status) out of the shared registry into per-project .borg/state.json files, making the registry a pure discovery index.

## context

The shared registry was mixing two concerns: stable project discovery data and volatile per-session runtime state. This caused coupling and made the registry harder to reason about.

## reasoning

Separating concerns makes the registry stable and read-mostly (safe to cache/index), while volatile state is co-located with the project it describes. Atomic writes to per-project files also avoid registry-wide locking concerns.
