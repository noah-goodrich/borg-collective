---
id: ci-red-root-cause-reproduce-then-fix
project: borg-collective
domain: testing
tags:
- ci
- debugging
- bats
- regression-test
preconditions: []
steps:
- Read the CI failure output carefully; note exact error message and column numbers
  (e.g., 'Invalid numeric literal at line 1, column 88' → 87-char path leaked into
  JSON).
- 'Identify what variable or environment condition is different in CI vs. local (here:
  XDG_CONFIG_HOME set in CI runner but not in local shell).'
- Reproduce locally by manually setting the offending env var to a missing path and
  running the test.
- Add a regression test in the relevant .bats file that exercises the failure path
  and fails on the unfixed code.
- Apply the minimal fix, confirm regression test passes, confirm full suite passes.
- Merge fix PR; verify CI green before merging any dependent artifacts.
pitfalls:
- Long-standing CI reds are often caused by environment differences invisible locally
  — check XDG vars, HOME, PATH, and tool versions before assuming code logic is wrong.
- 'A cryptic JSON parse error column number is often exactly the length of an injected
  string (e.g., a file path + '': line N:'') — use it as a measuring tape.'
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260714-1747-borg-collective
superseded_by: null
created_at: '2026-07-14 17:49:55.809155+00:00'
updated_at: '2026-07-14 17:49:55.809156+00:00'
---

# ci-red-root-cause-reproduce-then-fix

## description

Workflow for fixing a long-standing CI red that was merged over rather than investigated: reproduce locally with the exact environment mismatch, identify the root cause, add a regression test that fails on the old code, fix, confirm the regression test passes, then merge.
