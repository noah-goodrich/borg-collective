---
id: obs-20260611-debrief-tests-removed-not-skipped
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- bats
- testing
- lifecycle
- debrief
- cleanup
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.336105+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-debrief-tests-removed-not-skipped

## content

When a feature is fully removed (debrief era), the corresponding tests should be deleted outright rather than skipped. Skipped tests accumulate as dead weight and obscure which tests are actually meaningful. Six debrief-era tests were deleted from lifecycle.bats in this session and bundled into the lifecycle commit.

## resolution

Bundle test deletions into the same commit as the feature removal so `git log` clearly associates the pruning with the change. The commit message should call out the count of removed tests.
