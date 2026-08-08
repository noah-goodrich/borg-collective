---
id: obs-20260423-launchagent-homebrew-path
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- launchd
- launchagent
- homebrew
- PATH
- macos
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.115380+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260423-launchagent-homebrew-path

## content

LaunchAgent daemons do not inherit the user's shell PATH. On Apple Silicon Macs, Homebrew installs to /opt/homebrew/bin, which is absent from the default LaunchAgent environment. Any daemon that calls Homebrew-managed binaries (fswatch, etc.) will fail silently or with 'command not found' unless the PATH is explicitly set.

## resolution

Either hardcode /opt/homebrew/bin in the plist's EnvironmentVariables key, or source it explicitly in the daemon script before invoking any Homebrew binaries.
