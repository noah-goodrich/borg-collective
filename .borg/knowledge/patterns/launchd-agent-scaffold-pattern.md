---
id: launchd-agent-scaffold-pattern
project: borg-collective
domain: infrastructure
tags:
- launchd
- macos
- daemon
- install
preconditions: []
steps:
- Write daemon script to bin/<name> (zsh or bash; self-contained)
- Write plist to launchd/com.<org>.<name>.plist with RunAtLoad true, KeepAlive true,
  stdout/stderr paths under ~/Library/Logs/
- 'In install.sh: cp plist to ~/Library/LaunchAgents/; run launchctl bootstrap or
  launchctl load; guard the already-loaded case (check launchctl list before bootstrapping)'
- 'Verify idempotency: run install.sh twice, assert `launchctl list | grep -c <name>`
  == 1'
pitfalls:
- launchctl bootstrap and launchctl load have different semantics across macOS versions;
  test on target OS.
- If the plist changes, launchctl unload + load (or bootout + bootstrap) is required
  — a plain cp without reload leaves the old plist active.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.285895+00:00'
updated_at: '2026-06-11 22:41:19.285895+00:00'
---

# launchd-agent-scaffold-pattern

## description

Standard pattern for shipping a persistent macOS background watcher as a LaunchAgent with idempotent install.
