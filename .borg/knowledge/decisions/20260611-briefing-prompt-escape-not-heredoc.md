---
id: 20260611-briefing-prompt-escape-not-heredoc
date: '2026-06-11'
project: borg-collective
domain: code-quality
tags:
- zsh
- quoting
- heredoc
- minimal-change
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.146085+00:00'
updated_at: '2026-06-11 20:39:25.146086+00:00'
---

# 20260611-briefing-prompt-escape-not-heredoc

## decision

Fixed nested-quote bug in briefing_prompt= with \"..\" escapes rather than converting to a heredoc

## context

Quality agent during /simplify review flagged heredoc as a safer long-term alternative that eliminates the quote-footgun entirely

## reasoning

Escape fix is minimal, matches existing patterns in the file, and is not load-bearing. Heredoc refactor was deferred as a cheap optional follow-up, not applied in the bug-fix commit to keep the diff focused
