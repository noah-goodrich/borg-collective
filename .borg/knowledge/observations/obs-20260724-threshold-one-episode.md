---
id: obs-20260724-threshold-one-episode
session_date: '2026-07-24'
project: borg-collective
tool: claude-code
tags:
- usage-guardian
- threshold-tuning
- data-requirements
category: domain_knowledge
files_involved: []
confidence: 0.9
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-24 05:14:36.295095+00:00'
updated_at: '2026-07-24 05:14:37.898786+00:00'
---

# obs-20260724-threshold-one-episode

## content

The 85% sweep threshold rests on a single near-cap episode. One data point is insufficient for threshold tuning. The directive explicitly defers tuning until 3+ near-cap episodes have been observed.

## resolution

Do not adjust BORG_USAGE_SWEEP_ENABLED or BORG_USAGE_HALT_PCT thresholds until at least 3 genuine near-cap sessions have been logged and reviewed. The samples file accumulates this data passively once the poller is running.
