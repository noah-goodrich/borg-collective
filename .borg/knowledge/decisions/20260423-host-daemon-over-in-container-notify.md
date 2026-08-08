---
id: 20260423-host-daemon-over-in-container-notify
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- devcontainer
- macos
- osascript
- launchd
- fswatch
- notifications
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.112104+00:00'
updated_at: '2026-06-11 20:39:25.112104+00:00'
---

# 20260423-host-daemon-over-in-container-notify

## decision

Implement container→host notification bridge as a host-side LaunchAgent daemon (borg-notifyd) watching a shared state file via fswatch, rather than attempting osascript from inside the container.

## context

Devcontainer Claude sessions cannot call osascript due to macOS security restrictions — the binary is either absent or sandboxed in a way that prevents GUI interactions from within Docker.

## reasoning

The macOS security barrier is fundamental and cannot be worked around from inside a container. Watching a shared state file on the host sidesteps the problem entirely: the container writes state, the host reads it and fires the popup natively.
