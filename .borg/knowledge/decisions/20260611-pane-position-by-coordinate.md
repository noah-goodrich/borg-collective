---
id: 20260611-pane-position-by-coordinate
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- tmux
- drone
- pane-management
- zsh
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.459327+00:00'
updated_at: '2026-06-11 22:41:19.459327+00:00'
---

# 20260611-pane-position-by-coordinate

## decision

Use a get_left_pane() helper that sorts panes by pane_left ascending rather than relying on pane creation order or get_bottom_pane()

## context

Claude pane was appearing on the right instead of left after drone up; existing get_bottom_pane() was not reliable for horizontal split orientation detection

## reasoning

Sorting by the pane_left coordinate is a stable, layout-independent way to identify the leftmost pane regardless of creation order or tmux version behavior
