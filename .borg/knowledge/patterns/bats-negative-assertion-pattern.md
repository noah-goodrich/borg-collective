---
id: bats-negative-assertion-pattern
project: borg-collective
domain: testing
tags:
- bats
- shell-testing
- assertions
- negative-grep
preconditions: []
steps:
- Capture command output into $output via run
- Use '! grep -q "pattern" <<< "$output"' for negative assertion
- Do NOT use 'grep -qv ... || true' — this always exits 0 regardless of match, making
  the assertion dead
pitfalls:
- grep -qv matches lines that do NOT contain the pattern — if any other line exists,
  it succeeds even when the pattern is present. Combined with || true it becomes a
  no-op assertion that never fails
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.467136+00:00'
updated_at: '2026-06-16 10:27:02.467137+00:00'
---

# bats-negative-assertion-pattern

## description

Correct pattern for asserting a string is absent in bats test output
