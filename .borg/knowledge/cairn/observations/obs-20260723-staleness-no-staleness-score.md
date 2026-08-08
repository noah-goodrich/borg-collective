---
id: obs-20260723-staleness-no-staleness-score
session_date: '2026-07-24'
project: cairn
tool: claude-code
tags:
- belief-store
- staleness
- views
- phase-1a
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-24 05:15:46.528129+00:00'
updated_at: '2026-07-24 05:15:48.186761+00:00'
---

# obs-20260723-staleness-no-staleness-score

## content

The Phase 1a belief VIEW deliberately omits a staleness_score column. Only age_seconds (clamped with GREATEST(0,...)) is included. Staleness scoring is deferred to Phase 1b when real supersession data exists to calibrate it.

## resolution

Do not add staleness_score to the belief VIEW until Phase 1b is started with real corpus data. Consumers should use age_seconds for now.
