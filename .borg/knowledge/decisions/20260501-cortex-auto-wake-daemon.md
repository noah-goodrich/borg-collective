---
id: 20260501-cortex-auto-wake-daemon
date: '2026-06-16'
project: borg-collective
domain: infrastructure
tags:
- tmux
- cortex
- session-management
- launchd
- zsh
- automation
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.238416+00:00'
updated_at: '2026-06-16 10:27:02.238417+00:00'
---

# 20260501-cortex-auto-wake-daemon

## decision

Implement cap-and-resume as a daemon: detect the cap message in the Cortex pane, schedule a wake, auto-send `wake up!` via tmux at reset time

## context

Claude Code hits context limits (cap) mid-task; current workflow requires manual intervention to resume. Scrollback evidence confirmed the pattern: cap message → pause → manual `wake up!` → resume with no state loss

## reasoning

Smallest scope fix (~30 lines zsh + launchd plist) for a daily friction point. Evidence of the cap-and-resume pattern was directly observable in tmux scrollback, making the detection signal well-defined
