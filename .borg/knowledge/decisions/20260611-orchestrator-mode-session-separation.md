---
id: 20260611-orchestrator-mode-session-separation
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- borg-collective
- orchestrator-mode
- hooks
- session-separation
- claude
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.485332+00:00'
updated_at: '2026-06-11 22:41:19.485333+00:00'
---

# 20260611-orchestrator-mode-session-separation

## decision

Implement orchestrator-mode session separation via a _borg_session_mode() helper in lib/borg-hooks.sh, with guards in all three hooks (borg-link-down.sh, borg-link-up.sh, borg-notify.sh), and a full orchestrator overview renderer in borg-link-down.sh.

## context

Orchestrator Claude sessions operate across multiple projects simultaneously; treating them identically to single-project sessions caused confusing state updates and notifications.

## reasoning

A single shared helper keeps mode detection logic in one place. Guards in each hook prevent inappropriate state mutations during orchestrator sessions. The overview renderer in link-down gives the orchestrator a cross-project summary on session end rather than a single-project report.
