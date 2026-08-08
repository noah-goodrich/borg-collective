---
id: 20260721-dismissed-state-terminal-persisted
date: '2026-07-24'
project: cairn
domain: architecture
tags:
- codex
- belief-store
- state-machine
- review-queue
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: null
created_at: '2026-07-24 03:53:11.044319+00:00'
updated_at: '2026-07-24 03:55:23.802040+00:00'
---

# 20260721-dismissed-state-terminal-persisted

## decision

In the belief review-queue state machine, `dismissed` is a terminal state that is persisted and does not re-fire

## context

The proposed → superseded|invalidated|dismissed state machine needs clear terminal states to prevent infinite re-review loops for noise detections.

## reasoning

Without a persisted terminal dismissed state, a contradiction detector would re-flag the same pair on every run. Persisting dismissed prevents re-fire and lets the system distinguish 'reviewed and dismissed' from 'not yet seen'.
