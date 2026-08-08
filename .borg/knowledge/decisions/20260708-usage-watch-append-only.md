---
id: 20260708-usage-watch-append-only
date: '2026-07-09'
project: borg-collective
domain: infrastructure
tags:
- shell
- atomicity
- file-io
- polling
- launchd
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260709-0431-orchestrator
created_at: '2026-07-09 15:25:36.231494+00:00'
updated_at: '2026-07-09 15:25:36.231496+00:00'
---

# 20260708-usage-watch-append-only

## decision

Use plain `>>` append for usage-samples.jsonl rather than tmp+rename rewrite

## context

Initial implementation used a whole-file tmp+rename rewrite pattern to ensure consistency, but this runs at every 120s poll interval and the file grows unboundedly.

## reasoning

Plain `>>` append is already atomic below PIPE_BUF for single-line JSON records. The tmp+rename pattern is O(n) per poll on a forever-growing file, wasting I/O for no correctness benefit given the append-only read pattern downstream.
