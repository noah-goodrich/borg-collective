---
id: 20260415-dotfiles-placeholder-substitution-before-merge
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- dotfiles
- settings-management
- portability
- jq
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
created_at: '2026-06-11 20:39:24.987787+00:00'
updated_at: '2026-06-11 20:39:24.987788+00:00'
---

# 20260415-dotfiles-placeholder-substitution-before-merge

## decision

Substitute __DOTFILES_DIR__ placeholder in base settings files before the jq merge runs, not after.

## context

Base settings files in dotfiles need to reference paths relative to the dotfiles checkout, which varies per machine. The merge produces a final file consumed by Claude/Cortex, which expects resolved absolute paths.

## reasoning

jq operates on the value strings as-is; if the placeholder is present during merge it gets written into the output file unresolved. Substituting first means jq always sees valid paths and the output is immediately usable without a post-processing step.
