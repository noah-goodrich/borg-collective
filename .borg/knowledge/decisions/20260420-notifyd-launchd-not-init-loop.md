---
id: 20260420-notifyd-launchd-not-init-loop
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- launchd
- notifications
- container
- daemon
- macos
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.081761+00:00'
updated_at: '2026-06-11 20:39:25.081761+00:00'
---

# 20260420-notifyd-launchd-not-init-loop

## decision

Container-notification-bridge watcher lives in bin/borg-notifyd + a LaunchAgent plist, not as a background loop inside borg init.

## context

Need a process that survives shell restarts and watches registry.json for status transitions to 'waiting', firing macOS notifications.

## reasoning

launchd agents are independently manageable (start/stop/restart without touching borg shell functions), survive terminal quits, and get proper stdout/stderr logging to ~/Library/Logs. A borg init loop dies with the shell and is invisible to launchctl.
