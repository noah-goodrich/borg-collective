---
id: 20260611-two-step-swap-rename
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- git
- rename
- hooks
- lifecycle
- inversion
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.136578+00:00'
updated_at: '2026-06-11 20:39:25.136579+00:00'
---

# 20260611-two-step-swap-rename

## decision

Use a two-step .swap intermediate when git mv-ing two files that are exchanging names, to avoid a name collision on case-insensitive or same-tree renames.

## context

borg-link-up.sh and borg-link-down.sh need their semantics swapped (the names were inverted at creation). Doing a direct git mv A B; git mv B A would clobber one file.

## reasoning

Git mv A A.swap; git mv B A; git mv A.swap B is the standard safe sequence for exchanging two filenames in the same directory without data loss.
