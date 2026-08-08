---
id: 20260423-silent-startup-snapshot
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- launchd
- daemon
- fswatch
- notifications
- idempotency
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.112597+00:00'
updated_at: '2026-06-11 20:39:25.112597+00:00'
---

# 20260423-silent-startup-snapshot

## decision

borg-notifyd takes a baseline state snapshot on daemon launch and suppresses popups for any projects already in 'waiting' state at startup.

## context

Without a baseline, every daemon restart (e.g. after reboot or launchctl unload/load) would fire spurious popups for all projects currently in 'waiting' state.

## reasoning

Popups that fire on daemon restart rather than on actual state transitions are noise and would erode trust in the notification signal. The snapshot costs nothing and eliminates the false-positive class entirely.
