---
id: 20260721-sweep-default-off
date: '2026-07-21'
project: borg-collective
domain: architecture
tags:
- usage-guardian
- feature-flags
- safety
- bash
- tmux
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: null
created_at: '2026-07-21 22:16:47.836964+00:00'
updated_at: '2026-07-21 22:16:47.836966+00:00'
---

# 20260721-sweep-default-off

## decision

Ship the checkpoint-sweep mechanism default-OFF via BORG_USAGE_SWEEP_ENABLED env var, with threshold as config (BORG_USAGE_CHECKPOINT_PCT, default 85) rather than hard-coded

## context

The sweep types directly into live Claude panes — a capability with irreversible side effects if misfired. Needed a safe rollout path before production use.

## reasoning

Default-OFF eliminates risk during the validation period. Making the threshold a config var rather than a tuned constant acknowledges that the right threshold requires empirical data from near-cap episodes. The directive explicitly required this stance.
