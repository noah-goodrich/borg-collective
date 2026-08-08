---
id: 20260616-borg-watch-tput-clear-loop
date: '2026-06-16'
project: borg-collective
domain: infrastructure
tags:
- borg-watch
- tui
- zsh
- tput
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.466333+00:00'
updated_at: '2026-06-16 10:27:02.466333+00:00'
---

# 20260616-borg-watch-tput-clear-loop

## decision

Implement borg watch as a tput clear polling loop rather than a proper TUI library

## context

Need live-refresh display of project status and nanoprobe evidence badges in the terminal

## reasoning

tput clear + sleep loop is pure zsh with no dependencies, sufficient for a 5-second refresh cycle, and consistent with borg's philosophy of minimal toolchain. A full TUI library would be overkill for this use case.
