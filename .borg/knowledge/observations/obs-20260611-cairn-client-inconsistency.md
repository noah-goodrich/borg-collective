---
id: obs-20260611-cairn-client-inconsistency
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- cairn
- cairn-client
- architecture
- cli
- skills
- adapter
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.530845+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-cairn-client-inconsistency

## content

Both CLI paths and skill paths call cairn inconsistently today — there is no shared adapter. This is a known duplication hazard flagged for the next extraction round.

## resolution

File a /borg-plan directive for a shared cairn-client adapter after the scan/scoring extraction is complete. One verb at a time to avoid merge conflicts.
