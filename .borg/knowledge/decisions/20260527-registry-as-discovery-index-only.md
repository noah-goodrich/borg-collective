---
id: 20260527-registry-as-discovery-index-only
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- registry
- state-management
- separation-of-concerns
- shell
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.492498+00:00'
updated_at: '2026-06-11 22:41:19.492499+00:00'
---

# 20260527-registry-as-discovery-index-only

## decision

Migrate volatile session state (claude_session_id, last_activity, status) out of the shared registry into per-project .borg/state.json files. Registry becomes a pure discovery index.

## context

The shared registry was serving dual purposes: project discovery and runtime state tracking. This created coupling and made the registry a write-heavy shared resource during normal hook activity.

## reasoning

Separating concerns makes the registry stable and read-heavy (discovery only) while state.json files are local to each project and can be written atomically without contending with the registry. This also makes it trivial to inspect or reset state for a single project without touching the shared index.
