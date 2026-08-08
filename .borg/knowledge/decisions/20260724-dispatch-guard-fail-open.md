---
id: 20260724-dispatch-guard-fail-open
date: '2026-07-24'
project: borg-collective
domain: architecture
tags:
- hooks
- usage-guardian
- safety
- fail-open
- claude-code
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: null
created_at: '2026-07-24 05:14:36.289955+00:00'
updated_at: '2026-07-24 05:14:37.809065+00:00'
---

# 20260724-dispatch-guard-fail-open

## decision

The dispatch veto hook (borg-dispatch-guard.sh) is fail-OPEN on every uncertainty path: disabled flag, stale/missing/garbage sample, non-ok reading, non-numeric value, missing jq, empty stdin, non-dispatch tool.

## context

Building a PreToolUse hook that blocks Agent|Workflow dispatch at >=92% usage. The risk asymmetry is that a false-positive block could halt legitimate work, while a false-negative (missed block) is recoverable—the poller will still sweep and warn.

## reasoning

The hook operates at tool-fire time with real production state. Any gap in its inputs (missing file, stale data, tool mismatch) is more likely infrastructure noise than an actual over-cap condition. A block that fires incorrectly would silently kill agent workflows with no user-visible explanation. Fail-open preserves liveness and pushes the safety burden to the sweep mechanism, which has more context.
