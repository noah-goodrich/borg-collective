---
id: obs-20260501-explore-agent-jsonl-size-limit
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- explore-agent
- jsonl
- file-size
- read-only
- workaround
category: tool_behavior
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.357715+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260501-explore-agent-jsonl-size-limit

## content

The Explore agent hits a JSONL file-size limit when attempting to read large session log files in read-only mode, failing silently or with a size error rather than returning partial content.

## resolution

Fall back to `tmux capture-pane -p -t <window>.<pane> -S -<lines>` to capture live pane scrollback directly. 8000 lines was sufficient to recover ~3 cap-hit events across a long session.
