---
id: obs-20260611-merge-twin-jq-blocks
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- shell
- jq
- refactoring
- simplify
category: pattern_discovered
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.336439+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-merge-twin-jq-blocks

## content

The /simplify pass found two structurally identical `has_uncommitted_changes` jq blocks inside borg-link-up.sh that had been created by the content swap and were functionally redundant. Twin blocks like this are a reliable signal that a helper function or variable capture is missing.

## resolution

Merged into a single block. The pattern to watch for: any time a file-content swap produces two sections that perform the same logical operation on the same input, extract a named variable or function immediately rather than deferring.
