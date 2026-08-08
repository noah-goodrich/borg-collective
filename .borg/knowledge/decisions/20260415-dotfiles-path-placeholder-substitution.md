---
id: 20260415-dotfiles-path-placeholder-substitution
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- dotfiles
- jq
- sed
- portability
- absolute-paths
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.238103+00:00'
updated_at: '2026-06-11 22:41:19.238103+00:00'
---

# 20260415-dotfiles-path-placeholder-substitution

## decision

Use `__DOTFILES_DIR__` placeholder in base JSON files, substituted via sed at merge time

## context

Base settings JSON files are versioned in dotfiles and need to reference absolute paths (e.g., plugin paths) that differ per machine

## reasoning

Hardcoding absolute paths in versioned dotfiles makes the repo non-portable. Placeholder substitution at merge time keeps the base file machine-agnostic while producing correct output per machine.
