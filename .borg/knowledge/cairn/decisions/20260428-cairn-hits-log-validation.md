---
id: 20260428-cairn-hits-log-validation
date: '2026-06-11'
project: cairn
domain: infrastructure
tags:
- instrumentation
- validation
- logging
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
created_at: '2026-06-11 23:12:50.707644+00:00'
updated_at: '2026-06-11 23:12:50.707645+00:00'
---

# 20260428-cairn-hits-log-validation

## decision

borg-link-down.sh appends `timestamp\tproject\tbytes` to cairn-hits.log on every session start as a lightweight validation signal

## context

Need to measure cairn usage over 4 weeks to decide keep-or-kill. The log provides a durable, low-dependency signal that survives even if the cairn API is down.

## reasoning

A plain TSV log is always writable, trivially parseable, and doesn't depend on cairn being operational — providing a ground-truth usage baseline independent of the API's health.
