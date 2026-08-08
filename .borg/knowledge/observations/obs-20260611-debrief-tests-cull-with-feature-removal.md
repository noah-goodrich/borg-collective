---
id: obs-20260611-debrief-tests-cull-with-feature-removal
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- bats
- testing
- cleanup
- lifecycle
- debrief
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.162869+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-debrief-tests-cull-with-feature-removal

## content

When a feature is removed (debrief-era functionality), its tests should be culled in the same commit that removes the feature — not left as permanently-failing noise. 6 debrief-era tests in lifecycle.bats were culled in commit cfc6f09 because they tested removed functionality and were causing confusion about actual test health.

## resolution

Policy: removed feature → remove its tests in the same commit or immediately after. Document the removal in the commit message.
