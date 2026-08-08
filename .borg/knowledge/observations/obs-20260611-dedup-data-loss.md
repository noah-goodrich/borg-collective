---
id: obs-20260611-dedup-data-loss
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- deduplication
- settings.json
- data-loss
- hooks
- regression
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.540102+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-dedup-data-loss

## content

The de-duplication logic in PR #44 (settings.json hook de-dup) over-removed entries, deleting the user's custom `session-log.sh` hook. The bug: de-dup was keyed on a structural field shared between borg-managed and user-managed entries, causing user entries to be treated as duplicates of borg entries and removed.

## resolution

PR #45 scoped removal strictly to identical duplicate blocks (full content match, not key match). A regression test was added (248/248 bats pass). The deleted session-log.sh was manually restored.
