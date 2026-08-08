---
id: 20260414-sed-before-jq-placeholder-substitution
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- jq
- sed
- dotfiles
- path-substitution
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
created_at: '2026-06-11 20:39:24.977414+00:00'
updated_at: '2026-06-11 20:39:24.977415+00:00'
---

# 20260414-sed-before-jq-placeholder-substitution

## decision

Substitute __DOTFILES_DIR__ placeholder via sed before passing JSON to jq, rather than using a jq --arg or shell variable inside the JSON file

## context

The versioned settings base needed to reference the marketplace plugin path, which includes the dotfiles directory. Storing a literal shell variable or placeholder in JSON would make the file invalid or require jq to handle path construction.

## reasoning

sed substitution on the raw string before JSON parsing keeps the base file human-readable with a clear placeholder, avoids embedding shell syntax in JSON, and ensures jq always receives valid JSON with fully-resolved paths.
