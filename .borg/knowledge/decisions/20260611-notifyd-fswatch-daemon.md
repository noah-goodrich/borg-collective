---
id: 20260611-notifyd-fswatch-daemon
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- notifications
- launchd
- fswatch
- devcontainer
- macos
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.097792+00:00'
updated_at: '2026-06-11 20:39:25.097793+00:00'
---

# 20260611-notifyd-fswatch-daemon

## decision

Implement notification bridge as a host-side fswatch daemon (borg-notifyd) rather than having containers call into the host directly

## context

Devcontainer Claude sessions cannot fire macOS popups natively; needed a way to surface waiting-state transitions to the host user

## reasoning

Containers have no reliable path to host notification APIs. A host daemon watching shared state files via fswatch is a clean separation: containers write state, host reads and acts. Avoids any container→host exec complexity or privilege escalation.
