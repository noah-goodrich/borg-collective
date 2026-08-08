---
id: obs-20260611-directive-assimilation-workflow
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- workflow
- directives
- borg-assimilate
- documentation
category: pattern_discovered
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.341568+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-directive-assimilation-workflow

## content

The /borg-assimilate command formalises directive completion: the directive file is moved from docs/plans/ to docs/plans/assimilated/ with acceptance criteria marked [x] and a dated filename. This creates a permanent, auditable record of what was delivered and when, separate from git log.

## resolution

Follow the pattern: verify all acceptance criteria are met, mark them [x] in the file, rename with completion date prefix, move to assimilated/. Commit in the same changeset as the code that satisfies the final criterion.
