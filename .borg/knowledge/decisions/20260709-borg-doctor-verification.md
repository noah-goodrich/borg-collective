---
id: 20260709-borg-doctor-verification
date: '2026-07-09'
project: borg-collective
domain: infrastructure
tags:
- launchd
- agent-health
- borg-doctor
- bootstrap
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260709-1659-borg-collective
created_at: '2026-07-09 17:01:17.383798+00:00'
updated_at: '2026-07-09 17:01:17.383798+00:00'
---

# 20260709-borg-doctor-verification

## decision

borg doctor checks all four agents (registered? last exit? fresh output?) and install.sh verifies the poller produces a row after bootstrap.

## context

notifyd and cortex-wake had been exiting 127 on every fire — desktop notifications and CoCo wake silently dead — and were only discovered when borg doctor was built.

## reasoning

Silent failure of launchd agents is the core reliability risk. A single command that checks liveness across all agents catches cross-machine regressions immediately on sync and install.
