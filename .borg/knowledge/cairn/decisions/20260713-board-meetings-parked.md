---
id: 20260713-board-meetings-parked
date: '2026-07-13'
project: cairn
domain: architecture
tags:
- board-meetings
- multi-vendor
- subagents
- premature-optimization
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260713-2223-cairn
created_at: '2026-07-13 22:50:48.691038+00:00'
updated_at: '2026-07-13 22:50:48.691041+00:00'
---

# 20260713-board-meetings-parked

## decision

Park board-meetings feature rewrite; do not replace cross-vendor API calls with in-harness same-vendor subagents

## context

Evaluation of whether Sonnet/Fable/Opus subagents could replace external Anthropic+Gemini API calls in the board-meetings deliberation feature

## reasoning

Same-vendor subagents cannot reproduce cross-vendor lineage, which is the feature's actual value proposition. Additionally, board_meetings has 0 rows in production — optimizing a component that is not in the loop is premature optimization by definition.
