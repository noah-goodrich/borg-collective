---
id: obs-20260418-drone-color-bold-insufficient
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- tmux
- drone
- terminal-ui
- color-theming
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.267370+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260418-drone-color-bold-insufficient

## content

Using `fg=$color,bold` as the sole active-window differentiator in a per-project-colored tmux status bar produces low contrast on a subset of project colors. The active window is easy to misread as inactive. This is a latent UI bug that only manifests on certain hue assignments.

## resolution

Fixed by switching to `fg=colour0,bg=colour255,bold` (inverted). Any tmux theme that relies on bold-only for active-window distinction should be audited for similar contrast failures.
