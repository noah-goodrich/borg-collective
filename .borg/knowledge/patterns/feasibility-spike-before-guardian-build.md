---
id: feasibility-spike-before-guardian-build
project: borg-collective
domain: architecture
tags:
- spike
- go-no-go
- subprocess
- delivery-channel
- validation
preconditions: []
steps:
- 'Phase 1 spike: confirm data source exists, is non-interactive, costs zero, and
  returns expected schema'
- Document verdict explicitly as GO/NO-GO with evidence against each acceptance criterion
- 'Before building Phase 2 (intervention): manually test the delivery mechanism against
  a target in its actual busy state, not idle'
- Only proceed to automated delivery after manual delivery is confirmed to land
- Collect real behavioral data (burn rates, timing) for at least one week before tuning
  thresholds
pitfalls:
- Extrapolated burn rates from sparse spike data can be 3x off from real behavior
- A delivery mechanism that works against an idle pane may silently fail against a
  mid-turn pane (borg:8 zombie precedent)
- Threshold values tuned off a single sample will be wrong; wait for real burn curves
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260709-0431-orchestrator
superseded_by: null
created_at: '2026-07-09 15:25:36.245515+00:00'
updated_at: '2026-07-09 15:25:36.245516+00:00'
---

# feasibility-spike-before-guardian-build

## description

Before building any automated intervention system (checkpoint sweep, hard-stop, etc.), run a two-phase spike: (1) verify the data source is readable and trustworthy, (2) verify the delivery channel works against a live target in the actual runtime state.
