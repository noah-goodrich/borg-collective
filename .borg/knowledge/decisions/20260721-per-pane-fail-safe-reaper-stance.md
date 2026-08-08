---
id: 20260721-per-pane-fail-safe-reaper-stance
date: '2026-07-21'
project: borg-collective
domain: architecture
tags:
- usage-guardian
- error-handling
- bash
- fail-safe
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: null
created_at: '2026-07-21 22:16:47.843835+00:00'
updated_at: '2026-07-21 22:16:47.843835+00:00'
---

# 20260721-per-pane-fail-safe-reaper-stance

## decision

Implement per-pane fail-safe in _run_sweep: a failure to deliver to one pane does not abort the sweep for remaining panes (reaper stance — continue regardless)

## context

Claude panes can disappear between discovery and delivery; a dead pane should not block delivery to healthy panes

## reasoning

The cost of missing one pane is low (that session might already be dead); the cost of aborting the entire sweep because of one bad pane is high (remaining active sessions never get the checkpoint)
