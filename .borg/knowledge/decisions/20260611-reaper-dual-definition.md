---
id: 20260611-reaper-dual-definition
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- borg
- reaper
- hooks
- zsh
- bash
- deployment
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.510883+00:00'
updated_at: '2026-06-11 22:41:19.510883+00:00'
---

# 20260611-reaper-dual-definition

## decision

Define borg reap in both lib/registry.zsh (CLI path) and lib/borg-hooks.sh (hook path), kept in sync manually.

## context

The reaper needs to fire both from the CLI (borg reap) and from hook scripts (borg-link-down.sh). The two execution environments use different shell runtimes.

## reasoning

Hooks run in bash context via borg-hooks.sh; CLI runs in zsh via lib/registry.zsh. A single-source approach would require runtime detection or cross-sourcing, adding fragility. Explicit duplication with a sync discipline is simpler and more auditable.
