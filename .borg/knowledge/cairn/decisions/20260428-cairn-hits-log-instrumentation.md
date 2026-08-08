---
id: 20260428-cairn-hits-log-instrumentation
date: '2026-06-11'
project: cairn
domain: infrastructure
tags:
- validation
- instrumentation
- keep-or-kill
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1925-cairn
created_at: '2026-06-11 20:31:17.997124+00:00'
updated_at: '2026-06-11 20:31:17.997125+00:00'
---

# 20260428-cairn-hits-log-instrumentation

## decision

Add a flat `cairn-hits.log` file (timestamp\tproject\tbytes) written on every session start in addition to the API calls, as the primary evidence source for the 4-week keep-or-kill decision

## context

The keep-or-kill review needs honest usage data. API records could be lost if the service is down; a simple append-only log survives API outages.

## reasoning

A tab-separated log written by the hook with no external dependencies is the most reliable instrumentation possible — it works even when the cairn API is unreachable.
