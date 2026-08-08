---
id: 20260611-borg-reaper-idle-criteria
date: '2026-06-11'
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
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.510054+00:00'
updated_at: '2026-06-11 22:41:19.510054+00:00'
---

# 20260611-borg-reaper-idle-criteria

## decision

Define 'idle/stale' as: no live tmux window AND last_activity older than BORG_REAP_STALE_HOURS (default 12). Both conditions required.

## context

The reaper was incorrectly treating active/waiting agents as idle, causing capacity miscounts. Needed a durable definition that wouldn't false-positive on legitimately running agents.

## reasoning

Requiring both conditions prevents reaping agents that have a live tmux window (still running) or that recently touched last_activity (recently active but window may have closed transiently). Single-condition checks were too aggressive.
