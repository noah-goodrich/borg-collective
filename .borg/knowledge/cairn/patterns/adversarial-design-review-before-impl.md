---
id: adversarial-design-review-before-impl
project: cairn
domain: architecture
tags:
- design-review
- failure-modes
- pre-implementation
- zero-loss
- adversarial
preconditions: []
steps:
- Define the module's contract and list explicit correctness claims (e.g. 'enqueue
  never loses data on fsync success')
- 'Assign 6 failure-mode lenses: crash/reboot, concurrent access, filesystem semantics,
  encoding/data, time/ordering, TOCTOU/atomicity'
- For each lens, attempt to refute each correctness claim with a concrete failure
  scenario
- 'Synthesize findings: classify each as data_loss, liveness_stuck, or correctness_violation;
  estimate likelihood'
- Fold all confirmed holes into the implementation design before writing code
- After implementation, run a separate adversarial code review with empirical container
  repros for the highest-severity findings
pitfalls:
- Design review lenses can miss platform-specific behaviors (e.g. macOS F_FULLFSYNC)
  if reviewers assume POSIX semantics — explicitly include a 'platform semantics'
  lens
- Session token limits can interrupt mid-review; structure each lens as a self-contained
  artifact so results survive a context break
- Some findings will be marked 'theoretical' during design review but confirmed real
  during code review — do not dismiss low-probability holes in durability code
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0914-cairn
superseded_by: null
created_at: '2026-06-16 10:27:03.290092+00:00'
updated_at: '2026-06-16 10:27:03.290093+00:00'
---

# adversarial-design-review-before-impl

## description

Run a structured adversarial design review across multiple failure-mode lenses BEFORE writing implementation code, using the findings to harden the design. This session used 6 lenses and found 9 data_loss/liveness_stuck holes before a line was written.
