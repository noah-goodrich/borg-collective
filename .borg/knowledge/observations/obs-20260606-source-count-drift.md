---
id: obs-20260606-source-count-drift
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- deep-research
- source-cards
- reconciliation
- verification
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.481371+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260606-source-count-drift

## content

In the meta-review run itself, the verifier tallied 62 source cards while 63 existed on disk — a live source-reconciliation gap occurring in the session that was auditing source-reconciliation gaps. This is not a one-off: the gap exists because the verifier counts cards it processed, not cards that exist, and there is no assertion that the two sets are equal.

## resolution

Directive 01 assertion 6 (corrected-during-verification = FAILURE) and the card-integrity check must include a file-count reconciliation: count of cards in sources/ directory must equal N reported in §6 of the verification report. A mismatch is a hard failure, not a warning.
