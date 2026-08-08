---
id: gated-ship-before-merge
project: cairn
domain: code-quality
tags:
- ship-discipline
- verification
- borg-verify
- collective-review
- testing
preconditions: []
steps:
- Run /simplify on changed files (src/ and tests/) — verify clean output with no suggestions
- Run Collective Review — must return 'ship' verdict
- Run borg-verify PASS — confirms new real-DB tests are actually executing (not being
  skipped or mocked away)
- Merge only after all three gates pass
pitfalls:
- borg-verify is specifically needed when new real-DB tests are added — mock-based
  tests can pass without exercising the actual DB, so borg-verify confirms real execution
- Skipping /simplify allows dead code or unnecessary complexity to accumulate in session-authored
  code
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-08-01 03:01:20.168880+00:00'
updated_at: '2026-08-01 03:01:20.168884+00:00'
---

# gated-ship-before-merge

## description

Multi-gate verification sequence before merging a PR in the cairn project to prevent regressions and ensure real test execution
