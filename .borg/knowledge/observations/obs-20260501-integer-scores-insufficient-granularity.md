---
id: obs-20260501-integer-scores-insufficient-granularity
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- reveal
- scoring
- supabase
- pipeline
- data-quality
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.268448+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260501-integer-scores-insufficient-granularity

## content

potential_score and archetype_fit_score are stored as 0-5 integers in triage_results. The Python scoring.py pipeline computes float rubric scores (0-10) internally but discards them before DB insert. As a result, DB queries cannot distinguish the top 10% from the top 30% of photographs — a filter of potential_score>=4 captures a much wider band than intended.

## resolution

Planned fix: add rubric_score NUMERIC(4,2) column to triage_results and populate it from scoring.py output during pipeline runs. Not yet implemented — queued for next session.
