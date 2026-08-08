---
id: obs-20260616-pane-index-fragility
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- tmux
- drone
- pane-index
- fragile-selectors
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.420191+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-pane-index-fragility

## content

drone.zsh was using pane index arithmetic to identify which pane to focus/send commands to after a split. Pane indices in tmux are not stable — they renumber when any pane in the window is closed, causing commands to target the wrong pane silently.

## resolution

Replaced index-based selection with get_left_pane() helper that sorts panes by pane_left coordinate. Positional sort is stable across pane lifecycle events.
