---
id: 20260611-link-up-down-semantic-correction
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- lifecycle
- hooks
- session-management
- naming
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.159101+00:00'
updated_at: '2026-06-11 20:39:25.159102+00:00'
---

# 20260611-link-up-down-semantic-correction

## decision

SessionStart hook is borg-link-down.sh (connecting to the borg), SessionStop hook is borg-link-up.sh (disconnecting/surfacing from the borg); skills named to match

## context

Prior naming had the semantics inverted — 'link-up' was firing at session start and 'link-down' at stop, which was backwards relative to the metaphor (linking down into the collective on entry, linking back up/out on exit)

## reasoning

Correct metaphor alignment: you 'link down' into the hive on session start, you 'link up' (surface) on session end. Makes the hook names self-documenting and reduces cognitive load for future contributors
