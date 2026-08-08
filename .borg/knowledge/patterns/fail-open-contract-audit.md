---
id: fail-open-contract-audit
project: borg-collective
domain: code-quality
tags:
- safety
- hooks
- review
- fail-open
preconditions: []
steps:
- List every condition that must ALL be true to reach the deny exit (armed flag, file
  exists + fresh, last row is ok, value is numeric, value >= threshold, tool matcher
  matches).
- For each condition, identify the else branch and confirm it exits 0 with a logged
  reason.
- Trace through with a missing-dependency scenario (e.g., jq not found) to confirm
  it never reaches the deny branch.
- Have an independent reviewer read the hook with the fail-open contract stated explicitly,
  not inferred.
- Add a bats test for each confirmed fail-open path before submitting for review.
pitfalls:
- A complex condition like `[[ value -ge threshold ]]` that silently fails on non-numeric
  input can accidentally become fail-CLOSED if the error path isn't explicitly handled.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-24 05:14:36.293761+00:00'
updated_at: '2026-07-24 05:14:37.872662+00:00'
---

# fail-open-contract-audit

## description

Checklist pattern for auditing a fail-open safety hook before merge: enumerate every code path that could reach the DENY exit, confirm all others reach ALLOW, and get independent reviewer sign-off on the contract.
