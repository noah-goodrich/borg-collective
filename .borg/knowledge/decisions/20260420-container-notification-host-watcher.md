---
id: 20260420-container-notification-host-watcher
date: '2026-06-16'
project: borg-collective
domain: architecture
tags:
- notifications
- docker
- terminal-notifier
- fswatch
- launchd
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.188645+00:00'
updated_at: '2026-06-16 10:27:02.188646+00:00'
---

# 20260420-container-notification-host-watcher

## decision

Fix container notification blackhole via a host-side watcher on registry.json (fswatch + launchd or background zsh loop) that fires terminal-notifier on status→waiting transitions; make container notify.sh a no-op when /.dockerenv is present.

## context

Container sessions can't fire macOS notifications because terminal-notifier is host-only. notify.sh runs inside the container, fails silently at binary lookup, and no popup reaches the user.

## reasoning

The registry.json is written by the container and visible on the host via volume mount. Watching it on the host decouples the notification trigger from the execution environment. Making notify.sh a no-op inside containers prevents misleading 'success' returns.
