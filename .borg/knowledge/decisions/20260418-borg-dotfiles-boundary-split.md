---
id: 20260418-borg-dotfiles-boundary-split
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- borg
- dotfiles
- configuration-management
- claude
- separation-of-concerns
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.059040+00:00'
updated_at: '2026-06-11 20:39:25.059041+00:00'
---

# 20260418-borg-dotfiles-boundary-split

## decision

Move borg-required baseline config (CLAUDE.md sections, settings.base.json) into borg-collective/config/{claude,cortex}/ and inject into personal dotfiles via a delimited merge block, rather than storing everything in dotfiles repo.

## context

Borg changes were bleeding into personal dotfiles, making it hard to distinguish borg-managed config from personal config. Any borg update required a dotfiles commit.

## reasoning

Single source of truth for borg-managed content lives in borg-collective. Personal dotfiles CLAUDE.md becomes personal-only content. The merge helper uses delimited blocks so the boundary is machine-readable and idempotent. Dotfiles repo shrinks; borg repo is self-contained.
