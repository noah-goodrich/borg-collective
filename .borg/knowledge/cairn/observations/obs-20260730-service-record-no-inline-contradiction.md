---
id: obs-20260730-service-record-no-inline-contradiction
session_date: '2026-07-30'
project: cairn
tool: claude-code
tags:
- contradiction-detection
- service-layer
- performance
- write-path
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-30 23:23:43.225438+00:00'
updated_at: '2026-07-30 23:23:43.225442+00:00'
---

# obs-20260730-service-record-no-inline-contradiction

## content

`service.record_*` does NOT run contradiction detection inline. It is a decoupled, on-demand pass triggered separately. A false assumption that rerouting through the service layer would add per-row similarity queries was corrected mid-session.

## resolution

Verify the actual service implementation before assuming routing through a higher-level layer adds query overhead. In this case, rerouting was free of additional per-write cost — it only added inline embedding, which replaced the old manual re-embed step.
