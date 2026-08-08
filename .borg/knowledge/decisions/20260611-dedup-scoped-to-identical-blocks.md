---
id: 20260611-dedup-scoped-to-identical-blocks
date: '2026-06-11'
project: borg-collective
domain: code-quality
tags:
- deduplication
- settings.json
- data-loss
- regression
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.538471+00:00'
updated_at: '2026-06-11 22:41:19.538471+00:00'
---

# 20260611-dedup-scoped-to-identical-blocks

## decision

De-duplication logic must scope removal strictly to identical duplicate blocks, not to any matching key/entry

## context

PR #44 de-dup logic over-removed entries, deleting the user's `session-log.sh` hook from settings.json — a data-loss bug caught and fixed in #45

## reasoning

Greedy de-dup that removes all-but-one occurrence of a key can silently delete user customizations that happen to share a key name with a borg-managed entry
