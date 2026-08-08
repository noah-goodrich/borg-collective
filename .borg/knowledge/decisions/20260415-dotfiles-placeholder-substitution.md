---
id: 20260415-dotfiles-placeholder-substitution
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- dotfiles
- portability
- jq
- path-resolution
- settings-management
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.230692+00:00'
updated_at: '2026-06-11 22:41:19.230693+00:00'
---

# 20260415-dotfiles-placeholder-substitution

## decision

Use __DOTFILES_DIR__ placeholder in base settings files, substituted at merge time before jq runs.

## context

Base settings files need to reference dotfiles-relative paths (e.g., for allowed directories), but the absolute path to dotfiles varies per machine.

## reasoning

Substituting before the jq merge keeps the base files human-readable and machine-agnostic. The alternative of computing paths inside jq would be awkward and less transparent.
