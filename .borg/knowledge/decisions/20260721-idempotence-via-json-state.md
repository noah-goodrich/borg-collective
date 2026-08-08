---
id: 20260721-idempotence-via-json-state
date: '2026-07-21'
project: borg-collective
domain: architecture
tags:
- usage-guardian
- idempotence
- state-management
- json
- bash
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: null
created_at: '2026-07-21 22:16:47.844348+00:00'
updated_at: '2026-07-21 22:16:47.844348+00:00'
---

# 20260721-idempotence-via-json-state

## decision

Track per-sweep idempotence in ~/.config/borg/usage-guardian.json via _guardian_get/_guardian_set_swept rather than in-memory state or a lock file

## context

The watch loop runs on a cron-like cadence; without idempotence a pane would receive /borg-link-up on every tick once threshold is crossed

## reasoning

JSON file survives process restarts, is human-inspectable for debugging, and is consistent with the existing guardian state location. Per-pane keys in the JSON allow fine-grained tracking.
