---
id: bats-path-isolation-absent-binary
project: borg-collective
domain: testing
tags:
- bats
- testing
- PATH
- isolation
- shell
preconditions: []
steps:
- Identify tests that assert behavior when a dependency (e.g., cairn) is not on PATH
- Replace any ad-hoc PATH manipulation with `env PATH=/usr/bin:/bin <command>` (or
  equivalent minimal PATH)
- Confirm the binary under test is not present in that minimal PATH on CI and local
  dev machines
- Update expected output/exit codes to match the silent-skip semantics the code actually
  implements
pitfalls:
- A PATH set in the test body may not propagate correctly to subshells spawned by
  the script under test; `env` wrapping the invocation is more reliable
- If the binary exists in /usr/bin or /bin on some machines, even a minimal PATH won't
  guarantee absence — use a temp directory with no such binary instead
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.220403+00:00'
updated_at: '2026-06-16 10:27:02.220404+00:00'
---

# bats-path-isolation-absent-binary

## description

When writing bats tests for 'binary absent' scenarios, use `env PATH=<controlled-path>` rather than manipulating PATH in the test body, to guarantee the target binary is genuinely unreachable regardless of the test runner's environment.
