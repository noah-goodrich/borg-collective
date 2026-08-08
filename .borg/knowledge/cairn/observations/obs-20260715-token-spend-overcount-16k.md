---
id: obs-20260715-token-spend-overcount-16k
session_date: '2026-07-15'
project: cairn
tool: claude-code
tags:
- token-spend
- analytics
- cost-tracking
- deduplication
- postgres
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-15 15:41:50.300111+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260715-token-spend-overcount-16k

## content

/stats/usage was reporting a total of $62,778.89. The correct figure after deduplicating cumulative per-session snapshots is $46,091.79 — a $16,686 (~27%) overcount. The bug: token_spend rows are cumulative snapshots within a session, and the stats query was summing all rows rather than taking the peak per session.

## resolution

PR #35: query now takes MAX(spend) per session_id before summing across sessions. Historical data corrected without schema changes.
