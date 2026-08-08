---
id: tmux-capture-pane-fallback-for-large-logs
project: borg-collective
domain: debugging
tags:
- tmux
- scrollback
- debugging
- explore-agent
- jsonl
preconditions: []
steps:
- Attempt to read log file via Explore agent (read-only mode)
- If agent hits JSONL file-size limit and truncates, identify the tmux window/pane
  holding the relevant session (e.g., Cortex pane at 2.1)
- Run `tmux capture-pane -p -t <window>.<pane> -S -<line_count>` (e.g., -S -8000 for
  ~8000 lines of scrollback)
- Pipe or redirect output for analysis
pitfalls:
- tmux scrollback buffer has a finite size set in tmux.conf; very old output may be
  lost
- Pane index must be correct — verify with `tmux list-panes -t <window>` before capturing
- Captured output is raw terminal text including escape sequences; may need filtering
  for structured parsing
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.239375+00:00'
updated_at: '2026-06-16 10:27:02.239376+00:00'
---

# tmux-capture-pane-fallback-for-large-logs

## description

When an Explore/read agent hits JSONL file-size limits reading large log files, fall back to capturing tmux pane scrollback directly to get the relevant content
