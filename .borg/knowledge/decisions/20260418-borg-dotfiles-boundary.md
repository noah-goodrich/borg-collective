---
id: 20260418-borg-dotfiles-boundary
date: '2026-06-16'
project: borg-collective
domain: architecture
tags:
- borg-collective
- dotfiles
- config-management
- CLAUDE.md
- split
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.167057+00:00'
updated_at: '2026-06-16 10:27:02.167058+00:00'
---

# 20260418-borg-dotfiles-boundary

## decision

borg-collective owns Permissions/Bash/Subagent rule sections of CLAUDE.md and settings.base.json files; dotfiles repo owns only personal/user-specific overrides

## context

Both repos were editing the same claude and cortex config files, creating confusion about which repo to update when fixing shared tooling behavior

## reasoning

borg-collective is the machine/role configuration layer; dotfiles is the personal preference layer. Tool rules (what claude-code is allowed to do) are borg concerns, not personal preferences. Delimited-block merge pattern (<!-- BEGIN borg-managed --> markers) allows both layers to coexist in a single deployed file without manual conflict resolution.
