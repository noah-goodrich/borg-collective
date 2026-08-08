---
id: obs-20260611-tmux-pane-left-sort
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- tmux
- drone
- pane-layout
- zsh
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.461497+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-tmux-pane-left-sort

## content

tmux pane helpers that rely on creation order (first pane = left pane) or bottom/top axis for horizontal splits are unreliable. The pane_left format variable gives the actual pixel/column offset and sorting ascending on it reliably identifies the leftmost pane.

## resolution

Introduced get_left_pane() that runs: tmux list-panes -F '#{pane_left} #{pane_id}' | sort -n | head -1 | awk '{print $2}'. Applied to cmd_claude, cmd_cortex, cmd_feature.
