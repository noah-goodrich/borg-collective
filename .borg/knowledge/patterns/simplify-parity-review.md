---
id: simplify-parity-review
project: borg-collective
domain: code-quality
tags:
- simplify
- shell
- hooks
- parity
- review
preconditions: []
steps:
- List every non-trivial construct in file A (timeouts, PATH comments, error handling,
  etc.)
- Check whether each construct exists in the symmetric counterpart file B
- 'For every missing construct, decide: intentional asymmetry (document) or oversight
  (fix)'
- Run the full test suite after changes to confirm no regressions
pitfalls:
- Asymmetries that are intentional (e.g., up vs. down have genuinely different semantics)
  can be incorrectly 'fixed' — always confirm intent before adding parity code
- Adding a timeout to a write operation (record) has different failure semantics than
  a timeout on a read (search); ensure the failure mode is acceptable (silent skip
  vs. error)
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.219996+00:00'
updated_at: '2026-06-16 10:27:02.219997+00:00'
---

# simplify-parity-review

## description

When reviewing a pair of symmetric shell hook files (e.g., link-up / link-down), explicitly cross-check each feature present in one against the other to surface asymmetries that create latent reliability or cognitive bugs.
