---
id: obs-20260725-bats-exit2-vs-claude-code-honor
session_date: '2026-07-25'
project: borg-collective
tool: claude-code
tags:
- hooks
- bats
- claude-code
- PreToolUse
- testing-limits
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-25 16:56:41.545162+00:00'
updated_at: '2026-07-25 17:54:08.585417+00:00'
---

# obs-20260725-bats-exit2-vs-claude-code-honor

## content

Bats tests for the dispatch-guard hook can assert that the hook script emits exit 2 under the right conditions, but they cannot prove that Claude Code's PreToolUse hook runner actually honors exit 2 as a veto. The live-cap validation step is explicitly required to confirm the end-to-end contract.

## resolution

Do not mark the dispatch-guard directive complete based solely on bats passing. Arm both guardian halves (BORG_USAGE_SWEEP_ENABLED=1 + BORG_USAGE_HALT_ENABLED=1) and confirm during a genuine near-cap session that a dispatch attempt at >=92% is actually blocked by Claude Code. Only then close/assimilate the directive.
