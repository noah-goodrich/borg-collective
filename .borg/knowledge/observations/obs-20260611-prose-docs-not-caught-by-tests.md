---
id: obs-20260611-prose-docs-not-caught-by-tests
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- documentation
- refactoring
- sweep
- technical-debt
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.162445+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-prose-docs-not-caught-by-tests

## content

Six markdown files (architecture.md, skills-guide.md, devcontainer-coco.md, boris-workflow.md, cheatsheet.md, six-pager.md) still reference old hook/skill names after the full swap. No test catches prose-only doc staleness; it only surfaces when a human reads the docs and is confused.

## resolution

Treat prose docs as a separate sweep task, not bundled with the functional refactor commit. Track them explicitly as deferred follow-ups so they don't get lost.
