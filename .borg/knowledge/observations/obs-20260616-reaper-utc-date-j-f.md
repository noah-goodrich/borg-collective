---
id: obs-20260616-reaper-utc-date-j-f
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- date
- bsd-date
- timezone
- utc
- reaper
- macos
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.505494+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-reaper-utc-date-j-f

## content

BSD `date -j -f <format>` (macOS) does not apply UTC by default — it uses the local timezone. This causes the reaper's stale-hours calculation to be off by the UTC offset when the system is not in UTC, producing incorrect reap decisions.

## resolution

Filed directive `docs/plans/directives/2026-06-06-reaper-utc-timezone-offset.md`. The fix is to add `-u` flag: `date -u -j -f <format>`. Any timestamp comparison using `date -j -f` on macOS must include `-u` if the stored timestamps are in UTC.
