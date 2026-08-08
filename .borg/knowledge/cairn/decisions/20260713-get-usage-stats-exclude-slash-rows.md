---
id: 20260713-get-usage-stats-exclude-slash-rows
date: '2026-07-13'
project: cairn
domain: data-quality
tags:
- usage-stats
- call_log
- filtering
- roi
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260713-2223-cairn
created_at: '2026-07-13 22:50:48.697990+00:00'
updated_at: '2026-07-13 22:50:48.697991+00:00'
---

# 20260713-get-usage-stats-exclude-slash-rows

## decision

Modify get_usage_stats to exclude skipped rows and rows where query='/' from reported metrics

## context

80% of call_log rows (762/953) were synthetic '/' pollution from usage-watch poller, making ROI metrics report ~2% instead of the real ~52%

## reasoning

The '/' rows are instrumentation artifacts from the launchd poller, not real retrieval attempts. Including them in the denominator collapses the apparent retrieval rate to noise.
