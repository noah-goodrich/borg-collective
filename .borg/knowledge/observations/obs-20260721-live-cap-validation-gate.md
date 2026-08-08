---
id: obs-20260721-live-cap-validation-gate
session_date: '2026-07-21'
project: borg-collective
tool: claude-code
tags:
- usage-guardian
- validation
- production-readiness
- 5-hour-cap
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-21 22:16:47.852445+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260721-live-cap-validation-gate

## content

The directive's 'Done when' clause requires live-cap validation — arming the sweep against a real approaching 5-hour cap, end-to-end — before the feature is considered complete. This cannot be simulated in CI and requires a real near-cap episode. It is the blocking gate before enabling BORG_USAGE_SWEEP_ENABLED=1 in the plist.

## resolution

Schedule a session where the sweep is temporarily armed (BORG_USAGE_SWEEP_ENABLED=1) and observed during a genuine cap approach. Only after that episode should the plist be updated for permanent enablement.
