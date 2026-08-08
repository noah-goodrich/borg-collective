---
id: 20260611-brief-dispatch-bypass-overview
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- borg
- cli
- briefing
- performance
- dispatch
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.145620+00:00'
updated_at: '2026-06-11 20:39:25.145621+00:00'
---

# 20260611-brief-dispatch-bypass-overview

## decision

borg link --brief dispatches directly to _borg_print_briefing via borg_desktop_scan, bypassing _borg_link_overview entirely

## context

cmd_link previously routed --brief through _borg_link_overview, which ran full jq + desktop-scan work before invoking the briefing path

## reasoning

The --brief flag is documented as 'LLM narrative briefing' — the overview work is irrelevant to that output. Bypassing it saves ~300ms per invocation and keeps _borg_link_overview's signature clean (removed the do_brief parameter)
