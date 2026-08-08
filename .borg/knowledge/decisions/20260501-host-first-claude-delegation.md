---
id: 20260501-host-first-claude-delegation
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- claude
- tmux
- drone
- container
- session-management
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.354789+00:00'
updated_at: '2026-06-11 22:41:19.354790+00:00'
---

# 20260501-host-first-claude-delegation

## decision

Move Claude process to host machine; container becomes a dispatch target invoked via `drone exec` rather than the session host

## context

Current architecture spawns Claude inside the container, which creates friction when Claude needs to coordinate across projects or when container lifecycle doesn't match Claude session lifecycle

## reasoning

Host-first placement gives Claude stable filesystem access, cross-project visibility, and decouples AI session lifetime from container state. Container remains the execution environment for project commands but not the thinking environment.
