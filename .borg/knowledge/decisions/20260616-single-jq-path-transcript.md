---
id: 20260616-single-jq-path-transcript
date: '2026-06-16'
project: borg-collective
domain: code-quality
tags:
- jq
- shell
- parsing
- hooks
- cairn
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.465249+00:00'
updated_at: '2026-06-16 10:27:02.465250+00:00'
---

# 20260616-single-jq-path-transcript

## decision

Use a single jq path to extract last assistant message from transcript, dropping the grep+sed first-pass approach

## context

borg-link-up.sh needed to extract the last assistant message from a Claude transcript JSON file to enrich cairn session records

## reasoning

The grep+sed approach stopped parsing at the first quote in the message content, silently masking the jq fallback and producing truncated or wrong output. A single jq path handles all cases correctly and is more robust.
