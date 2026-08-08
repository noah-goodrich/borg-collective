---
id: obs-20260709-set-e-arithmetic
session_date: '2026-07-09'
project: borg-collective
tool: claude-code
tags:
- bash
- set-e
- arithmetic
- exit-code
- launchd
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260709-1659-borg-collective
superseded_by: null
created_at: '2026-07-09 17:01:17.386812+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260709-set-e-arithmetic

## content

(( expr )) returns exit code 1 when the arithmetic expression evaluates to 0 (false). Under set -e, this silently terminates the script. If (( DEBUG )) is the last statement in a log() function and DEBUG=0, every call to log() kills the script.

## resolution

Use (( expr )) || true when the expression may legitimately be zero, or restructure so an arithmetic expression is never the last command in a function that runs under set -e.
