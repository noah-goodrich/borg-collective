---
id: 20260616-orchestrator-session-mode-helper
date: '2026-06-16'
project: borg-collective
domain: architecture
tags:
- orchestrator-mode
- hooks
- session-separation
- bash
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.448134+00:00'
updated_at: '2026-06-16 10:27:02.448135+00:00'
---

# 20260616-orchestrator-session-mode-helper

## decision

Implement orchestrator-mode detection as a single `_borg_session_mode()` helper in lib/borg-hooks.sh, then guard all three hooks (borg-link-down.sh, borg-link-up.sh, borg-notify.sh) with calls to that helper.

## context

Directive A required hooks to behave differently when running in orchestrator mode (managing multiple sub-agent sessions) vs. single-project mode.

## reasoning

Centralising the mode detection in one helper prevents drift between hooks and makes future changes to detection logic a single-file edit. Guards in each hook keep hook logic self-contained and testable.
