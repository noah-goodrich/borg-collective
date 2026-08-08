---
id: 20260507-cairn-install-pipx-not-dotfiles
date: '2026-06-16'
project: borg-collective
domain: infrastructure
tags:
- cairn
- pipx
- dotfiles
- PATH
- tooling
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.347266+00:00'
updated_at: '2026-06-16 10:27:02.347266+00:00'
---

# 20260507-cairn-install-pipx-not-dotfiles

## decision

Install cairn via pipx rather than managing it through dotfiles

## context

Cairn binary was absent from PATH; SessionStart hook printed CAIRN UNAVAILABLE. Two installation paths were considered.

## reasoning

Verification spike confirmed the binary is genuinely absent rather than a PATH issue. pipx isolates the tool in its own virtualenv and manages the PATH entry automatically, which is more robust than a dotfiles-managed install.
