---
id: obs-20260709-burn-rate-load-dependent
session_date: '2026-07-09'
project: borg-collective
tool: claude-code
tags:
- claude-api
- token-usage
- rate-limiting
- capacity-planning
category: domain_knowledge
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260709-0431-orchestrator
superseded_by: null
created_at: '2026-07-09 15:26:37.444496+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260709-burn-rate-load-dependent

## content

Claude API session token burn rate is load-dependent, not a constant. Three measurement sessions yielded three different rates: ~1%/4min (spike estimate), ~0.8%/min (prior session), ~1.1%/min (this session, under active multi-agent load). At 1.1%/min, an 85% threshold provides ~13 min of headroom, not the ~40 min estimated from 0.8%/min and not the ~1hr assumed in the original spike.

## resolution

Do not tune BORG_USAGE_CHECKPOINT_PCT off any single session's burn rate. Collect several days of usage-samples.jsonl data across varied load conditions, then analyze the distribution — especially the tail under heavy multi-agent load — before setting thresholds.
