---
id: obs-20260611-truncated-write-on-interrupt
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- borg.zsh
- atomic-write
- claude-md
- setup
- truncation
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.100824+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-truncated-write-on-interrupt

## content

Direct shell redirection (> file) truncates the file immediately on open, before any content is written. An interrupt (Ctrl-C, signal, or error) during the write leaves a zero-byte or partial file with no indication of failure. For CLAUDE.md this caused downstream tools to silently operate on an empty config.

## resolution

Switched to atomic write: write to a temp file in the same directory, then mv to final destination. mv is atomic on same-filesystem operations. Released as v0.7.4.
