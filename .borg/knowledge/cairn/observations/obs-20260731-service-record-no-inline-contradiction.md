---
id: obs-20260731-service-record-no-inline-contradiction
session_date: '2026-08-01'
project: cairn
tool: claude-code
tags:
- service-layer
- contradiction-detection
- write-path
- performance
- architecture
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: null
superseded_by: null
created_at: '2026-08-01 03:01:20.219515+00:00'
updated_at: '2026-08-01 03:01:20.219517+00:00'
---

# obs-20260731-service-record-no-inline-contradiction

## content

service.record_* does NOT run contradiction detection inline. Contradiction detection is a decoupled on-demand pass. This was a false premise that almost caused the team to reject routing through service.record_batch out of concern for per-row similarity query overhead.

## resolution

Confirmed the architecture: routing backfill-commit through service.record_batch adds only inline embedding (which replaces the old manual re-embed step) — no similarity queries per row. The false premise was corrected mid-session before design decisions were finalized.
