---
id: 20260611-dockerenv-guard-in-hooks
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- devcontainer
- hooks
- guard
- notifications
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
created_at: '2026-06-11 20:39:25.098678+00:00'
updated_at: '2026-06-11 20:39:25.098678+00:00'
---

# 20260611-dockerenv-guard-in-hooks

## decision

Add /.dockerenv guard to hooks/notify.sh and skip CLAUDE.md sync/extensions in hooks/borg-start.sh when running inside a container

## context

Hooks run in both host and container contexts; without guards, notify.sh would silently fail (no osascript) and borg-start.sh was polluting host CLAUDE.md with /home/dev/... paths

## reasoning

Cheapest reliable container detection is /.dockerenv existence check. Silent exit in notify.sh prevents errors; skipping CLAUDE.md sync prevents cross-environment path contamination.
