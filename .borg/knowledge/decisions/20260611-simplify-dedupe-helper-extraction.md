---
id: 20260611-simplify-dedupe-helper-extraction
date: '2026-06-11'
project: borg-collective
domain: code-quality
tags:
- refactoring
- zsh
- drone
- dry-principle
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.159565+00:00'
updated_at: '2026-06-11 20:39:25.159565+00:00'
---

# 20260611-simplify-dedupe-helper-extraction

## decision

Extract `_ws_symlink_snippet` helper in drone.zsh to deduplicate supabase and generic scaffold workspace symlink logic rather than leaving twin blocks

## context

/simplify pass identified the two paths had near-identical symlink setup code; three agents ran and this was the highest-confidence clear win

## reasoning

DRY: both scaffold paths need the same symlink behavior; a helper means future changes to symlink logic happen in one place
