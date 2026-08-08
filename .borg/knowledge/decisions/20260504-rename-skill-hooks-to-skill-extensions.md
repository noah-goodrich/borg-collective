---
id: 20260504-rename-skill-hooks-to-skill-extensions
date: '2026-06-11'
project: borg-collective
domain: naming
tags:
- borg-collective
- claude-code
- naming-collision
- vocabulary
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.391852+00:00'
updated_at: '2026-06-11 22:41:19.391852+00:00'
---

# 20260504-rename-skill-hooks-to-skill-extensions

## decision

Rename the proposed directory from `skill-hooks/` to `skill-extensions/` to avoid collision with Claude Code's existing `hooks` vocabulary.

## context

During Devil's Advocate review, it was flagged that Claude Code already uses a `hooks` concept, making `skill-hooks/` ambiguous or confusing to users familiar with that tooling.

## reasoning

Avoiding vocabulary collision with Claude Code's native concepts reduces onboarding confusion and prevents future readers from misidentifying the mechanism.
