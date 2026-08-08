---
id: obs-20260501-cortex-cap-resume-stateless
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- cortex
- context-cap
- session-management
- tmux
- wake
category: tool_behavior
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.240998+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260501-cortex-cap-resume-stateless

## content

Claude Code context cap (cap message) followed by manual `wake up!` resumes mid-task with no observable state loss. Three cap-hit/resume cycles were confirmed across ~8000 lines of Cortex scrollback. The cap message is a stable, detectable signal in the pane output.

## resolution

This confirms that the cortex-auto-wake daemon design is sound: detect cap message, wait for reset window, auto-send `wake up!` via tmux. The resume behavior is reliable enough to automate.
