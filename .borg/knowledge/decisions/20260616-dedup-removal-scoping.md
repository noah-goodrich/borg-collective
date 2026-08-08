---
id: 20260616-dedup-removal-scoping
date: '2026-06-16'
project: borg-collective
domain: code-quality
tags:
- deduplication
- settings.json
- data-loss
- regression-testing
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.525896+00:00'
updated_at: '2026-06-16 10:27:02.525897+00:00'
---

# 20260616-dedup-removal-scoping

## decision

De-dup logic must scope removal strictly to the duplicate entries, not remove the last surviving entry when it appears in multiple contexts

## context

The de-dup over-removal bug (#45) deleted `session-log.sh` from the user's settings because the de-dup code removed the entry entirely rather than just the duplicate occurrences

## reasoning

Correct de-dup: keep exactly one copy of each entry, remove N-1 duplicates. The bug kept zero copies when the entry existed in more than one structural location.
