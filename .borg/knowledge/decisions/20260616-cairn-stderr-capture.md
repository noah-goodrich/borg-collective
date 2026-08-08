---
id: 20260616-cairn-stderr-capture
date: '2026-06-16'
project: borg-collective
domain: infrastructure
tags:
- cairn
- debugging
- stderr
- borg-link
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.503361+00:00'
updated_at: '2026-06-16 10:27:02.503362+00:00'
---

# 20260616-cairn-stderr-capture

## decision

Modify `borg-link-up.sh` to capture cairn write stderr instead of discarding it (PR #40).

## context

Cairn write failures were silent — the hook ran, appeared to succeed, but writes weren't landing. The failure nudge also referenced `cairn status` which doesn't exist (correct subcommand is `cairn health`).

## reasoning

Silent failures in observability tooling are the worst failure mode — you lose data and don't know it. Capturing stderr enables diagnosis. Fixing the subcommand name in the nudge prevents a confusing dead-end when a developer tries to debug.
