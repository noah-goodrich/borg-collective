---
id: cairn-pg-dump-restrict-tokens-2026-06-10
session_date: '2026-06-10'
project: cairn
tool: claude-code
tags:
- postgres
- pg_dump
- schema
- drift-check
- tokens
category: gotcha
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260610-1630-cairn
superseded_by: null
created_at: '2026-06-10 16:50:37.422383+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# cairn-pg-dump-restrict-tokens-2026-06-10

## content

pg_dump emits \restrict and \unrestrict volatile tokens in its schema snapshot output. These are per-session random strings, not valid SQL. They cause schema drift-check comparisons to always fail with spurious diffs.

## resolution

Strip lines beginning with \restrict and \unrestrict from pg_dump output before storing the snapshot or running diff comparisons. Use: grep -v '^\\restrict' | grep -v '^\\unrestrict'
