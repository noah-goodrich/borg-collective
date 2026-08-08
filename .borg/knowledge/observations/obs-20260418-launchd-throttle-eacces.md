---
id: obs-20260418-launchd-throttle-eacces
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- launchd
- ssh-agent
- macos
- throttling
- SIP
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.175361+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260418-launchd-throttle-eacces

## content

When a launchd-managed process exits with a non-zero code (here: 255 from EACCES) repeatedly, launchd enters a throttled backoff state and stops respawning the process. On modern macOS with SIP enabled, `launchctl kickstart` is blocked for user agents, so there is no direct way to force an immediate restart. The agent stays dead even after the underlying permission issue is fixed.

## resolution

Kill all related processes manually (pkill -f ssh-agent; pkill -f ssh-add) to clear launchd's failure count, fix the root cause, then wait for launchd to respawn on next trigger or reboot.
