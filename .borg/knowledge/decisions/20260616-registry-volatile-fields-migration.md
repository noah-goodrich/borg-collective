---
id: 20260616-registry-volatile-fields-migration
date: '2026-06-16'
project: borg-collective
domain: architecture
tags:
- registry
- state-management
- per-project
- json
- directive-b
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.447604+00:00'
updated_at: '2026-06-16 10:27:02.447605+00:00'
---

# 20260616-registry-volatile-fields-migration

## decision

Move volatile per-session fields (status, last_activity, claude_session_id, has_uncommitted_changes, waiting_reason, notify_origin) from the global ~/.config/borg/registry.json into per-project <project>/.borg/state.json files. Registry becomes a pure discovery index.

## context

registry.json was serving dual purposes: project discovery index AND runtime state store. This caused coupling and made concurrent multi-project state updates potentially unsafe.

## reasoning

Per-project state files are naturally scoped to the project, enable atomic writes without contending on a single global file, and align with the principle that volatile runtime data belongs near its subject. The registry retains its value as a global index without being polluted by ephemeral session data.
