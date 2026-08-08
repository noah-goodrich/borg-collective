---
id: 20260428-borg-link-up-auto-record
date: '2026-06-11'
project: cairn
domain: infrastructure
tags:
- borg
- hooks
- session-recording
- automation
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1925-cairn
created_at: '2026-06-11 23:12:50.707221+00:00'
updated_at: '2026-06-11 23:12:50.707221+00:00'
---

# 20260428-borg-link-up-auto-record

## decision

borg-link-up.sh (Stop hook) calls `cairn record session` on every session exit, best-effort (non-blocking)

## context

The 4-week keep-or-kill validation window requires honest session data without relying on developers to manually record sessions

## reasoning

Stop hooks fire reliably on session end regardless of how the session ends. Best-effort (fire-and-forget) means a failing cairn service never blocks session teardown.
