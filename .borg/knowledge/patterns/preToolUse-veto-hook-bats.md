---
id: preToolUse-veto-hook-bats
project: borg-collective
domain: testing
tags:
- bats
- hooks
- claude-code
- PreToolUse
- veto
- exit-codes
preconditions: []
steps:
- 'Identify every early-return (fail-open) path in the hook: disabled flag, missing
  file, stale sample, non-ok status, non-numeric value, missing dependency, wrong
  tool matcher.'
- Write one bats test per path that asserts exit 0 (allow) and that stdout contains
  the expected reason tag.
- 'Write the single DENY test: all conditions met (armed, fresh ok sample, value >=
  threshold, correct tool) → assert exit 2.'
- Run shellcheck on the hook as part of CI (add to build-list, assert in source-parity
  test).
- Add a source-parity test asserting the hook appears in hooks.json and the build-list
  copy step.
pitfalls:
- bats tests only prove the hook emits the correct exit code in isolation—they do
  NOT prove Claude Code honors exit 2 as a veto. Live-cap validation is required to
  confirm the runtime contract.
- Stale-sample detection requires a time comparison at test time; bats tests must
  control the sample timestamp or mock date logic to avoid flakiness.
- Forgetting to add the hook to both hooks.json AND the build-list copy causes the
  binary plugin to silently omit it; a source-parity test catches this.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-24 05:14:36.292998+00:00'
updated_at: '2026-07-24 05:14:37.872662+00:00'
---

# preToolUse-veto-hook-bats

## description

Pattern for TDD of a Claude Code PreToolUse veto hook in bash: structure tests to cover every fail-open path explicitly, one bats test per uncertainty branch, plus the single armed+fresh+over-threshold deny path.
