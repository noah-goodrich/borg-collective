---
id: obs-20260420-container-notifications-silently-fail
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- notifications
- docker
- terminal-notifier
- devcontainer
- borg
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.192342+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260420-container-notifications-silently-fail

## content

notify.sh inside a devcontainer calls terminal-notifier, which is a macOS-native binary not present in Linux containers. The failure is swallowed by `|| true`, so the script exits 0 and no popup reaches the user. Container-based Claude sessions can be waiting for input indefinitely with no visible signal.

## resolution

Make notify.sh a no-op when `/.dockerenv` is present. Implement a host-side registry.json watcher (fswatch + launchd or background zsh loop) that fires terminal-notifier on the host when it detects a status→waiting transition. Host-only sessions (orchestrator) are unaffected.
