---
id: obs-20260709-launchd-minimal-path
session_date: '2026-07-09'
project: borg-collective
tool: claude-code
tags:
- launchd
- PATH
- macOS
- shell-scripting
- daemon
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260709-0431-orchestrator
superseded_by: null
created_at: '2026-07-09 15:26:37.441635+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260709-launchd-minimal-path

## content

launchd on macOS provides a minimal PATH (/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin or similar) that does NOT include $HOME/.local/bin. The native Claude Code installer places the `claude` binary at $HOME/.local/bin/claude. A poller script that calls `claude` by name will work correctly from any login shell (which inherits the user's PATH) and will silently fail under launchd, exiting 0 if error handling is suppressive.

## resolution

Prepend $HOME/.local/bin (and any other user-local bin dirs the script depends on) to PATH at the top of the script, not in the plist, so the fix applies to all invocation contexts.
