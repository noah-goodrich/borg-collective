---
id: tmux-scrollback-fallback-for-large-files
project: borg-collective
domain: debugging
tags:
- tmux
- scrollback
- explore-agent
- jsonl
- file-size
preconditions: []
steps:
- Attempt Explore agent read of session log file
- If agent hits JSONL file-size limit, identify the target tmux window and pane (e.g.,
  `2.1` for window 2, pane 1)
- Run `tmux capture-pane -p -t <window>.<pane> -S -<lines>` with sufficient line depth
  (e.g., -8000)
- Pipe or redirect output for analysis
- Embed relevant excerpts directly in the directive or document being written
pitfalls:
- Scrollback buffer has a finite size set in tmux config; very old events may be gone
- Pane index must be correct — wrong pane silently returns different content
- Scrollback is volatile; capture before the session ends or the pane is cleared
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.356356+00:00'
updated_at: '2026-06-11 22:41:19.356356+00:00'
---

# tmux-scrollback-fallback-for-large-files

## description

When an Explore agent hits JSONL file-size limits reading session logs in read-only mode, fall back to capturing the live tmux pane scrollback directly to extract the needed evidence
