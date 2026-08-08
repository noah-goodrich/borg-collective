---
id: 20260418-drone-active-window-invert
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- tmux
- drone
- zsh
- terminal-ui
- color
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.043772+00:00'
updated_at: '2026-06-11 20:39:25.043773+00:00'
---

# 20260418-drone-active-window-invert

## decision

Use fg=colour0,bg=colour255,bold for active tmux window style instead of fg=$color,bold

## context

drone.zsh assigns a per-project hue to tmux windows; the active window was previously styled with that same project color + bold, making it hard to distinguish from inactive windows at a glance

## reasoning

Inverted black-on-white is unambiguous regardless of which project color is in use. A color+bold active style blends into the inactive window row on certain hues.
