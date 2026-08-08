---
id: bats-path-isolation-for-absent-tool
project: borg-collective
domain: testing
tags:
- bats
- shell
- testing
- PATH
- cairn
preconditions: []
steps:
- Identify the test scenario where a binary (e.g., `cairn`) must not be found.
- In the test's `setup` or inline, set `PATH=/usr/bin:/bin` (or similarly stripped)
  to guarantee the binary is absent regardless of CI or local environment.
- Assert the expected silent-skip or no-op behavior of the script under test.
- Restore PATH in `teardown` if other tests in the suite need the real PATH.
pitfalls:
- If the script under test calls other binaries (e.g., `git`, `jq`) that are also
  absent from the stripped PATH, the test will fail for the wrong reason — ensure
  minimal PATH still contains all *other* dependencies the script needs.
- Tests that previously assumed the tool would error loudly when absent may need updating
  if the intended behavior is a silent skip — as happened with test 66 in this session.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.228853+00:00'
updated_at: '2026-06-16 10:27:02.228853+00:00'
---

# bats-path-isolation-for-absent-tool

## description

Test 'tool absent from PATH' scenarios in bats by overriding PATH to a controlled minimal value rather than relying on the real system PATH.
