---
id: obs-20260709-unit-tests-miss-env-mismatches
session_date: '2026-07-09'
project: borg-collective
tool: claude-code
tags:
- testing
- bats
- launchd
- environment
- shell-scripting
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260709-0431-orchestrator
superseded_by: null
created_at: '2026-07-09 15:26:37.445030+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260709-unit-tests-miss-env-mismatches

## content

A 325-test bats suite was green throughout the entire period when the live launchd poller was blind (writing zero samples). Unit tests execute in the developer's login shell environment, which has the correct PATH and all expected binaries. They cannot detect failures that arise from PATH or environment differences in the daemon execution context.

## resolution

Supplement unit tests with an end-to-end verification step after any daemon install: force an immediate run via launchctl kickstart -k and confirm output was actually written. For CI, consider a test that explicitly unsets user PATH additions and runs the script in a minimal environment to catch env-dependency bugs.
