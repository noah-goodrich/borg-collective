---
id: 20260423-2pane-horizontal-default
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- drone
- tmux
- layout
- ux
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.320942+00:00'
updated_at: '2026-06-11 22:41:19.320942+00:00'
---

# 20260423-2pane-horizontal-default

## decision

Change `create_2pane_window` default from vertical 75/25 split to horizontal 50/50 (`split-window -h -p 50`)

## context

The 75/25 vertical split (top/bottom) was the original default for drone tmux windows. Side-by-side (left editor / right Claude pane) was the preferred working layout but required manual adjustment after every `drone up`.

## reasoning

50/50 horizontal matches the actual working pattern. Renaming `bottom` pane to `right` makes pane references self-documenting. Focus lands on the right (Claude) pane by default, matching the intended workflow entry point.
