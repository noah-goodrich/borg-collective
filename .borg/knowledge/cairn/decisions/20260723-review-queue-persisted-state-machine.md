---
id: 20260723-review-queue-persisted-state-machine
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
created_at: '2026-07-24 03:54:03.155734+00:00'
updated_at: '2026-07-24 03:55:23.802040+00:00'
---

# 20260723-review-queue-persisted-state-machine

## decision

Persist the full review-queue state machine (proposed → superseded|invalidated|dismissed) including dismissed as a terminal state, and snapshot the conflicting row id, similarity-at-detection, and triggering feedback signal at detection time

## context

PR-B introduces a /belief/* review endpoint for resolving contradictions detected by the belief system.

## reasoning

Persisting dismissed (rather than deleting dismissed records) preserves audit history and prevents the same contradiction from being re-flagged after a human has already evaluated and dismissed it. Snapshotting similarity-at-detection and the triggering signal enables future staleness/calibration analysis without requiring a replay of historical embeddings.
