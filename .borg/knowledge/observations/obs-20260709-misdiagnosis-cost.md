---
id: obs-20260709-misdiagnosis-cost
session_date: '2026-07-09'
project: borg-collective
tool: claude-code
tags:
- debugging
- process
- stderr
- root-cause
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260709-1659-borg-collective
superseded_by: null
created_at: '2026-07-09 17:01:17.387309+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260709-misdiagnosis-cost

## content

Theorizing a root cause (PATH omission) before reading the stderr log resulted in a merged PR with a false claim and a wasted deploy cycle. The actual error ('no such file or directory: /reaper.sh') was in the stderr log the entire time.

## resolution

Read the agent's stderr log as the first diagnostic step for any launchd exit-code failure. Do not form a hypothesis until the log has been examined.
