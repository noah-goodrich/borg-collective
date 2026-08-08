---
id: obs-20260709-exit0-masks-misconfiguration
session_date: '2026-07-09'
project: borg-collective
tool: claude-code
tags:
- shell-scripting
- error-handling
- launchd
- observability
- daemon
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260709-0431-orchestrator
superseded_by: null
created_at: '2026-07-09 15:26:37.442279+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260709-exit0-masks-misconfiguration

## content

The pattern `output=$(some-command) || output=''` collapses a command-not-found error (permanent misconfiguration) and a transient parse failure into the same code path. The script then logs WARNING and exits 0. launchctl list reports the job healthy. The job fires every 120s, writes zero samples, and gives no indication anything is wrong. This pattern appeared three times in a ~200-line script and was caught all three times only by end-to-end verification, never by the unit test suite (325→327 tests, all green throughout).

## resolution

Add explicit preflight checks (command -v, test -f) before the main logic. These should log ERROR and exit nonzero so the daemon supervisor (launchd, systemd, etc.) surfaces the failure. Reserve || output='' only for genuinely transient failures where continued operation is correct.
