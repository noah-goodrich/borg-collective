---
id: obs-20260617-troth-import-quarantine-ux-silent
session_date: '2026-06-17'
project: borg-collective
tool: claude-code
tags:
- troth
- import
- ux
- quarantine
- error-handling
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-17 18:01:10.028240+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260617-troth-import-quarantine-ux-silent

## content

troth's import flow had two silent failure modes: (1) quarantined imports were not surfaced to the user — the UI showed no indication of quarantine state; (2) imports resulting in empty categories led to a dead-end UI state with no escape path.

## resolution

Fixed in troth PR #18. Import pipelines must surface quarantine state explicitly and guard against empty-result dead ends in the UI flow.
