---
id: 20260801-model-routing-doc-only-fix
date: '2026-08-01'
project: borg-collective
domain: architecture
tags:
- model-routing
- documentation
- agents
- claude-opus
- claude-fable
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: cairn-backfill-commit
source_model: null
source_session: null
created_at: '2026-08-01 02:47:55.421312+00:00'
updated_at: '2026-08-01 02:47:55.421316+00:00'
---

# 20260801-model-routing-doc-only-fix

## decision

Resolved model routing discrepancy between agents/ROUTING.md and settings.json via documentation correction only — no code or settings changes made.

## context

ROUTING.md and settings.json disagreed on which model was the session default. Opus 4.8 is default; Fable 5 is opt-in. Specialist frontmatter was already correct.

## reasoning

The code (settings.json + specialist frontmatter) was already correct. The doc was wrong. Changing code to match wrong docs would have been backwards. Docs-only fix preserves the authoritative source of truth in settings.
