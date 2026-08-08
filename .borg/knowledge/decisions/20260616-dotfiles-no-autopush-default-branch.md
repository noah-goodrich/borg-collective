---
id: 20260616-dotfiles-no-autopush-default-branch
date: '2026-06-16'
project: borg-collective
domain: infrastructure
tags:
- dotfiles
- git
- automation
- safety
- claude-code
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.553285+00:00'
updated_at: '2026-06-16 10:27:02.553285+00:00'
---

# 20260616-dotfiles-no-autopush-default-branch

## decision

Hold default-branch pushes behind explicit human authorization in the auto-classifier; do not push dotfiles main automatically even when clean

## context

dotfiles main was ahead 1 commit (36ac626) containing keychain exports and .borg/state.json ignore. Auto-classifier correctly blocked the push; human authorization was deferred to next session.

## reasoning

Default-branch pushes to dotfiles carry secrets-adjacent content (API key exports). Requiring explicit authorization provides a human review gate before secrets-handling code hits origin.
