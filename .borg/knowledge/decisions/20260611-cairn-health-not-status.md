---
id: 20260611-cairn-health-not-status
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- cairn
- cli
- ux
- error-messaging
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.521017+00:00'
updated_at: '2026-06-11 22:41:19.521018+00:00'
---

# 20260611-cairn-health-not-status

## decision

Change the failure nudge in `borg-link-up.sh` from `cairn status` (nonexistent subcommand) to `cairn health`.

## context

PR #40 was filed specifically because the nudge was emitting a subcommand that does not exist, masking the real diagnostic information.

## reasoning

`cairn health` is the correct subcommand. Pointing operators to a nonexistent command actively hinders debugging.
