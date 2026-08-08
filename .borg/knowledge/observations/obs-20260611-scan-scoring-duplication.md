---
id: obs-20260611-scan-scoring-duplication
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- mechanism-layer
- scan
- scoring
- borg.zsh
- duplication
- architecture
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.530517+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-scan-scoring-duplication

## content

Reaper-scoring logic is duplicated between borg.zsh and the mechanism layer. This was identified as the highest-priority follow-on extraction after the reaper slice proved the pattern.

## resolution

File a /borg-plan directive for scan/scoring extraction, parented to 2026-06-08-mechanism-layer-extraction-plugin-80-20-split, before starting implementation.
