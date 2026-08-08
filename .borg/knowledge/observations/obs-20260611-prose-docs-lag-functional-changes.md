---
id: obs-20260611-prose-docs-lag-functional-changes
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- docs
- maintenance
- drift
- hooks
- skills
category: gotcha
files_involved: []
confidence: 0.8
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.336760+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-prose-docs-lag-functional-changes

## content

After a large rename/inversion, at least six prose-only markdown files (architecture.md, skills-guide.md, devcontainer-coco.md, boris-workflow.md, cheatsheet.md, six-pager.md) still referenced the old hook and skill names. These are non-functional but create confusion for anyone reading them. They were explicitly out-of-scope for this session but were not tracked in any todo until the session-end note.

## resolution

Add a docs-sweep directive as a follow-up task immediately when functional renaming is complete, before closing the session. Do not rely on memory across sessions to catch this. In this case it was captured in Section 4 blockers and Section 5 next-session items.
