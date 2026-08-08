---
id: 20260616-tmux-default-sidebyside
date: '2026-06-16'
project: borg-collective
domain: infrastructure
tags:
- tmux
- drone
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
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.210468+00:00'
updated_at: '2026-06-16 10:27:02.210469+00:00'
---

# 20260616-tmux-default-sidebyside

## decision

drone.zsh create_2pane_window defaults to split-window -h -p 50 (side-by-side 50/50) with focus on the right (Claude) pane, replacing an implicit vertical split.

## context

Drone windows are used for human-watches-Claude workflows where the human needs to see Claude output alongside a terminal. Side-by-side is more natural for wide monitors and keeps both panes equally visible.

## reasoning

50/50 horizontal gives Claude a full-height pane which suits its output style. Focus on right pane means the operator doesn't need to manually navigate after window creation. Hotkeys = (even-horizontal) and _ (even-vertical) added for ad-hoc rebalancing.
