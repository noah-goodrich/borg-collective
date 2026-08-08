---
id: 20260611-simplify-extract-ws-symlink-helper
date: '2026-06-11'
project: borg-collective
domain: code-quality
tags:
- refactoring
- shell
- drone
- deduplication
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.334366+00:00'
updated_at: '2026-06-11 22:41:19.334367+00:00'
---

# 20260611-simplify-extract-ws-symlink-helper

## decision

Extract a `_ws_symlink_snippet` helper in drone.zsh to deduplicate the supabase and generic scaffold workspace-symlink code paths rather than leaving them as twin inline blocks.

## context

/simplify surfaced two near-identical code blocks during the post-swap simplification pass.

## reasoning

Single point of change for workspace symlink logic; reduces future drift between the two scaffold paths. Clear win with no behavioral change.
