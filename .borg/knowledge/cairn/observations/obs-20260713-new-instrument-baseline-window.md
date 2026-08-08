---
id: obs-20260713-new-instrument-baseline-window
session_date: '2026-07-13'
project: cairn
tool: claude-code
tags:
- roi
- call_log
- baseline
- measurement
- instrumentation-age
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260713-2223-cairn
superseded_by: null
created_at: '2026-07-13 22:50:48.702463+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260713-new-instrument-baseline-window

## content

The cairn call_log instrument was only 5 days old at the time of the first ROI analysis. Any metrics derived from a ledger this young must be treated as a baseline snapshot, not a stable signal. The pollution rate (80%) dominated because the instrument hadn't accumulated enough real usage to dilute it.

## resolution

Document the baseline date and ledger age when reporting metrics. Revisit ROI numbers after the ledger is clean (post-#75 deploy) and has accumulated at least several weeks of real data.
