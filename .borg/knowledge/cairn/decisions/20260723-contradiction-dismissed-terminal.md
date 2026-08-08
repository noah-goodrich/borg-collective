---
id: 20260723-contradiction-dismissed-terminal
date: '2026-07-24'
project: cairn
domain: architecture
tags:
- state-machine
- contradiction-review
- belief-store
- postgresql
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: null
created_at: '2026-07-24 05:15:46.522549+00:00'
updated_at: '2026-07-24 05:15:48.083615+00:00'
---

# 20260723-contradiction-dismissed-terminal

## decision

Make `dismissed` a terminal state in the contradiction_review state machine (proposed→superseded|invalidated|dismissed) with no transitions out

## context

Designing the contradiction review workflow; needed to decide whether dismissed contradictions could be re-surfaced

## reasoning

Dismissed contradictions should never re-surface — they represent a deliberate human judgment that the pair is not actually contradictory. Re-surfacing would create noise and erode trust in the review queue. The UNIQUE(belief_id, conflicting_id) + ON CONFLICT DO NOTHING enforces this at the DB level
