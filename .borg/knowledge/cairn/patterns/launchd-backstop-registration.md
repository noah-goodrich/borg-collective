---
id: launchd-backstop-registration
project: cairn
domain: infrastructure
tags:
- launchd
- macos
- plist
- backstop
- automation
preconditions: []
steps:
- Place plist at ~/Library/LaunchAgents/<reverse-domain>.plist with StartCalendarInterval
  key for desired fire time
- Run `launchctl load ~/Library/LaunchAgents/<plist-name>.plist` to register without
  reboot
- 'Verify registration: `launchctl list | grep <label>` — confirm label appears and
  last exit is 0'
- Test by temporarily setting StartCalendarInterval to 1 minute out, then restoring
- After first natural fire, check the designated log path to confirm idempotent runner
  completed cleanly
pitfalls:
- launchctl load is session-scoped to the current user login; must re-run after reboot
  if plist is not in persistent LaunchAgents path
- A last exit of non-zero silently suppresses future runs on some macOS versions —
  always check exit code after first fire
- '`launchctl load` on an already-loaded plist errors; use `bootout` + `bootstrap`
  or `enable`/`disable` on newer macOS'
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260618-0029-cairn
superseded_by: null
created_at: '2026-06-18 00:30:17.387071+00:00'
updated_at: '2026-06-18 00:30:17.387072+00:00'
---

# launchd-backstop-registration

## description

Registering a launchd agent as a nightly backstop for a hook-based pipeline
