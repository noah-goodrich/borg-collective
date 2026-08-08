---
id: 20260801-recon-prove-or-drop-before-replace
date: '2026-08-01'
project: borg-collective
domain: architecture
tags:
- competitive-research
- graphiti
- recon
- technical-debt
- decision-framework
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: cairn-backfill-commit
source_model: null
source_session: null
created_at: '2026-08-01 02:47:55.494395+00:00'
updated_at: '2026-08-01 02:47:55.494396+00:00'
---

# 20260801-recon-prove-or-drop-before-replace

## decision

Do NOT evaluate or replace the just-shipped recon system with Graphiti (or alternatives) until issue #46 runs and gathers evidence of real deficiency.

## context

Competitive refresh surfaced Graphiti as a potential alternative to borg's custom recon/memory approach. The recon system was just documented and shipped in this session.

## reasoning

Speculative replacement of freshly shipped code based on competitive landscape noise rather than observed failure is a high-waste pattern. Gather real evidence of deficiency first; only then evaluate alternatives.
