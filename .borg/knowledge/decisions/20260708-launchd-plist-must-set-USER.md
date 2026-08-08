---
id: 20260708-launchd-plist-must-set-USER
date: '2026-07-09'
project: borg-collective
domain: infrastructure
tags:
- launchd
- plist
- environment
- claude-code
- macos
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260709-0431-orchestrator
created_at: '2026-07-09 15:25:36.242450+00:00'
updated_at: '2026-07-09 15:25:36.242451+00:00'
---

# 20260708-launchd-plist-must-set-USER

## decision

Explicitly set USER in EnvironmentVariables for all launchd plists that invoke claude CLI

## context

The existing cortex-wake.plist was used as a template but sets no EnvironmentVariables. When cloned verbatim, the poller ran silently and produced no output.

## reasoning

`claude -p '/usage'` prints nothing and exits 0 when USER is unset in the launchd environment. There is no error, no stderr, no non-zero exit — permanent silent blindness with no observable failure signal.
