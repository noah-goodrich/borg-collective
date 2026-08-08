---
id: 20260504-skip-simplify-for-prompt-only-prs
date: '2026-06-11'
project: borg-collective
domain: code-quality
tags:
- borg-collective
- borg-simplify
- workflow
- prompt-engineering
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.392610+00:00'
updated_at: '2026-06-11 22:41:19.392610+00:00'
---

# 20260504-skip-simplify-for-prompt-only-prs

## decision

Skip the /simplify step when a PR contains only prompt edits and documentation (no executable code).

## context

The skill-extensions PR (#20) contained only SKILL.md edits and docs. The question arose whether /simplify should still be run.

## reasoning

/simplify is designed to find executable code complexity. Applying it to markdown prompt files is a category error and would produce no signal.
