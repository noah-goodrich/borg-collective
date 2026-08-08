---
id: obs-20260606-self-cert-invisible
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- deep-research
- verification
- self-certification
- integrity
- audit
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.479822+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260606-self-cert-invisible

## content

Phase 3.5 'blind verification' in deep-research has never failed across 7+ production runs — but this is evidence of a design flaw, not quality. The verification step is performed by the same workflow context that produced the report. There is no mechanism that distinguishes 'verifier ran and found nothing wrong' from 'verifier step was skipped.' The troth corpus shipped 65 source cards with 0 quote sections and no verification report file; reveal retroactively changed source statuses to 'cached/partial' after the fact. Both passed with 0 failures.

## resolution

Convert the prose post-check into an executable Stop hook (Directive 01) that inspects files directly. The hook must block delivery if: verification-report.md is absent, §6 lacks sample N + failure count, verifier-id equals synthesis-id, any card lacks Access status enum or Verified Quote(s) heading, or any card was corrected-during-verification (which is a FAILURE, not a pass). Use troth and reveal corpora as required-FAIL test fixtures.
