---
id: obs-20260709-usage-stats-correlational-label
session_date: '2026-07-09'
project: cairn
tool: claude-code
tags:
- usage-tracking
- stats
- data-quality
- observability
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260709-1535-cairn
superseded_by: null
created_at: '2026-07-09 15:36:29.701173+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260709-usage-stats-correlational-label

## content

The get_usage_stats join between call_log and token_spend is labeled 'correlational' in the implementation because the project attribution bug means the two tables cannot be reliably joined per project today. The stats surface exists and is wired, but the numbers are misleading until the attribution normalization is fixed.

## resolution

The label is intentional and correct. Fix the attribution bug in the collector first, re-ingest, then the join becomes meaningful. Do not interpret per-project cost figures from the current live stats endpoint as accurate.
