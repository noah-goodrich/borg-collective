---
id: obs-20260611-registry-with-state-merge-pattern
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- borg-collective
- registry
- state-management
- zsh
- api-design
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.487529+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-registry-with-state-merge-pattern

## content

The planned migration requires borg.zsh consumers (cmd_ls, cmd_next, cmd_status, cmd_hail, cmd_link) to switch from borg_registry_read to a new borg_registry_with_state function that merges the per-project state.json data into the registry JSON at read time. This keeps the call sites simple while hiding the two-source data model behind a single function.

## resolution

Implement borg_registry_with_state in lib/registry.zsh as the canonical read path for any consumer that needs volatile fields. Reserve borg_registry_read for write/admin operations that only touch discovery metadata. Document this distinction explicitly in the function headers.
