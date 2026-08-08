---
id: container-to-host-notification-bridge
project: borg-collective
domain: infrastructure
tags:
- devcontainer
- macos
- fswatch
- launchd
- notifications
- ipc
preconditions: []
steps:
- Container process writes state transitions to a file on a host-mounted volume (e.g.,
  a shared .borg/state file)
- Host daemon (zsh script) uses fswatch to watch the shared state file for changes
- On change, daemon reads new state, diffs against its in-memory baseline snapshot,
  and fires osascript notifications only for genuine new transitions
- Daemon takes a baseline snapshot at startup to suppress notifications for pre-existing
  state
- Daemon prunes state entries for deleted/stopped projects to avoid stale tracking
- LaunchAgent plist keeps the daemon running across reboots; install script handles
  symlink + launchctl bootstrap
- In-container notification scripts guard against running on the host by checking
  for /.dockerenv and exiting silently if present
pitfalls:
- Without the /.dockerenv guard in the container-side notify script, both the daemon
  AND the container script could fire — resulting in double notifications
- Without the startup snapshot, every daemon restart fires spurious popups for all
  currently-waiting projects
- Homebrew's PATH may not be set in the LaunchAgent environment — daemon script must
  explicitly source or hardcode the Homebrew bin path
- Deleted projects must be pruned from the daemon's state map or they accumulate as
  phantom entries across restarts
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.312732+00:00'
updated_at: '2026-06-11 22:41:19.312732+00:00'
---

# container-to-host-notification-bridge

## description

Pattern for enabling macOS desktop notifications from containerized processes that cannot access osascript, using a shared state file and a host-side fswatch daemon
