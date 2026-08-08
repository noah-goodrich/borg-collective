---
id: obs-20260616-backwards-directive-in-downstream-repo
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- multi-repo
- source-of-truth
- claude-plugins
- documentation-drift
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.419786+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-backwards-directive-in-downstream-repo

## content

claude-plugins contained a directive that implied it was the authoritative source, directly contradicting the actual design (borg-collective is canonical). This created genuine confusion about where changes should originate and which repo to trust.

## resolution

Resolved by locating the original Dispatch session transcript (f9ef8d07) which explicitly documented the split. Fixed the claude-plugins directive and updated the borg-collective handoff doc. Lesson: downstream/publishing repos must explicitly declare themselves as consumers, not owners.
