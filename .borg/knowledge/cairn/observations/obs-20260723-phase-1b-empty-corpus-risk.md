---
id: obs-20260723-phase-1b-empty-corpus-risk
session_date: '2026-07-24'
project: cairn
tool: claude-code
tags:
- phase-1b
- staleness
- corpus
- data-requirements
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-24 05:15:46.526860+00:00'
updated_at: '2026-07-24 05:15:48.186761+00:00'
---

# obs-20260723-phase-1b-empty-corpus-risk

## content

At Phase 1a ship time, superseded_by is near-100% NULL in the belief corpus. Phase 1b (learned per-scope staleness clock) requires real supersession events to learn from. Starting Phase 1b without this data produces a meaningless model.

## resolution

Phase 1b is explicitly gated. Before starting, query contradiction_review resolutions and superseded_by counts to verify corpus has accumulated sufficient real events. Do not use synthetic data as a substitute.
