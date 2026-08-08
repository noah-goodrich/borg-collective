---
id: two-phase-adversarial-code-review
project: cairn
domain: code-quality
tags:
- code-review
- adversarial
- empirical
- container-repro
- zero-loss
preconditions: []
steps:
- Run design-review-style lens pass against the actual implementation code
- For any finding above severity threshold, write a minimal container repro that demonstrates
  the failure
- Distinguish 'verifier-confirmed' (repro succeeded) from 'theoretical' (reasoning
  only)
- Fix all verifier-confirmed bugs immediately; add regression tests
- Close test gaps identified by the review (missing coverage of specific branches/error
  paths)
pitfalls:
- Code review without empirical repros risks false positives (theoretical bugs that
  don't manifest) and false negatives (bugs that need specific timing to surface)
- The review found one real bug (mark_dead_letter exception handling) that design
  review missed — code review catches implementation drift from design intent
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0914-cairn
superseded_by: null
created_at: '2026-06-16 10:27:03.290610+00:00'
updated_at: '2026-06-16 10:27:03.290610+00:00'
---

# two-phase-adversarial-code-review

## description

After implementation, run a second adversarial pass (code review, not design review) that empirically verifies the highest-severity findings with container repros rather than reasoning alone.
