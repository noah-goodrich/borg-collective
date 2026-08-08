---
id: obs-20260611-transcript-path-previously-ignored
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- hooks
- cairn
- transcript
- claude
- hook-input
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.503230+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-transcript-path-previously-ignored

## content

The SessionStop hook input JSON includes a transcript_path field pointing to the full session transcript, but borg-link-up.sh was not parsing or using it. This field enables post-session enrichment without any additional API calls.

## resolution

Parse transcript_path from hook input in SessionStop handlers. It enables extracting last assistant message, conversation length, tool use counts, etc. Guard for empty path and missing file before use.
