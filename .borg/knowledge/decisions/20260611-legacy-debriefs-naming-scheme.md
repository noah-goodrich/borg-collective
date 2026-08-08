---
id: 20260611-legacy-debriefs-naming-scheme
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- borg
- checkpoints
- migration
- naming-convention
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.146543+00:00'
updated_at: '2026-06-11 20:39:25.146544+00:00'
---

# 20260611-legacy-debriefs-naming-scheme

## decision

Legacy debrief files migrated to .borg/checkpoints/ as <mtime-YYYY-MM-DD-HHMM>-legacy-<tag>.md where tag is first-8 of UUID or 'global'/'global-snowfort-audit'

## context

20 legacy LLM-debrief files existed across multiple projects in now-deprecated debriefs/ directories; needed to integrate with new checkpoint model without losing history

## reasoning

mtime-derived timestamps make legacy files sort chronologically alongside real checkpoints. The 'legacy' infix clearly marks them as migrated artifacts. UUID prefix preserves per-session identity while staying human-scannable
