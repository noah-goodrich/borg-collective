---
id: obs-20260612-backfill-input-gitignore
session_date: '2026-06-12'
project: cairn
tool: cursor
tags:
- cairn
- backfill
- gitignore
- data
- sensitive
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-12 03:25:39.256391+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260612-backfill-input-gitignore

## content

cairn/backfill-input/ was left as an untracked directory after the 347→1,395 record backfill. This directory contains raw project data that should not be committed.

## resolution

Add cairn/backfill-input/ to .gitignore or delete the directory. Session explicitly called this out as a post-session cleanup action.
