---
id: obs-20260501-cortex-cap-no-state-loss
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- cortex
- claude
- context-cap
- tmux
- session-management
category: tool_behavior
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.358365+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260501-cortex-cap-no-state-loss

## content

Claude (Cortex) resuming after a context cap via `wake up!` tmux signal preserves mid-task state — the session continues where it left off with no observable state loss. Three cap-hits were confirmed across ~8000 lines of scrollback in a single long session, each followed by successful resume.

## resolution

Automate the wake signal via a daemon that detects the cap message pattern and schedules `tmux send-keys` at reset time, eliminating the human-in-the-loop requirement.
