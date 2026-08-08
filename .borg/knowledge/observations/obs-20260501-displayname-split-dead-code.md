---
id: obs-20260501-displayname-split-dead-code
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- reveal
- typescript
- dead-code
- archetypes
- display-names
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.268096+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260501-displayname-split-dead-code

## content

GalleryMonograph.tsx, gallery/page, and BetaFeedbackForm all contained dead code splitting displayName on ' — ' separator. This pattern was presumably left over from an earlier data model where displayName encoded multiple fields. It was silently a no-op because the separator was never present in current data.

## resolution

Dead split logic removed from all three components. Future developers adding displayName fields should not assume the ' — ' separator pattern is intentional or supported.
