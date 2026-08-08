---
id: 20260415-additive-only-permissions-merge
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- settings-management
- dotfiles
- permissions
- idempotency
- zsh
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:24.987232+00:00'
updated_at: '2026-06-11 20:39:24.987233+00:00'
---

# 20260415-additive-only-permissions-merge

## decision

borg setup uses additive-only union merge for permissions.allow — dotfiles base is a floor, never a ceiling. Machine-local entries are never removed.

## context

Needed a way to distribute a baseline set of Claude/Cortex permissions across machines via dotfiles without clobbering machine-specific tool grants that vary per environment.

## reasoning

Different machines may have legitimately different tool permissions (e.g., a dev box with more grants than a shared machine). A destructive sync would break machine-specific workflows silently. Additive-only is safe to run repeatedly and never regresses a machine's capabilities.
