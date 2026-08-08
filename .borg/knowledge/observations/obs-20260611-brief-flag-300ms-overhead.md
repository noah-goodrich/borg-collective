---
id: obs-20260611-brief-flag-300ms-overhead
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- borg
- briefing
- cli-latency
- jq
- desktop-scan
category: performance
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.148295+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-brief-flag-300ms-overhead

## content

Routing borg link --brief through _borg_link_overview before reaching _borg_print_briefing added ~300ms of unnecessary jq + desktop-scan work per invocation. This work is only relevant for the overview output, not the LLM briefing narrative.

## resolution

Dispatch --brief directly to _borg_print_briefing, bypassing _borg_link_overview entirely. Removes the do_brief parameter from _borg_link_overview's signature as a side-effect.
