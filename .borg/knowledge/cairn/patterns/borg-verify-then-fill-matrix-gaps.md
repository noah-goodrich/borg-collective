---
id: borg-verify-then-fill-matrix-gaps
project: cairn
domain: testing
tags:
- testing
- acceptance-criteria
- borg-verify
- ci
preconditions: []
steps:
- Implement feature and pass all existing tests
- Run /borg-verify to map each AC to diff evidence
- Identify matrix rows where the only evidence is in-process unit tests
- Add CLI-level or HTTP-level tests that exercise the same path end-to-end
- Re-run /borg-verify to confirm all rows now have real-call test coverage
pitfalls:
- Unit tests that pass in-process can mask bugs in the wiring between layers (e.g.,
  HTTP handler → service → usage.log_call). The live hit_count=0 observation in this
  session may be exactly this failure mode.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260709-1535-cairn
superseded_by: null
created_at: '2026-07-09 15:36:29.695002+00:00'
updated_at: '2026-07-09 15:36:29.695004+00:00'
---

# borg-verify-then-fill-matrix-gaps

## description

Run /borg-verify after implementing a feature to map acceptance criteria to diff evidence, then audit the matrix for rows backed only by unit tests (not CLI/integration tests) and add the missing real-call tests.
