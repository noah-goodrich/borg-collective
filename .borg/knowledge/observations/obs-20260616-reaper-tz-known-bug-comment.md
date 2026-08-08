---
id: obs-20260616-reaper-tz-known-bug-comment
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- bash
- date
- timezone
- reaper
- bsd
- comments
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.555100+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-reaper-tz-known-bug-comment

## content

lib/reaper.sh:37 had a standing inline comment explicitly marking the UTC parsing as a known bug and instructing not to fix it at that location. The bug was nonetheless a real TZ-boundary failure: `date -j -f` without `-u` interprets the `Z` suffix as local time, causing reaper to misfire or silently skip tasks near midnight in non-UTC timezones.

## resolution

Removed the 'do not fix here' comment and applied the dual BSD/GNU fix (`-u` + `TZ=UTC`) directly in place. The comment was a historical deferral, not a genuine architectural constraint.
