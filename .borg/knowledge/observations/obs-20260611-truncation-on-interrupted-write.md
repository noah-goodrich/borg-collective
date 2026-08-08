---
id: obs-20260611-truncation-on-interrupted-write
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- zsh
- file-write
- atomic
- CLAUDE.md
- borg.zsh
category: error_encountered
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.304609+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-truncation-on-interrupted-write

## content

Direct shell file writes (echo/printf with redirection) can leave a truncated file if the process is interrupted (Ctrl-C, timeout, shell crash) between the open-for-write (which truncates immediately) and the completion of writing. CLAUDE.md was found empty/truncated after interrupted borg setups.

## resolution

Switched _borg_merge_claude_md to write to a temp file first, then mv to the final destination. mv is atomic on the same filesystem, so the destination is either the previous complete content or the new complete content — never a partial write.
