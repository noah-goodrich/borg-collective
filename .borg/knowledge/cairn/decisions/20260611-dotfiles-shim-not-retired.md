---
id: 20260611-dotfiles-shim-not-retired
date: '2026-06-11'
project: cairn
domain: infrastructure
tags:
- cairn
- shim
- dotfiles
- cli
- hook
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1925-cairn
created_at: '2026-06-11 20:31:18.024584+00:00'
updated_at: '2026-06-11 20:31:18.024584+00:00'
---

# 20260611-dotfiles-shim-not-retired

## decision

The dotfiles shell shim (~/.config/dotfiles/zsh/bin/cairn) must NOT be retired as long as hooks depend on it. It was prematurely retired during this session and had to be restored.

## context

During the cairn restoration work, the shim was removed under the assumption that the Python CLI superseded it. This broke all three hook integrations.

## reasoning

The shim is the only cairn client available in hook environments (stripped PATH, no POSTGRES_PASSWORD). Python CLI is for interactive terminal use where local.zsh sources credentials. These two clients serve different runtime contexts and must coexist.
