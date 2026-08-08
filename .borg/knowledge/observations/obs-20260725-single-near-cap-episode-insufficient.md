---
id: obs-20260725-single-near-cap-episode-insufficient
session_date: '2026-07-25'
project: borg-collective
tool: claude-code
tags:
- usage-guardian
- thresholds
- data
- calibration
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-25 16:56:41.545567+00:00'
updated_at: '2026-07-25 17:54:08.585417+00:00'
---

# obs-20260725-single-near-cap-episode-insufficient

## content

The 85% checkpoint-sweep threshold rests on only ONE near-cap episode of empirical data. Tuning the threshold based on a single data point risks a poorly calibrated value.

## resolution

Do not adjust the 85% threshold until at least 3 independent near-cap episodes have been observed with both guardian halves armed. Let threshold data accrue naturally rather than tuning prematurely.
