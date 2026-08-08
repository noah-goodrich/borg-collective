---
id: feature-roi-gate-before-optimize
project: cairn
domain: engineering-process
tags:
- roi
- premature-optimization
- gap-analysis
- feature-gating
preconditions: []
steps:
- Identify the feature under consideration for improvement
- Query call_log or equivalent ledger for rows attributed to that feature
- If row count is 0 or negligible, classify the improvement as premature optimization
  and park it
- Document the parking decision with a reopen condition (e.g., 'reopen if genuine
  cross-vendor need appears')
- Record the correct future path (e.g., CAIRN_MCP_ALLOW_REMOTE=1 flag) so it isn't
  lost
pitfalls:
- Usage ledger may itself be polluted (see '/' pollution pattern) — validate ledger
  cleanliness before trusting row counts
- A feature with 0 rows may have 0 rows because it's broken, not unused — distinguish
  before parking
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260713-2223-cairn
superseded_by: null
created_at: '2026-07-13 22:50:48.698978+00:00'
updated_at: '2026-07-13 22:50:48.698979+00:00'
---

# feature-roi-gate-before-optimize

## description

Before investing in quality/performance improvements to a feature, verify the feature has non-zero production usage. Check call_log/usage rows for the relevant component as a precondition.
