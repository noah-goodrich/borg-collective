---
id: obs-20260630-fswatch-delivery-latency
session_date: '2026-06-30'
project: borg-collective
tool: claude-code
tags:
- vinculum
- fswatch
- latency
- tmux
category: performance
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260630-2202-borg-collective
superseded_by: null
created_at: '2026-06-30 22:03:12.820938+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260630-fswatch-delivery-latency

## content

The `fswatch` → `tmux send-keys` delivery path achieves approximately 0.9 seconds end-to-end latency for cross-pane message delivery on a local machine.

## resolution

Acceptable for cross-session coordination use cases. Not suitable for tight feedback loops requiring sub-100ms delivery. Document as a known characteristic of the file-based approach.
