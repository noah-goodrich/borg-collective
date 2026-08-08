---
id: 20260415-dotfiles-path-placeholder
date: '2026-06-11'
project: borg-collective
domain: dotfiles
tags:
- dotfiles
- jq
- sed
- path-substitution
- portability
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.004934+00:00'
updated_at: '2026-06-11 20:39:25.004935+00:00'
---

# 20260415-dotfiles-path-placeholder

## decision

Use __DOTFILES_DIR__ placeholder in versioned base JSON, substituted via sed at merge time

## context

The versioned dotfiles base JSON needs to reference the user's dotfiles directory (e.g. for plugin paths) but that path varies per machine

## reasoning

Hardcoding absolute paths in committed dotfiles breaks portability across machines. Placeholder substitution at merge time keeps the base clean and machine-agnostic.
