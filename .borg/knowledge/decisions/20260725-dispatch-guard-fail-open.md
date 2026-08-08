---
id: 20260725-dispatch-guard-fail-open
date: '2026-07-25'
project: borg-collective
domain: architecture
tags:
- hooks
- safety
- claude-code
- usage-guardian
- shell
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: null
created_at: '2026-07-25 16:56:41.540006+00:00'
updated_at: '2026-07-25 17:54:08.360727+00:00'
---

# 20260725-dispatch-guard-fail-open

## decision

The >=92% dispatch-guard veto hook is fail-OPEN on every uncertainty (missing file, stale sample, parse error, etc.) and default-OFF via BORG_USAGE_HALT_ENABLED env var.

## context

Building a PreToolUse hook that denies Agent/Workflow dispatch at high usage requires deciding what to do when the data source is unavailable or ambiguous.

## reasoning

A fail-CLOSED hook would block all dispatch whenever the samples file is missing or stale, which would be catastrophic during normal operation (e.g., first run, file rotation, poller lag). Fail-OPEN preserves liveness at the cost of occasionally missing a cap event — acceptable given the sweep at 85% provides a softer prior warning. Default-OFF allows shipping without requiring operators to explicitly opt in to potentially disruptive behavior.
