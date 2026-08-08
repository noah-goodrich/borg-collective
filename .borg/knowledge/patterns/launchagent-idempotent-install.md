---
id: launchagent-idempotent-install
project: borg-collective
domain: infrastructure
tags:
- launchd
- macos
- install
- idempotent
- daemon
preconditions: []
steps:
- Copy plist to ~/Library/LaunchAgents/ (cp -f is safe to re-run).
- Attempt 'launchctl bootstrap gui/$(id -u) <plist>' or 'launchctl load'; catch already-loaded
  error (exit code 37 or 'service already loaded' stderr) and treat as success.
- Verify with 'launchctl list | grep <label>' returning exactly one line.
- 'For updates: launchctl bootout first, then bootstrap again.'
pitfalls:
- launchctl load (legacy) vs launchctl bootstrap (modern) behave differently on different
  macOS versions — prefer bootstrap for 10.15+.
- Running install.sh twice without handling the already-loaded case will error out
  and may leave a broken agent state.
- StandardOutPath/StandardErrorPath directories must exist before launchd tries to
  write them — create ~/Library/Logs/ in the install script if not present.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.083183+00:00'
updated_at: '2026-06-11 20:39:25.083184+00:00'
---

# launchagent-idempotent-install

## description

Idempotent LaunchAgent install pattern for macOS daemons shipped with a project.
