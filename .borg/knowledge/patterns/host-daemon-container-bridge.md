---
id: host-daemon-container-bridge
project: borg-collective
domain: infrastructure
tags:
- devcontainer
- macos
- fswatch
- launchd
- notifications
- state-file
preconditions: []
steps:
- Container writes state to a well-known file path on a shared volume (e.g., ~/.borg/projects/<name>/status)
- Container-side hook guards execution with '[ -f /.dockerenv ] && return 0' to skip
  host-only code
- Host daemon (borg-notifyd) uses fswatch to watch the shared state directory for
  write events
- Daemon maintains a per-project state snapshot on startup (silent snapshot) to suppress
  spurious fires on daemon start
- On state change detected, daemon reads new state and fires the host-side action
  (e.g., terminal-notifier popup)
- Daemon prunes state entries for projects whose state files have been deleted
- LaunchAgent plist ensures daemon starts at login and restarts on crash
- install.sh performs sed substitution of HOME path into plist, then launchctl bootstrap
  to register
pitfalls:
- Homebrew PATH is not available in launchd environment by default — daemon must source
  Homebrew PATH explicitly or use full paths to fswatch/terminal-notifier
- Without a silent startup snapshot, daemon fires a notification for every project's
  current state on first launch
- If the plist KeepAlive is not set, a crash silently kills notifications until next
  login
- fswatch may deliver duplicate events for a single write; daemon must deduplicate
  by comparing previous and new state values
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.302952+00:00'
updated_at: '2026-06-11 22:41:19.302953+00:00'
---

# host-daemon-container-bridge

## description

Pattern for bridging container events to host-only capabilities (e.g., macOS notifications) via shared state files and a host fswatch daemon
