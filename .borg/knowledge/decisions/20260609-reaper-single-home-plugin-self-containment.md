---
id: 20260609-reaper-single-home-plugin-self-containment
date: '2026-06-17'
project: borg-collective
domain: architecture
tags:
- plugins
- mechanism-layer
- 80/20
- reaper
- plugin-design
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-17 18:03:01.139542+00:00'
updated_at: '2026-06-17 18:03:01.139544+00:00'
---

# 20260609-reaper-single-home-plugin-self-containment

## decision

80/20 split: single reaper home lives in the mechanism layer; plugins are self-contained and call into that shared home rather than each owning their own reaper logic.

## context

PR #41 — mechanism-layer extraction for the reaper verb was the first proof-of-concept for the plugin 80/20 pattern.

## reasoning

Eliminates duplication of reaper-scoring logic across plugins; establishes a proven template (reaper slice) for subsequent verb extractions (scan/scoring, cairn-client, search).
