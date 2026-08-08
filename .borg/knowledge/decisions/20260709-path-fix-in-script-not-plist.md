---
id: 20260709-path-fix-in-script-not-plist
date: '2026-07-09'
project: borg-collective
domain: infrastructure
tags:
- launchd
- PATH
- shell-scripting
- single-source-of-truth
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260709-0431-orchestrator
created_at: '2026-07-09 15:26:37.435268+00:00'
updated_at: '2026-07-09 15:26:37.435270+00:00'
---

# 20260709-path-fix-in-script-not-plist

## decision

Prepend $HOME/.local/bin to PATH inside the poller script itself, not in the launchd plist

## context

launchd's minimal PATH omitted $HOME/.local/bin where the native claude installer places the binary. The plist already had an explicit PATH override, making it the obvious fix location.

## reasoning

Fixing it in the script means every invocation path (launchd, cron, manual, CI) gets the fix from one place. Fixing the plist would only help launchd invocations; a future cron or systemd deployment would rediscover the same bug.
