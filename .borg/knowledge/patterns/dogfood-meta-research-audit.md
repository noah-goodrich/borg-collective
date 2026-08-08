---
id: dogfood-meta-research-audit
project: borg-collective
domain: research-tools
tags:
- deep-research
- brainstorm
- meta
- audit
- multi-agent
preconditions: []
steps:
- Run deep-research workflow on the tool's own methodology (7 research tracks, 5 audit
  lenses)
- Produce analysis.md (state of art), audit.md (right/wrong/ugly with file:line citations),
  and verification-report.md
- Run brainstorm workflow on the audit findings to generate improvement options
- Run a multi-voice council (9 agents) to select and sequence options into directives
- Ensure the two corpora that FAILED the audit become mandatory test fixtures for
  the remediation directive (troth → MUST FAIL gate, reveal → MUST FAIL gate)
- Ship directives sequentially; do not start a later directive until its prerequisite
  is passing in CI
pitfalls:
- Council agents may return prose instead of StructuredOutput if context is sparse
  — fix by adding compact inline context + explicit 'respond only via StructuredOutput'
  instruction before resuming from cache
- Source card count on disk vs. verifier tally can diverge (63 vs 62 in this session)
  — this is itself a live instance of the source-reconciliation gap the directive
  is meant to catch
- 'Self-certification is invisible: a workflow that both generates and verifies its
  own output will show 0 failures across all runs even when bypassed — treat ''100%
  pass rate across N runs'' as a red flag, not a green one'
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.478954+00:00'
updated_at: '2026-06-16 10:27:02.478955+00:00'
---

# dogfood-meta-research-audit

## description

Run a tool's own research + brainstorm skills against the tool itself to surface integrity gaps, then use the audit artifacts as test fixtures for the remediation directives.
