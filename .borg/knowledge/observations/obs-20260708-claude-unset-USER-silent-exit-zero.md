---
id: obs-20260708-claude-unset-USER-silent-exit-zero
session_date: '2026-07-09'
project: borg-collective
tool: claude-code
tags:
- claude-code
- launchd
- environment
- silent-failure
- USER
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260709-0431-orchestrator
superseded_by: null
created_at: '2026-07-09 15:25:36.249397+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260708-claude-unset-USER-silent-exit-zero

## content

When the USER environment variable is unset, `claude -p '/usage'` exits 0 with no stdout and no stderr. There is no error message, no non-zero exit code, and no observable failure signal. In a launchd context this produces a permanently silent poller that appears healthy.

## resolution

Always set USER explicitly in launchd plist EnvironmentVariables. Add a guard in the polling script to fail loudly if USER is empty before invoking claude.
