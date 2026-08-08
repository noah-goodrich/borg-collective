---
id: obs-20260801-presence-falsely-marked-unimplemented
session_date: '2026-08-01'
project: borg-collective
tool: claude-code
tags:
- presence
- architecture
- documentation
- feature-flags
- docs-sync
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: null
superseded_by: null
created_at: '2026-08-01 02:47:55.632799+00:00'
updated_at: '2026-08-01 02:47:55.632800+00:00'
---

# obs-20260801-presence-falsely-marked-unimplemented

## content

The presence subsystem was documented (or implied in docs) as not yet implemented, but code inspection confirmed it IS implemented. The docs had fallen behind an actual feature shipping.

## resolution

Added a Presence subsection to architecture.md reflecting the real implementation. When auditing 'unimplemented' features, always verify against code — the feature may have shipped without the docs catching up.
