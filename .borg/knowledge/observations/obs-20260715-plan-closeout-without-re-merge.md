---
id: obs-20260715-plan-closeout-without-re-merge
session_date: '2026-07-15'
project: borg-collective
tool: claude-code
tags:
- plan-management
- acceptance-criteria
- closeout
- docs-only-pr
category: pattern_discovered
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260715-0256-borg-collective
superseded_by: null
created_at: '2026-07-15 02:57:12.427191+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260715-plan-closeout-without-re-merge

## content

A project plan can be formally closed out via a docs-only PR even when the implementation was already merged in prior sessions. The closeout PR (#78) verified all acceptance criteria against existing merged code, archived the plan file, and disclosed the one deliberate deviation — all without touching implementation code. This cleanly separates 'code shipped' from 'plan formally closed'.

## resolution

Treat plan archival as a first-class deliverable; use a docs-only PR to record the acceptance-criteria audit result and any deviations. Future sessions should check whether open plan files correspond to already-merged implementations before starting new work.
