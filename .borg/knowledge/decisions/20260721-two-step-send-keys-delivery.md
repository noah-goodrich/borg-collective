---
id: 20260721-two-step-send-keys-delivery
date: '2026-07-21'
project: borg-collective
domain: architecture
tags:
- tmux
- send-keys
- bash
- borg-link-up
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: null
created_at: '2026-07-21 22:16:47.843258+00:00'
updated_at: '2026-07-21 22:16:47.843259+00:00'
---

# 20260721-two-step-send-keys-delivery

## decision

Deliver /borg-link-up to panes as two separate send-keys calls: one for the text, one for Enter — rather than a single call with newline embedded

## context

Needed reliable command delivery to tmux panes without relying on shell interpretation of embedded newlines or escape sequences

## reasoning

Separating the text send and the Enter send is the idiomatic tmux pattern; it avoids shell quoting issues with embedded newlines and makes the two-step intent explicit and testable independently
