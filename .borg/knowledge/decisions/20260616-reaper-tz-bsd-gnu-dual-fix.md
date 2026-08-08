---
id: 20260616-reaper-tz-bsd-gnu-dual-fix
date: '2026-06-16'
project: borg-collective
domain: code-quality
tags:
- bash
- date
- timezone
- bsd
- gnu
- cross-platform
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.552685+00:00'
updated_at: '2026-06-16 10:27:02.552686+00:00'
---

# 20260616-reaper-tz-bsd-gnu-dual-fix

## decision

Fix UTC timestamp parsing in lib/reaper.sh using BSD `-u` flag AND GNU `TZ=UTC` prefix, supporting both in the same code path

## context

reaper.sh:37 was parsing UTC `Z` timestamps via `date -j -f` without the `-u` flag, causing TZ-dependent misinterpretation. The file carried a 'known bug, do not fix here' comment. CI must pass on both GNU (Linux) and BSD (macOS) date.

## reasoning

BSD `date` uses `-u` for UTC; GNU `date` uses `TZ=UTC` prefix. Both idioms are needed simultaneously for CI green on both platforms. A single-flag approach would fail one platform.
