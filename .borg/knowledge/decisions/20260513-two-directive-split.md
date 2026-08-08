---
id: 20260513-two-directive-split
date: '2026-06-16'
project: borg-collective
domain: architecture
tags:
- orchestrator-mode
- session-separation
- migration
- planning
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.376421+00:00'
updated_at: '2026-06-16 10:27:02.376422+00:00'
---

# 20260513-two-directive-split

## decision

Split orchestrator/project session separation into two directives: A (hook behavior + env var rename, ship immediately) and B (per-project state migration out of registry, stub and block on A being live)

## context

Full solution required both behavioral changes (hooks, env vars) and a data migration (moving state fields out of the shared registry into per-project stores). Attempting both simultaneously risked shipping a broken intermediate state.

## reasoning

Directive A has no data migration risk and can ship and be verified independently. Directive B depends on A being active (post-borg-setup) to know the new session classification is reliable before migrating data that depends on it. Stubbing B with the full plan preserved context without blocking A's delivery.
