---
id: 20260611-lifecycle-inversion-swap-via-intermediate
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- git
- file-rename
- shell
- hooks
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
created_at: '2026-06-11 20:39:25.158639+00:00'
updated_at: '2026-06-11 20:39:25.158640+00:00'
---

# 20260611-lifecycle-inversion-swap-via-intermediate

## decision

Use a `.swap` intermediate filename when renaming files that need to exchange names (A→A.swap, B→A, A.swap→B) rather than attempting direct simultaneous rename

## context

Swapping hook filenames borg-link-up.sh ↔ borg-link-down.sh; direct rename would clobber one file with the other on case-sensitive or same-filesystem operations

## reasoning

Shell and git cannot atomically swap two filenames; the intermediate prevents data loss and keeps git history traceable through the rename chain
