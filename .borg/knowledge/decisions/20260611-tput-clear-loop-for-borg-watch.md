---
id: 20260611-tput-clear-loop-for-borg-watch
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- cli
- terminal
- borg-watch
- live-display
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.501204+00:00'
updated_at: '2026-06-11 22:41:19.501204+00:00'
---

# 20260611-tput-clear-loop-for-borg-watch

## decision

Implement borg watch as a tput clear loop rather than using watch(1) or a TUI library

## context

borg watch needed to show live-refreshed project status and recent nanoprobes.

## reasoning

tput clear is universally available in zsh environments, requires no dependencies, and allows full control over output formatting including the ⚠/✓ evidence badge rendering. watch(1) does not support color/cursor control portably and is not available on all macOS installs without GNU coreutils.
