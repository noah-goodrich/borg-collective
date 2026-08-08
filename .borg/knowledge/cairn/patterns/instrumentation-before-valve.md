---
id: instrumentation-before-valve
project: cairn
domain: architecture
tags:
- borg-collective
- recon
- frequency-driven-design
- deferred-work
preconditions: []
steps:
- Identify the seam where the would-be valve would be invoked (e.g., _recon_persist_contradictions)
- Add a counter or structured log entry for each case where a fact could not be persisted
  via existing paths
- Run in production for enough sessions to get statistically meaningful frequency
  data
- Review frequency data before committing to building the valve
- If frequency justifies the build cost, scope and implement the valve; otherwise
  close the issue as not-worth-it
pitfalls:
- Building the valve before instrumentation risks shipping infrastructure that handles
  zero real cases
- Instrumentation must be on the borg-collective side (where the would-be callers
  live), not the cairn side (which already has the POST /record/batch endpoint)
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-08-01 03:01:20.189696+00:00'
updated_at: '2026-08-01 03:01:20.189700+00:00'
---

# instrumentation-before-valve

## description

Before building a new persistence valve or integration point, instrument the upstream system to measure actual demand frequency
