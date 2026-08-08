---
id: obs-20260611-homebrew-path-launchd
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
created_at: '2026-06-11 22:41:19.303633+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-homebrew-path-launchd

## content

LaunchAgents do not inherit the user's shell PATH. Homebrew-installed binaries (fswatch, terminal-notifier) are not on the default launchd PATH (/usr/bin:/bin:/usr/sbin:/sbin). A daemon script that works fine when run in terminal silently fails under launchd because it cannot find its tools.

## resolution

Explicitly prepend Homebrew paths in the daemon script: export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH" at the top of the script, before any Homebrew binary is called.
