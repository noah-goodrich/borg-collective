---
id: obs-20260423-atomic-write-prevents-truncation
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- shell
- zsh
- file-write
- race-condition
- claude-md
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.115754+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260423-atomic-write-prevents-truncation

## content

_borg_merge_claude_md was writing directly to the target file, which caused truncation if the process was interrupted mid-write (e.g. during setup on a slow machine or with a timing race). This corrupted CLAUDE.md on the work machine.

## resolution

Write to a temp file first, then mv (atomic rename) to the destination. On the same filesystem, mv is atomic at the OS level and the destination is never in a partial state.
