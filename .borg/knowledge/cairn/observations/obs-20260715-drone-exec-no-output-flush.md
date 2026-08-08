---
id: obs-20260715-drone-exec-no-output-flush
session_date: '2026-07-15'
project: cairn
tool: drone
tags:
- drone
- ci
- background-process
- logging
- debugging
category: tool_behavior
files_involved: []
confidence: 0.9
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-15 15:41:50.300989+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260715-drone-exec-no-output-flush

## content

Running `drone exec` in the background does NOT flush output to the terminal. Log lines are buffered and may never appear, making it impossible to monitor progress or debug failures when run as a background job.

## resolution

Always run drone commands in the foreground. If you need to free the terminal, use a multiplexer (tmux/screen) rather than backgrounding the process.
