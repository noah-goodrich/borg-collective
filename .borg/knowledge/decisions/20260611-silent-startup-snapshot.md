---
id: 20260611-silent-startup-snapshot
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- notifications
- fswatch
- daemon
- startup
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.098240+00:00'
updated_at: '2026-06-11 20:39:25.098240+00:00'
---

# 20260611-silent-startup-snapshot

## decision

borg-notifyd takes a silent startup snapshot of current state rather than treating all existing state files as new transitions

## context

Without a snapshot, every daemon restart (e.g., after reboot) would fire popups for all currently-waiting projects, producing spurious noise

## reasoning

The daemon should only notify about transitions that happen while it is running. Pre-existing state is baseline, not an event.
