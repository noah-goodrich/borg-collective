---
id: obs-20260418-drone-color-bold-readability
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- tmux
- drone
- zsh
- color
- terminal-ui
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.045525+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260418-drone-color-bold-readability

## content

In drone.zsh, styling the active tmux window with only the project color + bold is insufficient for visual distinction. On mid-range or saturated hues the bold variant of the same color reads as 'slightly brighter' rather than 'selected', making the active window ambiguous at a glance.

## resolution

Fixed at line 140: changed active window style to fg=colour0,bg=colour255,bold (black text on white background), which is project-color-agnostic and always visually distinct.
