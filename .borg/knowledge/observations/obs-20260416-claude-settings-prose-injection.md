---
id: obs-20260416-claude-settings-prose-injection
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- claude
- mcp
- settings.local.json
- json
- permission-allowlist
- content-bleed
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.025210+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260416-claude-settings-prose-injection

## content

A prose string leaked into `.claude/settings.local.json` as a syntactically valid but semantically inert permission entry: `"Bash(matters most\" — all research citations preserved, narrative shifted from deficit framing:*)"`. This appears to be content from a concurrent writing task that was accidentally injected into the allowlist. JSON parsers accept it without error; the Claude plugin runtime will simply never match it. The bug is invisible to automated validation.

## resolution

Manually remove the corrupted line before committing. Recommend a pre-commit lint step that validates `.claude/settings.local.json` permission entries against the known allowed-tool namespace pattern (e.g., `^(Bash|Read|WebFetch|Write)\(.*\)$`) to catch future injections.
