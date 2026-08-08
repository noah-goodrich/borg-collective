---
id: tmux-pane-position-by-sort
project: borg-collective
domain: infrastructure
tags:
- tmux
- zsh
- pane-layout
- drone
preconditions: []
steps:
- 'Use `tmux list-panes -F ''#{pane_left} #{pane_id}''` to get positional data'
- Sort ascending by the position field (pane_left for horizontal, pane_top for vertical)
- Take the first result to get the leftmost/topmost pane ID
- Encapsulate in a helper (e.g., get_left_pane(), get_bottom_pane()) for reuse across
  drone commands
pitfalls:
- Pane indices (#{pane_index}) shift when panes are killed or reordered; always prefer
  positional sort over index assumptions
- get_bottom_pane and get_left_pane are not interchangeable — verify which axis your
  split creates
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.419071+00:00'
updated_at: '2026-06-16 10:27:02.419072+00:00'
---

# tmux-pane-position-by-sort

## description

Reliably identify leftmost/bottommost pane in a tmux split by sorting on pane_left or pane_top rather than using index arithmetic
