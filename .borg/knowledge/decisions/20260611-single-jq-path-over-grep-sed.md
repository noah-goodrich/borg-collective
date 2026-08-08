---
id: 20260611-single-jq-path-over-grep-sed
date: '2026-06-11'
project: borg-collective
domain: code-quality
tags:
- shell
- jq
- parsing
- robustness
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.500400+00:00'
updated_at: '2026-06-11 22:41:19.500400+00:00'
---

# 20260611-single-jq-path-over-grep-sed

## decision

Use a single jq path to extract last assistant message from transcript, replacing a grep+sed first-pass with jq fallback

## context

borg-link-up.sh needed to extract the last assistant message from a JSON transcript to build structured cairn notes. An initial grep+sed approach was used for speed with jq as fallback.

## reasoning

The grep+sed first-pass stopped at the first quote character, silently truncating output and masking the jq fallback entirely. A single jq path handles all cases correctly and is not meaningfully slower for the file sizes involved.
