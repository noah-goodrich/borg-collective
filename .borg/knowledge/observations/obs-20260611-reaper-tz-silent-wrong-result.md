---
id: obs-20260611-reaper-tz-silent-wrong-result
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- bash
- date
- bsd
- timezone
- silent-bug
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.560662+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-reaper-tz-silent-wrong-result

## content

BSD `date -j -f` parsing a UTC `Z`-suffixed timestamp without `-u` silently applies the local timezone offset, producing a wrong numeric result with no error. The bug existed with a standing code comment acknowledging it, and a separate commit (#48) had been conflated with 'the fix' in the directive tracking — it was actually fixing a different `stat`-related issue.

## resolution

Add `-u` (BSD) and `TZ=UTC` prefix (GNU) to the `date` invocation. Add explicit TZ-boundary bats tests that set `TZ` to a non-UTC zone before asserting reap age calculations.
