---
id: obs-20260616-plugin-version-gap
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- claude-plugins
- versioning
- borg-setup
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.556755+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-plugin-version-gap

## content

After `borg setup`, the borg-collective plugin version advanced from 0.2.3 to 0.2.9 — a 6-minor-version gap resolved in a single session activation. All hooks and agents reported 'unchanged', indicating the version bump was metadata/manifest only, not behavioral.

## resolution

No action required. Document as baseline: after a multi-session gap, expect version number jumps that look alarming but are benign if hooks/agents report unchanged. Verify by checking the actual plugin manifest diff rather than reacting to the version delta alone.
