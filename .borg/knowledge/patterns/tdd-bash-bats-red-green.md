---
id: tdd-bash-bats-red-green
project: borg-collective
domain: testing
tags:
- bats
- bash
- tdd
- usage-guardian
preconditions: []
steps:
- Write bats tests for each discrete function (_claude_panes, _send_checkpoint, _guardian_get/_guardian_set_swept,
  _run_sweep) before implementing
- Run bats to confirm RED (expected failures)
- Implement the bash function to the test contract
- Run bats to confirm GREEN
- Run shellcheck on the script file before committing
- Confirm fast pure-bash suites still pass (regression gate)
pitfalls:
- Blanket 'no send-keys ever' tests will conflict with behavioural tests for sweep
  functions — replace with a default-OFF behavioural test that asserts send-keys is
  NOT called when the master switch is unset
- Container/tmux-dependent bats suites may hang on stateful host environments; rely
  on CI (clean runners) for those suites rather than running the full suite locally
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-21 22:16:47.846267+00:00'
updated_at: '2026-07-21 22:16:47.846268+00:00'
---

# tdd-bash-bats-red-green

## description

TDD cycle for bash scripts using bats: write failing tests expressing the behaviour contract, then implement just enough script logic to pass, then shellcheck
