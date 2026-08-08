---
id: obs-20260708-bash-guard-borg-project-bypass
session_date: '2026-07-08'
project: borg-collective
tool: claude-code
tags:
- bash-guard
- security
- pre-approval
- bypass
- hooks
- critical
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260708-1940-orchestrator
superseded_by: null
created_at: '2026-07-08 19:41:01.406673+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260708-bash-guard-borg-project-bypass

## content

hooks/bash-guard.sh:66 contains a CRITICAL security flaw: any shell command that contains the string '.borg-project' anywhere in the command line is unconditionally pre-approved without further inspection. An attacker-controlled command of the form 'rm -rf / --no-preserve-root .borg-project' would bypass all bash-guard checks. Additionally ~12 matcher-gap bypasses were found.

## resolution

Fix specified in docs/research/2026-07-07-fable5-zero-hour/03-security-audit-triaged.md but NOT yet applied. Must be implemented as a nanoprobe job gated by new bats tests in tests/bash_guard.bats (none exist today). This is the highest-priority security item for the next session.
