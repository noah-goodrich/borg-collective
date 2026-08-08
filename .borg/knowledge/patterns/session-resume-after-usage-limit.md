---
id: session-resume-after-usage-limit
project: borg-collective
domain: infrastructure
tags:
- workflow
- usage-limits
- resume
- session-management
preconditions: []
steps:
- At the start of any multi-phase workflow, write a STATUS.md or EXECUTION-PLAN.md
  that records completed phases, parked phases, and the exact resume command (workflow
  scriptPath + resumeFromRunId if applicable).
- When a usage limit is hit, park in-progress synthesis/analysis phases; note them
  as 'parked' in the status doc.
- Write memory files capturing the state of each parked work stream (one file per
  logical work stream).
- On reset, read the STATUS.md first, then resume the workflow using the cached run
  ID (cached intermediate results return instantly, avoiding re-spend).
- Route resumed work to a cheaper model tier if the original model caused the limit
  (e.g., park Fable work, resume on Opus).
pitfalls:
- If no resume run ID is captured before the limit hits, intermediate workflow results
  may not be recoverable and the expensive phases must re-run.
- Memory files written near a session limit may not flush — verify they exist at the
  start of the next session before discarding any in-session state.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260708-1940-orchestrator
superseded_by: null
created_at: '2026-07-08 19:41:01.404862+00:00'
updated_at: '2026-07-08 19:41:01.404862+00:00'
---

# session-resume-after-usage-limit

## description

Pattern for continuing multi-phase work across session/weekly usage limit resets without losing progress.
