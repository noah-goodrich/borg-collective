---
id: blind-review-research-deliverables
project: borg-collective
domain: research
tags:
- competitive-research
- review-process
- quality-control
- analysis
preconditions: []
steps:
- Produce the research analysis draft (raw track files + synthesis).
- 'Perform a blind review: evaluate the analysis as if reading it fresh, without attachment
  to the effort spent producing it.'
- 'Issue a verdict: PASS (ship as-is), REVISE (specific changes required), or REJECT
  (start over).'
- Incorporate revisions if REVISE; document what changed and why.
- Commit both the final analysis and the raw track files so future sessions have the
  evidence trail.
pitfalls:
- Skipping blind review risks shipping analysis that confirms priors rather than surfaces
  real competitive signal.
- Raw track files (competitor-specific notes, scratchpad landscape) should be preserved
  separately from the synthesis — don't collapse them into the final doc.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-08-01 02:47:55.543024+00:00'
updated_at: '2026-08-01 02:47:55.543028+00:00'
---

# blind-review-research-deliverables

## description

Competitive research deliverables should go through a blind review step (PASS/REVISE/REJECT verdict) before being incorporated into the codebase or informing architectural decisions.
