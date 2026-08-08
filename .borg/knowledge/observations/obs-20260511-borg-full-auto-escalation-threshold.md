---
id: obs-20260511-borg-full-auto-escalation-threshold
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- borg
- orchestration
- full-auto
- process
category: tool_behavior
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.369459+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260511-borg-full-auto-escalation-threshold

## content

When Noah declares 'full auto' mode, the correct behavior is immediate dispatch of all ready tracks without seeking confirmation. Previous sessions had the orchestrator asking for approval before each dispatch, creating unnecessary round-trips. Feedback captured in feedback_full_auto_mode.md.

## resolution

Full auto = dispatch immediately on all non-blocked tracks; escalate only: missing secrets, destructive operations without backups, hard schema conflicts. Do not surface soft questions or progress check-ins.
