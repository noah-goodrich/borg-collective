---
id: obs-20260801-routing-doc-code-drift
session_date: '2026-08-01'
project: borg-collective
tool: claude-code
tags:
- model-routing
- agents
- settings.json
- documentation-drift
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: null
superseded_by: null
created_at: '2026-08-01 03:01:33.401056+00:00'
updated_at: '2026-08-01 03:01:33.401058+00:00'
---

# obs-20260801-routing-doc-code-drift

## content

agents/ROUTING.md had drifted from settings.json — the documented default model did not match the configured default model. This creates silent misbehavior where operators reading docs would configure agents based on incorrect assumptions.

## resolution

Both files updated atomically in PR #109. Pattern: treat ROUTING.md and settings.json as a coupled pair that must be diffed together on any model-routing change.
