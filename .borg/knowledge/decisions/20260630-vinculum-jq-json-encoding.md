---
id: 20260630-vinculum-jq-json-encoding
date: '2026-06-30'
project: borg-collective
domain: code-quality
tags:
- vinculum
- json
- shell
- jq
- encoding
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260630-2202-borg-collective
created_at: '2026-06-30 22:03:12.815887+00:00'
updated_at: '2026-06-30 22:03:12.815888+00:00'
---

# 20260630-vinculum-jq-json-encoding

## decision

Use `jq` for JSON encoding in `borg vinculum pub` rather than hand-rolled shell string escaping

## context

Initial implementation used manual shell escaping to construct JSON payloads; the /simplify pass caught that this mangled quotes and backslashes in message content

## reasoning

Hand-rolled shell JSON escaping is fragile and will silently corrupt messages containing quotes, backslashes, or Unicode. `jq` handles all edge cases correctly and is already a project dependency.
