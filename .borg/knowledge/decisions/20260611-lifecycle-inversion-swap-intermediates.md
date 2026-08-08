---
id: 20260611-lifecycle-inversion-swap-intermediates
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- shell
- hooks
- git
- file-rename
- lifecycle
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.333551+00:00'
updated_at: '2026-06-11 22:41:19.333552+00:00'
---

# 20260611-lifecycle-inversion-swap-intermediates

## decision

Use a `.swap` intermediate file when renaming two files to each other's names (e.g., borg-link-up.sh ↔ borg-link-down.sh) to avoid a collision where one file overwrites the other mid-swap.

## context

The lifecycle inversion required swapping the filenames of two hook scripts. A direct mv A B; mv B A sequence would destroy content because the first mv clobbers the destination.

## reasoning

Shell filesystems are not transactional; two-step rename without intermediate loses one file. The .swap temp name breaks the dependency cycle cleanly with zero risk of data loss.
