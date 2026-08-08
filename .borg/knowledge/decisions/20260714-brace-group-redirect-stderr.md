---
id: 20260714-brace-group-redirect-stderr
date: '2026-07-14'
project: borg-collective
domain: code-quality
tags:
- bash
- redirect
- stderr
- bats
- testing
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260714-1747-borg-collective
created_at: '2026-07-14 17:49:55.804700+00:00'
updated_at: '2026-07-14 17:49:55.804703+00:00'
---

# 20260714-brace-group-redirect-stderr

## decision

Fix the stderr leak in borg-link-down.sh by brace-grouping the printf+redirect: `{ printf ... >> "$BORG_DIR/cairn-hits.log"; } 2>/dev/null` instead of `printf ... >> "$BORG_DIR/cairn-hits.log" 2>/dev/null`

## context

The original form silenced stderr on the printf command but not on the file-open that bash performs before executing the command. A missing BORG_DIR caused bash to emit an error on stderr before 2>/dev/null took effect, contaminating bats test output spliced into JSON stdout.

## reasoning

Brace grouping makes 2>/dev/null apply to the entire subshell including the redirect open, which is the actual source of the error. Minimal change, preserves intent, directly addresses root cause.
