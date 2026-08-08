---
id: obs-20260724-exit2-not-proven-in-bats
session_date: '2026-07-24'
project: borg-collective
tool: claude-code
tags:
- hooks
- PreToolUse
- bats
- veto
- live-validation
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-24 05:14:36.294362+00:00'
updated_at: '2026-07-24 05:14:37.898786+00:00'
---

# obs-20260724-exit2-not-proven-in-bats

## content

bats tests that assert exit 2 from a PreToolUse hook ONLY prove the shell script emits exit 2. They do NOT prove Claude Code interprets exit 2 as a veto and actually blocks the tool call. The runtime behavior of the hook protocol requires live validation against a real Claude Code session.

## resolution

Documented as an explicit remaining validation step: arm both guardian halves and trigger a real near-cap dispatch attempt to confirm Claude Code honors exit 2. Do not assimilate/close the directive until this live-cap pass is complete.
