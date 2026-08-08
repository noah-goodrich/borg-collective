---
id: 20260611-sessionstart-linkdown-sessionstop-linkup
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- lifecycle
- hooks
- session-management
- naming-semantics
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.333943+00:00'
updated_at: '2026-06-11 22:41:19.333943+00:00'
---

# 20260611-sessionstart-linkdown-sessionstop-linkup

## decision

SessionStart fires borg-link-down.sh (pulls context down into the session); SessionStop fires borg-link-up.sh (pushes results up to persistent storage).

## context

Prior naming had the semantics inverted — link-up was wired to start and link-down to stop — which confused contributors reading the hook table.

## reasoning

The mnemonic now matches the data-flow direction: 'down' = receiving/loading, 'up' = saving/publishing. This matches common VCS and sync tool conventions (pull down, push up).
