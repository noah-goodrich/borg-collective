---
id: container-host-notification-bridge
project: borg-collective
domain: infrastructure
tags:
- devcontainer
- macos
- fswatch
- launchd
- notifications
- docker
preconditions: []
steps:
- Container process writes state to a file on a shared volume (e.g. a Docker bind
  mount accessible on the host).
- A host-side LaunchAgent daemon watches that file/directory with fswatch.
- On detecting a relevant state transition, the daemon calls osascript or another
  host-native notification API.
- Add a /.dockerenv guard to any in-container notification script so it exits silently
  rather than attempting and failing to fire a popup.
- On daemon startup, snapshot current state so pre-existing states don't trigger spurious
  notifications on restart.
- Prune state entries for projects whose directories no longer exist to avoid stale
  watches.
pitfalls:
- Without the /.dockerenv guard, both the host daemon AND the in-container script
  can fire, causing double notifications.
- Without a startup snapshot, every daemon restart fires popups for all currently-waiting
  projects.
- Homebrew's PATH may not be set in the LaunchAgent environment — explicitly source
  /opt/homebrew/bin or add it to the plist's EnvironmentVariables.
- End-to-end double-fire testing requires a real Claude session turn to end; cannot
  be verified synthetically.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.114113+00:00'
updated_at: '2026-06-11 20:39:25.114114+00:00'
---

# container-host-notification-bridge

## description

Pattern for firing host-native notifications (osascript/AppleScript) from events that originate inside a Docker devcontainer, where osascript is unavailable.
