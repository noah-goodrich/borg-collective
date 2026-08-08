---
id: 20260616-borg-reaper-idle-definition
date: '2026-06-16'
project: borg-collective
domain: architecture
tags:
- borg
- reaper
- tmux
- session-tracking
- capacity
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.489959+00:00'
updated_at: '2026-06-16 10:27:02.489959+00:00'
---

# 20260616-borg-reaper-idle-definition

## decision

Define 'idle' for reaper as: no live tmux window AND last_activity older than BORG_REAP_STALE_HOURS (default 12h)

## context

Reaper was incorrectly treating active/waiting agents as idle, causing premature capacity reclamation and broken borg next behavior

## reasoning

Both conditions must be true to avoid false positives — a missing tmux window alone could be transient, and a stale timestamp alone could belong to a legitimately backgrounded agent. The conjunction is conservative (fail-safe) and matches actual human intent.
