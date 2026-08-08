---
id: obs-20260709-live-hits-zero-suspect
session_date: '2026-07-09'
project: cairn
tool: claude-code
tags:
- usage-tracking
- hit-count
- call_log
- http
- debugging
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260709-1535-cairn
superseded_by: null
created_at: '2026-07-09 15:36:29.699716+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260709-live-hits-zero-suspect

## content

231 queries were logged in call_log after the service restart, but all showed hits=0. Unit tests for hit recording pass in-process, suggesting the bug is in the HTTP path's wiring (/search → search_formatted → search), not the recording logic itself. Borg hooks were also hammering the service during the crash-loop, so some zero-hit rows may be legitimate misses, but the pattern warrants verification.

## resolution

Not yet resolved. Next session: run a known-hit search (curl /search?q=pgvector&project=cairn) and check the resulting call_log row for hit_count > 0. If still 0, trace the HTTP handler → service → usage.log_call chain for where hit_count is computed vs. where it's passed to the logger.
