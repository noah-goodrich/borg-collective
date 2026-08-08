---
id: obs-20260501-host-first-ordering-constraint
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- claude
- drone
- hooks
- ordering
- migration
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.358036+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260501-host-first-ordering-constraint

## content

The `host-first-claude-delegation` change must be shipped before `directive-orphan-prevention` hook logic is added to `borg-link-down`/`borg-link-up`. If orphan-prevention hooks are added while Claude still runs in-container, the new hooks will conflict with in-container Claude assumptions during the transition window.

## resolution

Enforce shipping order: host-first delegation → orphan-prevention hooks. Document this dependency in both directives' Scope Boundaries sections.
