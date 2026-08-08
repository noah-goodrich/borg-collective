---
id: 20260709-preflight-command-v-exit-nonzero
date: '2026-07-09'
project: borg-collective
domain: code-quality
tags:
- shell-scripting
- error-handling
- launchd
- observability
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260709-0431-orchestrator
created_at: '2026-07-09 15:26:37.437503+00:00'
updated_at: '2026-07-09 15:26:37.437504+00:00'
---

# 20260709-preflight-command-v-exit-nonzero

## decision

Add a command -v preflight check for the claude binary that logs ERROR and exits nonzero on failure, rather than letting a missing binary collapse into a parse-failure warning

## context

The existing pattern `output=$(...) || output=''` caused a missing-binary error (permanent misconfiguration) to be silently treated as transient format drift, logged WARNING, and exited 0. launchd reported the job healthy.

## reasoning

A nonzero exit makes launchd report an unhealthy job, surfacing the misconfiguration through existing monitoring. Exits 0 on permanent failures is the root cause of the entire silent-blindness class found repeatedly in this script.
