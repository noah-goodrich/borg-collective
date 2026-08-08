---
id: obs-20260708-burn-rate-3x-spike-estimate
session_date: '2026-07-09'
project: borg-collective
tool: claude-code
tags:
- claude-code
- usage
- burn-rate
- threshold-tuning
category: performance
files_involved: []
confidence: 0.8
source_model: null
source_session: 20260709-0431-orchestrator
superseded_by: null
created_at: '2026-07-09 15:25:36.250304+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260708-burn-rate-3x-spike-estimate

## content

Live measured burn rate was ~0.8%/min, approximately 3x the ~1%/4min (~0.25%/min) extrapolated during the spike. At 0.8%/min, an 85% threshold checkpoint buys ~40 minutes of runway, not ~1 hour.

## resolution

Do not tune BORG_USAGE_CHECKPOINT_PCT or checkpoint timing off a single sample or spike extrapolations. Collect at least one week of usage-samples.jsonl data before setting thresholds.
