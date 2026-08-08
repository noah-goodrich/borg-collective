---
id: bats-failure-triage-preexisting-vs-regression
project: borg-collective
domain: testing
tags:
- bats
- testing
- triage
- regression
preconditions: []
steps:
- 1. Run full suite, capture total pass/fail counts
- 2. Group failures by test file
- 3. For each failing file, check whether the tested subcommand/feature still exists
  in the codebase
- 4. If the subcommand was removed/renamed as part of prior work (not this session),
  mark as pre-existing — document the old vs new invocation
- 5. If the failure is in a file touched this session, investigate as potential regression
- 6. Cull tests for removed functionality (they create noise) or document them as
  known-broken with a fix recipe
pitfalls:
- 134/141 passing looks good but the 7 failures in briefing.bats (calling removed
  `borg briefing` subcommand, now `borg link --brief`) will mask real regressions
  if not triaged
- Don't delete pre-existing failing tests without first documenting the fix — they
  encode intent even if the invocation changed
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.160643+00:00'
updated_at: '2026-06-11 20:39:25.160644+00:00'
---

# bats-failure-triage-preexisting-vs-regression

## description

Pattern for triaging bats test failures after a large refactor to distinguish pre-existing failures from newly introduced regressions
