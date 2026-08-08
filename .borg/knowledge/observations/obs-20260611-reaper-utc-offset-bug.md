---
id: obs-20260611-reaper-utc-offset-bug
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- reaper
- date
- timezone
- bsd-date
- posix
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.522724+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-reaper-utc-offset-bug

## content

`date -j -f` on macOS (BSD date) without the `-u` flag uses local time, causing reaper staleness calculations to be off by the local UTC offset. On a UTC-7 host a 1-hour-stale record would appear 8 hours stale, or vice versa depending on direction.

## resolution

Filed directive `docs/plans/directives/2026-06-06-reaper-utc-timezone-offset.md`. Fix is to add `-u` to all `date -j -f` calls in the reaper logic, or normalise both timestamps to UTC before comparison.
