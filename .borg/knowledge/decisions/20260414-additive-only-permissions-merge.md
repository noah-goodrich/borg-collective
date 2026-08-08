---
id: 20260414-additive-only-permissions-merge
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- jq
- settings-management
- idempotency
- dotfiles
- permissions
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:24.976767+00:00'
updated_at: '2026-06-11 20:39:24.976768+00:00'
---

# 20260414-additive-only-permissions-merge

## decision

Use additive-only union merge for permissions.allow — compute ($live + $new | unique) rather than overwriting the live array

## context

borg setup needed to propagate a versioned permissions baseline from dotfiles into machine-local settings files for both Claude Code and Cortex, without destroying machine-specific allow entries added by other tools or manual edits

## reasoning

Any machine may have locally-added allow entries (e.g. from plugin installs or manual configuration) that are not in the dotfiles base. Overwriting would silently break those machines on every borg setup run. The union approach is safe to run repeatedly and never regresses existing state.
