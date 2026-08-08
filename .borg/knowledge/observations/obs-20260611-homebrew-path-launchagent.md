---
id: obs-20260611-homebrew-path-launchagent
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- launchd
- homebrew
- PATH
- macos
- fswatch
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.101241+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-homebrew-path-launchagent

## content

LaunchAgents on macOS do not inherit the user's shell PATH. Homebrew-installed binaries (e.g., fswatch at /opt/homebrew/bin/fswatch) are not on the default launchd PATH, causing the daemon to silently fail or error with 'command not found' even though fswatch works fine in an interactive shell.

## resolution

borg-notifyd explicitly prepends /opt/homebrew/bin:/usr/local/bin to PATH at the top of the script before invoking fswatch.
